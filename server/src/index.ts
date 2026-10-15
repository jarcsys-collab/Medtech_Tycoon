import { readFileSync } from "node:fs";
import { ConfigError, loadConfig } from "./config/env.js";
import { Database } from "./db/mongodb.js";
import { describeError } from "./db/redact.js";
import { buildApp } from "./app.js";

const SHUTDOWN_TIMEOUT_MS = 10_000;

async function main(): Promise<void> {
  let config;
  try {
    config = loadConfig();
  } catch (err) {
    // Names and rules only; ConfigError never contains values.
    console.error(err instanceof ConfigError ? err.message : "Failed to read configuration");
    process.exit(1);
  }

  const { version } = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8")) as { version: string };
  const app = await buildApp({ config, version, db: { ping: async () => db.ping() } });
  const db = new Database({ uri: config.mongodbUri, dbName: config.mongodbDbName, logger: app.log });

  let shuttingDown = false;
  const shutdown = async (signal: string) => {
    if (shuttingDown) return;
    shuttingDown = true;
    app.log.info({ signal }, "shutting down");
    const force = setTimeout(() => {
      app.log.error({}, "graceful shutdown timed out; exiting");
      process.exit(1);
    }, SHUTDOWN_TIMEOUT_MS);
    force.unref();
    try {
      await app.close(); // stop accepting connections, finish in-flight requests
      await db.close();
      process.exit(0);
    } catch {
      process.exit(1);
    }
  };
  process.on("SIGTERM", () => void shutdown("SIGTERM"));
  process.on("SIGINT", () => void shutdown("SIGINT"));

  await app.listen({ host: "0.0.0.0", port: config.port });
  app.log.info({ version, db: config.mongodbDbName, origins: config.allowedOrigins }, "medtechtycoon-api started");
  // Connect after listening so /healthz answers while Atlas is slow or down.
  void db.connect();
}

main().catch((err: unknown) => {
  const { name, code, message } = describeError(err);
  console.error(`medtechtycoon-api failed to start: ${name}${code ? ` (${code})` : ""}: ${message}`);
  process.exit(1);
});
