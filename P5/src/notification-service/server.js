const express = require('express');
const cors = require('cors');
const amqp = require('amqplib');

const app = express();
app.use(cors());
app.use(express.json());

const RABBITMQ_URL = process.env.RABBITMQ_URL || 'amqp://localhost';

// SOLID: Liskov Substitution Principle (LSP)
// Ambas clases hijas pueden sustituir a la clase padre sin alterar el comportamiento.
class Notificator {
    send(message) {
        throw new Error("Method 'send()' must be implemented.");
    }
}

class EmailNotificator extends Notificator {
    send(message) {
        console.log(`[Email] Enviando correo: ${message}`);
    }
}

class SMSNotificator extends Notificator {
    send(message) {
        console.log(`[SMS] Enviando mensaje de texto: ${message}`);
    }
}

// Consumidor asíncrono
async function startConsumer() {
    try {
        const connection = await amqp.connect(RABBITMQ_URL);
        const channel = await connection.createChannel();
        const queue = 'notifications_queue';
        
        await channel.assertQueue(queue, { durable: true });
        channel.prefetch(1); // Procesar de a 1 mensaje para evitar saturación
        
        console.log(`[*] Waiting for messages in ${queue}. To exit press CTRL+C`);
        
        channel.consume(queue, (msg) => {
            if (msg !== null) {
                const data = JSON.parse(msg.content.toString());
                console.log(`[x] Received %s`, msg.content.toString());
                
                const notificator = new EmailNotificator();
                notificator.send(`Lote ${data.batchId} ha sido procesado con estado: ${data.status}`);
                
                // Confirmar procesamiento exitoso (evita perder mensajes si se cae el pod)
                channel.ack(msg);
            }
        }, { noAck: false }); // Requiere confirmación manual
    } catch (err) {
        console.error('Error connecting to RabbitMQ, retrying in 5 seconds...', err);
        setTimeout(startConsumer, 5000);
    }
}

startConsumer();

const PORT = 4003;
app.listen(PORT, () => {
    console.log(`Notification Service (Node.js) corriendo en puerto ${PORT}`);
});
