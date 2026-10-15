import type { FastifyInstance } from "fastify";
import type { DatabaseHealth } from "../db/mongodb.js";

export const SERVICE_NAME = "medtechtycoon-api";

/** Liveness (process up) and readiness (dependencies up). Responses carry no configuration. */
export async function healthRoutes(app: FastifyInstance, opts: { db: DatabaseHealth }): Promise<void> {
  app.get("/healthz", async () => ({ status: "ok", service: SERVICE_NAME }));

  app.get("/readyz", async (_request, reply) => {
    const mongodb = await opts.db.ping();
    reply.header("Cache-Control", "no-store");
    if (!mongodb) {
      return reply.status(503).send({ status: "unavailable", service: SERVICE_NAME, checks: { mongodb: "down" } });
    }
    return { status: "ready", service: SERVICE_NAME, checks: { mongodb: "up" } };
  });
}
