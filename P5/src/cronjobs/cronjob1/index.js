const { Client } = require('pg');

const client = new Client({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: 5432,
});

async function run() {
  try {
    await client.connect();
    
    // Crear tabla si no existe
    await client.query(`
      CREATE TABLE IF NOT EXISTS cron_logs (
        id SERIAL PRIMARY KEY,
        carne VARCHAR(50) NOT NULL,
        executed_at TIMESTAMP NOT NULL
      );
    `);

    // Obtener hora GMT-6
    const date = new Date();
    date.setHours(date.getHours() - 6);
    
    const carne = process.env.CARNE || '201712620';
    
    await client.query(
      'INSERT INTO cron_logs (carne, executed_at) VALUES ($1, $2)',
      [carne, date]
    );

    console.log(`[CronJob 1] Registro insertado exitosamente: ${carne} at ${date.toISOString()}`);
  } catch (error) {
    console.error('Error ejecutando CronJob 1:', error);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
