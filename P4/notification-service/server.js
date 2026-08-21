const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

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

// Simulamos recepción asíncrona mediante un endpoint REST para pruebas
app.post('/api/notifications', (req, res) => {
    const { batchId, type } = req.body;
    const message = `Lote ${batchId} ha sido procesado.`;

    let notificator;
    if (type === 'SMS') {
        notificator = new SMSNotificator();
    } else {
        notificator = new EmailNotificator();
    }

    // Funciona igual sin importar la subclase (LSP)
    notificator.send(message);

    res.json({ status: "Notificación enviada" });
});

const PORT = 4003;
app.listen(PORT, () => {
    console.log(`Notification Service (Node.js) corriendo en puerto ${PORT}`);
});
