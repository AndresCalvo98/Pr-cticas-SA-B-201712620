const axios = require('axios');
const axiosRetry = require('axios-retry').default;

// Configurar axios globalmente para esta instancia
const authzClient = axios.create({
    baseURL: 'http://localhost:4000',
    timeout: 2000 // 2 seconds timeout for each request
});

// Implementacion de ciclo de reintentos (retry loop con backoff)
axiosRetry(authzClient, { 
    retries: 3, 
    retryDelay: (retryCount) => {
        console.log(`[RETRY] Reintentando conexion a authz-service. Intento ${retryCount}...`);
        return retryCount * 1000; // 1s, 2s, 3s backoff
    },
    retryCondition: (error) => {
        // Reintentar en caso de error de red o timeout
        return axiosRetry.isNetworkOrIdempotentRequestError(error) || error.code === 'ECONNABORTED';
    }
});

const roleMiddleware = async (req, res, next) => {
    try {
        const { role } = req.user;
        const requestedPath = req.originalUrl; // e.g. /api/ruta1

        const response = await authzClient.post('/authorize', {
            role: role,
            path: requestedPath
        });

        if (response.data.allowed) {
            next();
        } else {
            res.status(403).json({ error: 'Forbidden. Access denied for your role.' });
        }
    } catch (error) {
        console.error('[ROLE-MW] Error conectando al servicio de autorizacion despues de reintentos:', error.message);
        res.status(503).json({ error: 'Authorization service unavailable. Please try again later.' });
    }
};

module.exports = roleMiddleware;
