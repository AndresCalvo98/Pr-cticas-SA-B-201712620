const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_jwt_key_here';
const JWT_EXPIRATION_TIME = process.env.JWT_EXPIRATION_TIME || '30s'; // configurable by env
const JWT_GRACE_PERIOD_MS = parseInt(process.env.JWT_GRACE_PERIOD_MS) || 5 * 60 * 1000; // default 5 mins

const authMiddleware = (req, res, next) => {
    const token = req.cookies.token;

    if (!token) {
        return res.status(401).json({ error: 'Access denied. No token provided.' });
    }

    try {
        // First try to verify normally
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded;
        next();
    } catch (err) {
        // If expired, check grace period
        if (err.name === 'TokenExpiredError') {
            const decodedExpired = jwt.verify(token, JWT_SECRET, { ignoreExpiration: true });
            
            // Check if within grace period
            const now = Date.now();
            const expiredAt = err.expiredAt.getTime();
            
            if (now - expiredAt <= JWT_GRACE_PERIOD_MS) {
                // Renew token
                const payload = {
                    id: decodedExpired.id,
                    name: decodedExpired.name,
                    role: decodedExpired.role
                };
                
                const newToken = jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRATION_TIME });
                
                res.cookie('token', newToken, {
                    httpOnly: true,
                    secure: false, 
                    sameSite: 'strict',
                    maxAge: 24 * 60 * 60 * 1000
                });

                req.user = payload;
                console.log(`[AUTH] Token renovado para usuario ${payload.name}`);
                return next();
            } else {
                return res.status(401).json({ error: 'Token expired and grace period passed. Please login again.' });
            }
        }
        return res.status(401).json({ error: 'Invalid token.' });
    }
};

module.exports = authMiddleware;
