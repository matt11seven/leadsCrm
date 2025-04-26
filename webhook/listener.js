// Webhook Listener para eventos do PostgreSQL
import { Client } from 'pg';
import fetch from 'node-fetch';

// Carrega variáveis de ambiente
const DATABASE_URL = process.env.DATABASE_URL;
const WEBHOOK_URL = process.env.WEBHOOK_URL;

if (!DATABASE_URL) {
  console.error('DATABASE_URL não definida');
  process.exit(1);
}

if (!WEBHOOK_URL) {
  console.error('WEBHOOK_URL não definida');
  process.exit(1);
}

console.log(`Iniciando webhook listener...`);
console.log(`Eventos serão enviados para: ${WEBHOOK_URL}`);

// Inicializa cliente PostgreSQL
const client = new Client({ connectionString: DATABASE_URL });

async function start() {
  try {
    await client.connect();
    console.log('Conectado ao PostgreSQL');
    
    // Configura o listener para o canal de eventos
    await client.query('LISTEN lead_event_channel');
    console.log('Escutando notificações no canal lead_event_channel');

    // Handler para notificações recebidas
    client.on('notification', async (msg) => {
      try {
        console.log(`Recebida notificação: ${msg.channel}`);
        const payload = JSON.parse(msg.payload);
        
        // Envia o payload para o webhook configurado
        const response = await fetch(WEBHOOK_URL, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        });
        
        console.log(`Webhook enviado. Status: ${response.status}`);
      } catch (error) {
        console.error('Erro ao processar notificação:', error);
      }
    });

    // Mantém a conexão ativa
    setInterval(async () => {
      await client.query('SELECT 1');
    }, 30000);
    
  } catch (error) {
    console.error('Erro ao iniciar listener:', error);
    process.exit(1);
  }
}

// Gestão de encerramento
process.on('SIGINT', async () => {
  console.log('Encerrando...');
  await client.end();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  console.log('Encerrando...');
  await client.end();
  process.exit(0);
});

// Inicia o serviço
start();
