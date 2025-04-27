/**
 * PostgreSQL Event Webhook Listener
 * 
 * Este serviço escuta eventos do PostgreSQL em tempo real e os encaminha para 
 * um endpoint webhook configurado via variável de ambiente WEBHOOK_URL.
 */

require('dotenv').config();
const { Client } = require('pg');
const axios = require('axios');

// Construir URL do webhook a partir das variáveis do Easypanel
function buildWebhookUrl() {
  // Se WEBHOOK_URL estiver definido diretamente, use-o
  if (process.env.WEBHOOK_URL) {
    return process.env.WEBHOOK_URL;
  }
  
  // Caso contrário, construa a partir das variáveis do Easypanel
  const projectName = process.env.PROJECT_NAME || 'ops-s';
  const serviceName = process.env.SERVICE_NAME || 'webhook';
  const primaryDomain = process.env.PRIMARY_DOMAIN || 'localhost';
  const webhookPath = process.env.WEBHOOK_PATH || '/lead-events';
  
  // Formatar a URL completa
  return `https://${projectName}-${serviceName}.${primaryDomain}${webhookPath}`;
}

// Configuração via variáveis de ambiente
const config = {
  webhookUrl: buildWebhookUrl(),
  webhookInsecure: process.env.WEBHOOK_INSECURE === 'true', // Ignorar validação de certificado
  pgConfig: {
    host: process.env.POSTGRES_HOST || 'localhost',
    port: parseInt(process.env.POSTGRES_PORT || '5432'),
    database: process.env.POSTGRES_DB || 'leadscrm',
    user: process.env.POSTGRES_USER || 'postgres',
    password: process.env.POSTGRES_PASSWORD || 'postgres'
  },
  channelName: 'lead_events',
  retryInterval: 5000, // ms entre tentativas de reconexão
  maxRetries: 10, // número máximo de tentativas por evento
  timeout: 15000 // timeout maior para conexões HTTPS (15 segundos)
};

// Cliente para conexão principal
const client = new Client(config.pgConfig);

// Cliente separado para notificações (evita bloqueios na conexão principal)
const notificationClient = new Client(config.pgConfig);

/**
 * Conecta ao PostgreSQL e configura o listener
 */
async function setupListener() {
  try {
    // Conectar ao PostgreSQL
    await client.connect();
    await notificationClient.connect();
    
    console.log(`[${new Date().toISOString()}] Conectado ao PostgreSQL em ${config.pgConfig.host}:${config.pgConfig.port}`);
    console.log(`[${new Date().toISOString()}] Escutando no canal: ${config.channelName}`);
    
    // Configurar LISTEN para o canal de eventos
    await notificationClient.query(`LISTEN ${config.channelName}`);
    
    // Manipulador de notificações
    notificationClient.on('notification', async (notification) => {
      try {
        console.log(`[${new Date().toISOString()}] Evento recebido:`, notification.channel);
        
        // Analisar o payload da notificação (convertendo de string para objeto)
        const payload = JSON.parse(notification.payload);
        
        // Enriquecer o payload com dados completos do evento
        const enrichedPayload = await enrichEventData(payload);
        
        // Enviar para o webhook
        await sendToWebhook(enrichedPayload);
      } catch (error) {
        console.error(`[${new Date().toISOString()}] Erro ao processar notificação:`, error.message);
      }
    });
    
    // Manipulador de erros
    notificationClient.on('error', handleConnectionError);
    client.on('error', handleConnectionError);
    
    console.log(`[${new Date().toISOString()}] Webhook listener iniciado - enviando eventos para ${config.webhookUrl}`);
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Erro na inicialização:`, error.message);
    // Tentar novamente após intervalo
    setTimeout(setupListener, config.retryInterval);
  }
}

/**
 * Enriquece os dados do evento com informações adicionais do banco
 */
async function enrichEventData(eventData) {
  try {
    // Obter os detalhes completos do evento
    const eventQuery = {
      text: `SELECT 
              e.*, 
              l.name AS lead_name, 
              l.email AS lead_email, 
              l.status AS lead_status,
              l.source AS lead_source
            FROM lead_events e
            LEFT JOIN leads l ON e.lead_id = l.id
            WHERE e.id = $1`,
      values: [eventData.id]
    };
    
    const result = await client.query(eventQuery);
    
    if (result.rows.length === 0) {
      throw new Error(`Evento não encontrado: ${eventData.id}`);
    }
    
    // Enriquecer com timestamp da API
    const enrichedData = { 
      ...result.rows[0],
      webhook_timestamp: new Date().toISOString(),
      event_type: result.rows[0].event_type
    };
    
    return enrichedData;
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Erro ao enriquecer dados:`, error.message);
    // Falha segura: retornar pelo menos os dados originais
    return { 
      ...eventData, 
      webhook_timestamp: new Date().toISOString(),
      error: error.message 
    };
  }
}

/**
 * Envia os dados do evento para o webhook configurado
 */
async function sendToWebhook(data, retryCount = 0) {
  try {
    console.log(`[${new Date().toISOString()}] Enviando para webhook (HTTPS): ${config.webhookUrl} [Construído com variáveis do Easypanel]`);
    
    // Opções de configuração para HTTPS
    const axiosOptions = {
      headers: {
        'Content-Type': 'application/json',
        'X-Webhook-Source': 'leadscrm-postgres',
        'X-Event-Type': data.event_type || 'unknown'
      },
      timeout: config.timeout // timeout configurado
    };
    
    // Adicionar opção para ignorar validação de certificado se configurado
    if (config.webhookInsecure) {
      console.log(`[${new Date().toISOString()}] AVISO: Validação de certificado SSL desativada (não seguro)`);
      axiosOptions.httpsAgent = new (require('https').Agent)({ rejectUnauthorized: false });
    }
    
    const response = await axios.post(config.webhookUrl, data, axiosOptions);
    
    console.log(`[${new Date().toISOString()}] Webhook enviado com sucesso. Status: ${response.status}`);
    return true;
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Erro ao enviar webhook:`, 
      error.response ? `Status ${error.response.status}: ${error.response.statusText}` : error.message);
    
    // Implementar retry com backoff exponencial
    if (retryCount < config.maxRetries) {
      const delay = Math.min(config.retryInterval * Math.pow(2, retryCount), 30000); // max 30s
      console.log(`[${new Date().toISOString()}] Tentando novamente em ${delay}ms (tentativa ${retryCount + 1}/${config.maxRetries})`);
      
      setTimeout(() => {
        sendToWebhook(data, retryCount + 1);
      }, delay);
    } else {
      console.error(`[${new Date().toISOString()}] Falha após ${config.maxRetries} tentativas, desistindo.`);
      // Aqui você poderia implementar um mecanismo de persistência para eventos não entregues
    }
    return false;
  }
}

/**
 * Manipula erros de conexão e tenta reconectar
 */
function handleConnectionError(error) {
  console.error(`[${new Date().toISOString()}] Erro de conexão:`, error.message);
  
  // Fechar conexões atuais
  try {
    client.end();
    notificationClient.end();
  } catch (e) {
    // Ignorar erros ao fechar conexões
  }
  
  // Tentar reconectar após intervalo
  console.log(`[${new Date().toISOString()}] Tentando reconectar em ${config.retryInterval}ms...`);
  setTimeout(setupListener, config.retryInterval);
}

// Processar sinais de término para desligar graciosamente
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

/**
 * Desliga o serviço graciosamente
 */
async function shutdown() {
  console.log(`[${new Date().toISOString()}] Desligando webhook listener...`);
  
  try {
    await client.end();
    await notificationClient.end();
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Erro ao desligar conexões:`, error.message);
  }
  
  process.exit(0);
}

// Iniciar o serviço
setupListener();
