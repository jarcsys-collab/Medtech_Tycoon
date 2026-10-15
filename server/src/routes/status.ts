import type { FastifyInstance } from "fastify";
import { SERVICE_NAME } from "./health.js";

/** Public, harmless build info for checking which version is deployed. */
export async function statusRoutes(app: FastifyInstance, opts: { version: string }): Promise<void> {
  const startedAt = Date.now();
  app.get("/status", async () => ({
    service: SERVICE_NAME,
    version: opts.version,
    uptimeSeconds: Math.floor((Date.now() - startedAt) / 1000),
  }));
}
