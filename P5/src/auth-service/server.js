const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// Principio Abierto/Cerrado (OCP) de SOLID:
// Podríamos tener la lógica quemada, pero usar un mapa de permisos permite
// extender las rutas y roles fácilmente sin modificar la lógica principal.
const rolePermissions = {
    'Admin': ['/api/ruta1', '/api/ruta2'],
    'Cliente': ['/api/ruta2']
};

app.post('/authorize', (req, res) => {
    const { role, path } = req.body;
    
    console.log(`[AUTHZ-SERVICE] Recibida peticion de autorizacion: Role=${role}, Path=${path}`);

    if (!role || !path) {
        return res.status(400).json({ error: 'role and path are required' });
    }

    const allowedPaths = rolePermissions[role];
    if (allowedPaths && allowedPaths.includes(path)) {
        return res.json({ allowed: true });
    }

    return res.json({ allowed: false });
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
    console.log(`Microservicio de Autorizacion corriendo en puerto ${PORT}`);
});
