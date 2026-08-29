const express = require('express');
const cors = require('cors');
const { graphqlHTTP } = require('express-graphql');
const { buildSchema } = require('graphql');
const { CheckerStrategy, AuthorizerStrategy, ApprovalContext } = require('./approvalStrategy');
const amqp = require('amqplib');

const RABBITMQ_URL = process.env.RABBITMQ_URL || 'amqp://localhost';

async function publishNotification(batchId, status) {
    try {
        const connection = await amqp.connect(RABBITMQ_URL);
        const channel = await connection.createChannel();
        const queue = 'notifications_queue';
        await channel.assertQueue(queue, { durable: true });
        
        const msg = JSON.stringify({ batchId, status });
        channel.sendToQueue(queue, Buffer.from(msg), { persistent: true });
        console.log(`[x] Sent to queue: ${msg}`);
        
        setTimeout(() => { connection.close(); }, 500);
    } catch (err) {
        console.error('Error publishing to RabbitMQ:', err);
    }
}

const app = express();
app.use(cors());
app.use(express.json());

// Simulamos base de datos NoSQL
const workflows = [
    { batchId: "batch-123", status: "PENDING_CHECKER" }
];

// 1. ENDPOINTS REST
app.post('/api/approvals/:batchId', (req, res) => {
    const { batchId } = req.params;
    const { role } = req.body;

    let strategy;
    if (role === 'Checker') {
        strategy = new CheckerStrategy();
    } else if (role === 'Authorizer') {
        strategy = new AuthorizerStrategy();
    } else {
        return res.status(403).json({ error: 'Role not authorized for approvals' });
    }

    const context = new ApprovalContext(strategy);
    const newStatus = context.execute(batchId);
    
    // Actualizamos BD mock
    let wf = workflows.find(w => w.batchId === batchId);
    if(wf) wf.status = newStatus;

    if (newStatus === 'APPROVED') {
        publishNotification(batchId, newStatus);
    }

    res.json({ message: "Aprobación registrada", status: newStatus });
});

// 2. ENDPOINT GRAPHQL (Para cumplir rúbrica de 2 servicios con GraphQL)
const schema = buildSchema(`
  type Workflow {
    batchId: String!
    status: String!
  }
  type Query {
    getWorkflow(batchId: String!): Workflow
  }
`);

const root = {
  getWorkflow: ({ batchId }) => workflows.find(w => w.batchId === batchId)
};

app.use('/graphql', graphqlHTTP({
  schema: schema,
  rootValue: root,
  graphiql: true,
}));

const PORT = 4002;
app.listen(PORT, () => {
    console.log(`Approval Service (Node.js) corriendo en puerto ${PORT}`);
});
