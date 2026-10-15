import Fastify, { type FastifyInstance, type FastifyServerOptions } from "fastify";
import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import type { Config } from "./config/env.js";
import type { DatabaseHealth } from "./db/mongodb.js";
import { registerErrorHandlers } from "./middleware/errors.js";
import { healthRoutes } from "./routes/health.js";
import { statusRoutes } from "./routes/status.js";

export type AppDeps = {
  config: Pick<Config, "nodeEnv" | "allowedOrigins">;
  db: DatabaseHealth;
  version: string;
  /** Where logs go (default stdout). Tests pass a collector to assert nothing sensitive is logged. */
  logStream?: { write(line: string): void };
};

/** 16 KiB is ample for Phase 2 (no endpoint takes a body yet); raise per-route when cloud saves land. */
export const BODY_LIMIT_BYTES = 16 * 1024;
export const RATE_LIMIT_PER_MINUTE = 120;

export async function buildApp(deps: AppDeps): Promise<FastifyInstance> {
  const app = Fastify({
    logger: {
      level: deps.config.nodeEnv === "production" ? "info" : "debug",
      redact: { paths: ["req.headers.authorization", "req.headers.cookie", "*.password", "*.uri", "*.mongodbUri"], censor: "[redacted]" },
      ...(deps.logStream && { stream: deps.logStream }),
    } satisfies FastifyServerOptions["logger"],
    bodyLimit: BODY_LIMIT_BYTES,
    // Railway's edge proxy is the single trusted hop; the client IP is the address it appends.
    trustProxy: deps.config.nodeEnv === "production" ? (_address: string, hop: number) => hop === 0 : false,
    requestIdHeader: false,
  });

  await app.register(helmet, {
    // JSON API: nothing should be rendered or framed.
    contentSecurityPolicy: { directives: { defaultSrc: ["'none'"], frameAncestors: ["'none'"] } },
  });

  // Exact-match allowlist (scheme + host + port). Bearer tokens later, so no credentials/cookies.
  await app.register(cors, {
    origin: deps.config.allowedOrigins,
    methods: ["GET", "HEAD", "POST", "PUT", "DELETE"],
    allowedHeaders: ["Authorization", "Content-Type"],
    credentials: false,
    maxAge: 600,
  });

  await app.register(rateLimit, { max: RATE_LIMIT_PER_MINUTE, timeWindow: "1 minute" });

  registerErrorHandlers(app);
  await app.register(healthRoutes, { db: deps.db });
  await app.register(statusRoutes, { version: deps.version });
  return app;
}
