const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// Archivo local de base de datos SQLite
const dbPath = path.resolve(__dirname, '../../database.sqlite');
const db = new sqlite3.Database(dbPath);

db.serialize(() => {
    db.run(`
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            role TEXT NOT NULL
        )
    `, (err) => {
        if (err) {
            console.error("Error creando la tabla users:", err.message);
        } else {
            console.log("Tabla users lista");
        }
    });
});

module.exports = db;
