const { Client } = require('pg');
const amqp = require('amqplib');

const pgClient = new Client({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: 5432,
});

const RABBITMQ_URL = process.env.RABBITMQ_URL || 'amqp://localhost';

async function run() {
  try {
    await pgClient.connect();
    
    // Contar ejecuciones de la última hora
    const res = await pgClient.query(`
      SELECT COUNT(*) as count 
      FROM cron_logs 
      WHERE executed_at >= NOW() - INTERVAL '1 hour'
    `);
    
    const count = res.rows[0].count;
    const summaryMsg = `Resumen: ${count} ejecuciones del Cronjob 1 en la ultima hora.`;
    console.log(`[CronJob 2] ${summaryMsg}`);

    // Publicar en RabbitMQ
    const rabbitConn = await amqp.connect(RABBITMQ_URL);
    const channel = await rabbitConn.createChannel();
    const queue = 'cron_summary_queue';
    
    await channel.assertQueue(queue, { durable: true });
    channel.sendToQueue(queue, Buffer.from(summaryMsg), { persistent: true });
    
    console.log('[CronJob 2] Mensaje publicado en RabbitMQ.');
    
    setTimeout(() => {
      rabbitConn.close();
      pgClient.end();
      process.exit(0);
    }, 500);

  } catch (error) {
    console.error('Error ejecutando CronJob 2:', error);
    process.exit(1);
  }
}

run();
