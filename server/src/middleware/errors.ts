import type { FastifyError, FastifyInstance } from "fastify";
import { describeError } from "../db/redact.js";

/**
 * Uniform JSON errors. 4xx keep Fastify's short client-facing message (e.g. body too large);
 * 5xx return a generic message. Stack traces and internals are only logged, redacted.
 */
export function registerErrorHandlers(app: FastifyInstance): void {
  app.setErrorHandler((err: FastifyError, request, reply) => {
    const status = err.statusCode && err.statusCode >= 400 && err.statusCode < 600 ? err.statusCode : 500;
    if (status >= 500) {
      request.log.error({ err: describeError(err) }, "request failed");
      return reply.status(status).send({ error: "internal_error", message: "Internal Server Error" });
    }
    return reply.status(status).send({ error: err.code ?? "bad_request", message: err.message });
  });

  app.setNotFoundHandler((_request, reply) => reply.status(404).send({ error: "not_found", message: "Not Found" }));
}
