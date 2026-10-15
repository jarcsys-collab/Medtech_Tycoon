import { buildApp } from "../src/app.js";
import type { DatabaseHealth } from "../src/db/mongodb.js";

export const ORIGIN = "https://jarcsys-collab.github.io";
/** Fake secret used to prove credentials never leak into responses or logs. */
export const SECRET_PASSWORD = "S3cr3t-Do-Not-Leak-9f2c";
export const FAKE_URI = `mongodb+srv://mtt_dev:${SECRET_PASSWORD}@cluster0.example.invalid/?retryWrites=true`;

export function fakeDb(up: boolean): DatabaseHealth & { setUp(v: boolean): void } {
  let state = up;
  return { ping: async () => state, setUp: (v) => { state = v; } };
}

export function collectLogs() {
  const lines: string[] = [];
  return { lines, stream: { write: (line: string) => { lines.push(line); } } };
}

export async function makeApp(db: DatabaseHealth, logs = collectLogs(), nodeEnv: "test" | "production" = "test") {
  const app = await buildApp({ config: { nodeEnv, allowedOrigins: [ORIGIN] }, db, version: "0.1.0-test", logStream: logs.stream });
  return { app, logs };
}
