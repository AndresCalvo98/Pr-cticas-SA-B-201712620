// SOLID: Open/Closed Principle (OCP)
// Las estrategias de aprobación están abiertas a extensión (podemos agregar más roles)
// pero cerradas a modificación (no tocamos este archivo si agregamos "AuditorStrategy")

class ApprovalStrategy {
    approve(batchId) {
        throw new Error("Method 'approve()' must be implemented.");
    }
}

class CheckerStrategy extends ApprovalStrategy {
    approve(batchId) {
        console.log(`[Checker] Revisión de primer nivel aprobada para el lote ${batchId}.`);
        return "PENDING_AUTHORIZER";
    }
}

class AuthorizerStrategy extends ApprovalStrategy {
    approve(batchId) {
        console.log(`[Authorizer] Autorización final aprobada para el lote ${batchId}. Emitiendo evento a RabbitMQ...`);
        return "APPROVED";
    }
}

class ApprovalContext {
    constructor(strategy) {
        this.strategy = strategy;
    }
    execute(batchId) {
        return this.strategy.approve(batchId);
    }
}

module.exports = {
    CheckerStrategy,
    AuthorizerStrategy,
    ApprovalContext
};
