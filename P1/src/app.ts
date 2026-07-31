import express, { type NextFunction, type Request, type Response } from "express";
import { pool } from "./config/database";
import { HttpError } from "./utils/http-error";
import { PostgresOperationalRequestRepository } from "./repositories/postgres-operational-request.repository";
import { OperationalRequestService } from "./services/operational-request.service";
import { OperationalRequestController } from "./controllers/operational-request.controller";
import { createOperationalRequestRouter } from "./routes/operational-request.routes";

const repository = new PostgresOperationalRequestRepository(pool);
const service = new OperationalRequestService(repository);
const controller = new OperationalRequestController(service);

export const app = express();

app.use(express.json());

app.get("/health", (_request, response) => {
  response.json({ status: "ok" });
});

app.use("/api/solicitudes", createOperationalRequestRouter(controller));

app.use((error: unknown, _request: Request, response: Response, _next: NextFunction) => {
  if (error instanceof HttpError) {
    response.status(error.statusCode).json({ error: error.message });
    return;
  }

  console.error(error);
  response.status(500).json({ error: "Error interno del servidor" });
});
