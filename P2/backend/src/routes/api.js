const express = require('express');
const router = express.Router();

const authController = require('../controllers/authController');
const authMiddleware = require('../middlewares/authMiddleware');
const roleMiddleware = require('../middlewares/roleMiddleware');

router.post('/register', authController.register);
router.post('/login', authController.login);
router.post('/logout', authController.logout);

// Protected routes
router.get('/ruta1', authMiddleware, roleMiddleware, (req, res) => {
    res.json({ message: 'Bienvenido a Ruta 1! (Acceso permitido)', user: req.user.name });
});

router.get('/ruta2', authMiddleware, roleMiddleware, (req, res) => {
    res.json({ message: 'Bienvenido a Ruta 2! (Acceso permitido)', user: req.user.name });
});

// Endpoint just to get current user info for UI
router.get('/me', authMiddleware, (req, res) => {
    res.json({ user: req.user });
});

module.exports = router;
