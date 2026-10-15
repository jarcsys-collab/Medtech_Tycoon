// Integration tests against a throwaway local mongod (mongodb-memory-server). Never touches Atlas.
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { MongoMemoryServer } from "mongodb-memory-server";
import { Database, type DbLogger } from "../src/db/mongodb.js";
import { redact } from "../src/db/redact.js";
import { makeApp, SECRET_PASSWORD } from "./helpers.js";

function captureLogger() {
  const entries: string[] = [];
  const logger: DbLogger = {
    info: (obj, msg) => entries.push(JSON.stringify({ level: "info", msg, ...obj })),
    warn: (obj, msg) => entries.push(JSON.stringify({ level: "warn", msg, ...obj })),
  };
  return { entries, logger };
}

let mongod: MongoMemoryServer;
beforeAll(async () => { mongod = await MongoMemoryServer.create(); });
afterAll(async () => { await mongod?.stop(); });

describe("Database (real driver, local mongod)", () => {
  it("connects, reuses one client, and reports ready", async () => {
    const { logger, entries } = captureLogger();
    const db = new Database({ uri: mongod.getUri(), dbName: "medtechtycoon_test", logger });
    expect(await db.connect()).toBe(true);
    const client = db.client;
    expect(await db.ping()).toBe(true);
    expect(await db.ping()).toBe(true);
    expect(db.client).toBe(client);
    expect(entries.some((e) => e.includes("MongoDB connected"))).toBe(true);

    const { app } = await makeApp(db);
    const res = await app.inject({ method: "GET", url: "/readyz" });
    expect(res.statusCode).toBe(200);
    await app.close();
    await db.close();
    expect(await db.ping()).toBe(false); // closed client is never reported ready
  });

  it("reports 503 when the server goes away, then recovers when it returns", async () => {
    const temp = await MongoMemoryServer.create();
    const { logger } = captureLogger();
    const db = new Database({ uri: temp.getUri(), dbName: "medtechtycoon_test", logger, serverSelectionTimeoutMS: 1000, pingTimeoutMS: 1500 });
    expect(await db.connect()).toBe(true);
    const { app } = await makeApp(db);

    await temp.stop({ doCleanup: false });
    expect((await app.inject({ method: "GET", url: "/readyz" })).statusCode).toBe(503);
    expect((await app.inject({ method: "GET", url: "/healthz" })).statusCode).toBe(200);

    await temp.start(true); // same port
    let ready = false;
    for (let i = 0; i < 20 && !ready; i++) {
      ready = (await app.inject({ method: "GET", url: "/readyz" })).statusCode === 200;
      if (!ready) await new Promise((r) => setTimeout(r, 500));
    }
    expect(ready).toBe(true);
    await app.close();
    await db.close();
    await temp.stop();
  });

  it("fails fast and logs without credentials when the server is unreachable", async () => {
    const { logger, entries } = captureLogger();
    const uri = `mongodb://mtt_dev:${SECRET_PASSWORD}@127.0.0.1:1/?directConnection=true`;
    const db = new Database({ uri, dbName: "medtechtycoon_test", logger, serverSelectionTimeoutMS: 800, pingTimeoutMS: 1000 });
    const started = Date.now();
    expect(await db.connect()).toBe(false);
    expect(Date.now() - started).toBeLessThan(5000);
    expect(await db.ping()).toBe(false);

    const { app } = await makeApp(db);
    const res = await app.inject({ method: "GET", url: "/readyz" });
    expect(res.statusCode).toBe(503);
    expect(res.body).not.toContain(SECRET_PASSWORD);
    expect(res.body).not.toContain("127.0.0.1");
    const logged = entries.join("\n");
    expect(logged).toContain("MongoDB not reachable yet");
    expect(logged).not.toContain(SECRET_PASSWORD);
    await app.close();
    await db.close();
  });
});

describe("redact", () => {
  it("removes credentials and query strings from connection strings", () => {
    const out = redact(`failed: mongodb+srv://user:${SECRET_PASSWORD}@cluster0.example.invalid/db?authSource=admin&tls=true`);
    expect(out).not.toContain(SECRET_PASSWORD);
    expect(out).not.toContain("authSource");
    expect(out).toContain("mongodb+srv://***@");
  });
});
