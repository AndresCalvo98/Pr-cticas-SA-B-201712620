const crypto = require('crypto');
require('dotenv').config();

// Se aplica el Principio de Responsabilidad Única (SRP) de SOLID:
// Este módulo se encarga EXCLUSIVAMENTE de la encriptación y desencriptación.
// No sabe de bases de datos, ni de endpoints, ni de JWT.

const algorithm = 'aes-256-cbc';
const secretKey = process.env.AES_SECRET_KEY || 'default_secret_key_123456789012'; // 32 chars minimum for aes-256-cbc

// Ensure secret key is exactly 32 bytes
const getValidKey = () => {
    return crypto.createHash('sha256').update(String(secretKey)).digest('base64').substring(0, 32);
};

const ivLength = 16;

const encrypt = (text) => {
    if (!text) return text;
    const iv = crypto.randomBytes(ivLength);
    const cipher = crypto.createCipheriv(algorithm, Buffer.from(getValidKey()), iv);
    let encrypted = cipher.update(text);
    encrypted = Buffer.concat([encrypted, cipher.final()]);
    return iv.toString('hex') + ':' + encrypted.toString('hex');
};

const decrypt = (text) => {
    if (!text) return text;
    try {
        const textParts = text.split(':');
        const iv = Buffer.from(textParts.shift(), 'hex');
        const encryptedText = Buffer.from(textParts.join(':'), 'hex');
        const decipher = crypto.createDecipheriv(algorithm, Buffer.from(getValidKey()), iv);
        let decrypted = decipher.update(encryptedText);
        decrypted = Buffer.concat([decrypted, decipher.final()]);
        return decrypted.toString();
    } catch (error) {
        console.error("Error decrypting data", error);
        return null;
    }
};

module.exports = {
    encrypt,
    decrypt
};
