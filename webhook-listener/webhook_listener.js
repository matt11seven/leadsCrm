const { Client } = require('pg');
const axios = require('axios');
const dotenv = require('dotenv');

// Carregar as variáveis de ambiente
dotenv.config();

// Configurações do banco de dados
const dbConfig = {
  connectionString: process.env.DATABASE_URL,
};

// URL para onde enviar os webhooks
const webhookUrl = process.env.WEBHOOK_URL || 'http://localhost:8080/api/lead-event';

// Inicializa cliente PostgreSQL
const client = new Client(dbConfig);

// Função para conectar ao banco de dados e configurar o listener
async function startListener() {
  try {
    // Conectar ao banco de dados
    await client.connect();
    console.log('Conectado ao banco de dados PostgreSQL');

    // Configurar o listener para o canal lead_event_channel
    await client.query('LISTEN lead_event_channel');
    console.log(`Escutando notificações no canal 'lead_event_channel'`);
    console.log(`Webhooks serão enviados para: ${webhookUrl}`);

    // Configurar o handler para notificações
    client.on('notification', async (notification) => {
      try {
        // Processar a notificação
        const payload = JSON.parse(notification.payload);
        console.log(`Recebida notificação: ${notification.channel}`);
        console.log(`Evento: ${payload.event_type} para lead: ${payload.lead_id}`);

        // Enviar os dados para o webhook
        await sendWebhook(payload);
      } catch (error) {
        console.error('Erro ao processar notificação:', error);
      }
    });

    // Manter a conexão viva com polling
    setInterval(async () => {
      try {
        await client.query('SELECT 1');
      } catch (error) {
        console.error('Erro no heartbeat:', error);
        // Tentar reconectar se perder a conexão
        await reconnect();
      }
    }, 30000); // A cada 30 segundos

  } catch (error) {
    console.error('Erro ao iniciar o listener:', error);
    // Tentar reconectar em caso de erro
    setTimeout(reconnect, 5000);
  }
}

// Função para enviar os dados para o webhook
async function sendWebhook(payload) {
  try {
    const response = await axios.post(webhookUrl, payload, {
      headers: {
        'Content-Type': 'application/json',
        'X-Webhook-Source': 'lead-crm-postgres'
      }
    });
    
    console.log(`Webhook enviado com sucesso. Status: ${response.status}`);
    return true;
  } catch (error) {
    console.error('Erro ao enviar webhook:', error.message);
    return false;
  }
}

// Função para reconectar em caso de perda de conexão
async function reconnect() {
  try {
    // Fechar a conexão atual se estiver aberta
    if (client) {
      try {
        await client.end();
      } catch (e) {
        console.error('Erro ao fechar conexão:', e);
      }
    }
    
    // Iniciar uma nova conexão
    console.log('Tentando reconectar ao banco de dados...');
    setTimeout(startListener, 5000);
  } catch (error) {
    console.error('Erro ao reconectar:', error);
    setTimeout(reconnect, 5000);
  }
}

// Gerenciar o encerramento gracioso
process.on('SIGINT', async () => {
  console.log('Encerrando listener de webhook...');
  if (client) {
    await client.end();
  }
  process.exit(0);
});

process.on('SIGTERM', async () => {
  console.log('Encerrando listener de webhook...');
  if (client) {
    await client.end();
  }
  process.exit(0);
});

// Iniciar o listener
startListener();
