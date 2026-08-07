const db = require('../db');
const { encrypt, decrypt } = require('../utils/crypto');
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_jwt_key_here';
const JWT_EXPIRATION_TIME = process.env.JWT_EXPIRATION_TIME || '30s'; // configurable by env

exports.register = (req, res) => {
    const { name, email, password, role } = req.body;

    if (!name || !email || !password || !role) {
        return res.status(400).json({ error: 'All fields are required' });
    }

    if (role !== 'Admin' && role !== 'Cliente') {
        return res.status(400).json({ error: 'Invalid role. Must be Admin or Cliente.' });
    }

    db.all(`SELECT * FROM users`, [], (err, users) => {
        if (err) return res.status(500).json({ error: 'Database error' });
        
        const userExists = users.find(u => decrypt(u.email) === email);
        if (userExists) {
            return res.status(409).json({ error: 'Email already exists' });
        }

        // Encrypt sensitive data
        const encName = encrypt(name);
        const encEmail = encrypt(email);
        const encPassword = encrypt(password);

        db.run(
            `INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)`,
            [encName, encEmail, encPassword, role],
            function (err) {
                if (err) return res.status(500).json({ error: 'Database error' });
                res.status(201).json({ message: 'User registered successfully', userId: this.lastID });
            }
        );
    });
};

exports.login = (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ error: 'Email and password are required' });
    }

    db.all(`SELECT * FROM users`, [], (err, users) => {
        if (err) {
            return res.status(500).json({ error: 'Database error' });
        }
        
        const user = users.find(u => decrypt(u.email) === email);
        
        if (!user) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const decPassword = decrypt(user.password);
        if (decPassword !== password) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Authentication successful
        const decName = decrypt(user.name);
        
        const payload = {
            id: user.id,
            name: decName,
            role: user.role
        };

        const token = jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRATION_TIME });

        // Set HTTP-only cookie
        res.cookie('token', token, {
            httpOnly: true,
            secure: false, // set to true if using HTTPS
            sameSite: 'strict',
            maxAge: 24 * 60 * 60 * 1000 // 1 day in ms for browser keep-alive
        });

        res.json({ message: 'Login successful', role: user.role, name: decName });
    });
};

exports.logout = (req, res) => {
    res.clearCookie('token');
    res.json({ message: 'Logged out successfully' });
};
