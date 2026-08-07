const express = require('express');
const cookieParser = require('cookie-parser');
const cors = require('cors');
const path = require('path');
require('dotenv').config();

const apiRoutes = require('./routes/api');

const app = express();

app.use(cors({
    origin: true,
    credentials: true
}));
app.use(express.json());
app.use(cookieParser());

// Serve static frontend files
app.use(express.static(path.join(__dirname, '../../frontend')));

app.use('/api', apiRoutes);

// Principio de Inversion de Dependencias (DIP):
// El servidor confía en la abstracción de rutas en '/api' en lugar de implementar
// toda la lógica de negocio aquí.
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Backend API corriendo en el puerto ${PORT}`);
});
