import { afterEach, describe, expect, it } from "vitest";
import type { FastifyInstance } from "fastify";
import { BODY_LIMIT_BYTES, RATE_LIMIT_PER_MINUTE } from "../src/app.js";
import { collectLogs, fakeDb, makeApp, ORIGIN, SECRET_PASSWORD } from "./helpers.js";

let app: FastifyInstance;
afterEach(async () => { await app?.close(); });

describe("health endpoints", () => {
  it("/healthz is 200 even when MongoDB is down", async () => {
    ({ app } = await makeApp(fakeDb(false)));
    const res = await app.inject({ method: "GET", url: "/healthz" });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ status: "ok", service: "medtechtycoon-api" });
  });

  it("/readyz is 503 when MongoDB is down and 200 once it is up", async () => {
    const db = fakeDb(false);
    ({ app } = await makeApp(db));
    const down = await app.inject({ method: "GET", url: "/readyz" });
    expect(down.statusCode).toBe(503);
    expect(down.json()).toEqual({ status: "unavailable", service: "medtechtycoon-api", checks: { mongodb: "down" } });
    expect(down.headers["cache-control"]).toBe("no-store");

    db.setUp(true);
    const up = await app.inject({ method: "GET", url: "/readyz" });
    expect(up.statusCode).toBe(200);
    expect(up.json()).toEqual({ status: "ready", service: "medtechtycoon-api", checks: { mongodb: "up" } });
  });

  it("/status returns only service, version and uptime", async () => {
    ({ app } = await makeApp(fakeDb(true)));
    const body = (await app.inject({ method: "GET", url: "/status" })).json();
    expect(Object.keys(body).sort()).toEqual(["service", "uptimeSeconds", "version"]);
  });
});

describe("CORS", () => {
  it("allows the GitHub Pages origin", async () => {
    ({ app } = await makeApp(fakeDb(true)));
    const res = await app.inject({ method: "GET", url: "/healthz", headers: { origin: ORIGIN } });
    expect(res.headers["access-control-allow-origin"]).toBe(ORIGIN);
    expect(res.headers["access-control-allow-credentials"]).toBeUndefined();
  });

  it("answers a preflight from the allowed origin with Authorization allowed", async () => {
    ({ app } = await makeApp(fakeDb(true)));
    const res = await app.inject({ method: "OPTIONS", url: "/healthz",
      headers: { origin: ORIGIN, "access-control-request-method": "PUT", "access-control-request-headers": "authorization,content-type" } });
    expect(res.statusCode).toBe(204);
    expect(res.headers["access-control-allow-origin"]).toBe(ORIGIN);
    expect(String(res.headers["access-control-allow-headers"]).toLowerCase()).toContain("authorization");
  });

  it.each(["https://evil.example", "https://jarcsys-collab.github.io.evil.example", "http://jarcsys-collab.github.io", "null"])(
    "does not allow origin %s", async (origin) => {
      ({ app } = await makeApp(fakeDb(true)));
      const res = await app.inject({ method: "GET", url: "/healthz", headers: { origin } });
      expect(res.headers["access-control-allow-origin"]).toBeUndefined();
    });
});

describe("errors and limits", () => {
  it("returns JSON 404 for unknown routes and exposes no player endpoints", async () => {
    ({ app } = await makeApp(fakeDb(true)));
    for (const url of ["/nope", "/players", "/saves/1", "/leaderboard"]) {
      const res = await app.inject({ method: "GET", url });
      expect(res.statusCode).toBe(404);
      expect(res.json()).toEqual({ error: "not_found", message: "Not Found" });
    }
  });

  it("hides internal error details from the client and redacts them in logs", async () => {
    const logs = collectLogs();
    ({ app } = await makeApp(fakeDb(true), logs));
    app.get("/boom", async () => { throw new Error(`connect failed for mongodb+srv://u:${SECRET_PASSWORD}@host/db`); });
    const res = await app.inject({ method: "GET", url: "/boom" });
    expect(res.statusCode).toBe(500);
    expect(res.json()).toEqual({ error: "internal_error", message: "Internal Server Error" });
    expect(res.body).not.toMatch(/stack|at .*\.ts|mongodb/i);
    expect(logs.lines.join("")).toContain("request failed");
    expect(logs.lines.join("")).not.toContain(SECRET_PASSWORD);
  });

  it("rejects bodies over the size limit with 413", async () => {
    ({ app } = await makeApp(fakeDb(true)));
    app.post("/echo", async () => ({ ok: true }));
    const res = await app.inject({ method: "POST", url: "/echo", headers: { "content-type": "application/json" },
      payload: JSON.stringify({ blob: "x".repeat(BODY_LIMIT_BYTES + 1) }) });
    expect(res.statusCode).toBe(413);
    expect(res.json().message).not.toMatch(/stack/i);
  });

  it("returns 400 JSON for malformed JSON bodies", async () => {
    ({ app } = await makeApp(fakeDb(true)));
    app.post("/echo", async () => ({ ok: true }));
    const res = await app.inject({ method: "POST", url: "/echo", headers: { "content-type": "application/json" }, payload: "{bad" });
    expect(res.statusCode).toBe(400);
    expect(res.json()).toHaveProperty("error");
  });
});

describe("security headers, rate limiting and logging", () => {
  it("sets security headers suitable for a JSON API", async () => {
    ({ app } = await makeApp(fakeDb(true)));
    const h = (await app.inject({ method: "GET", url: "/healthz" })).headers;
    expect(h["content-security-policy"]).toContain("default-src 'none'");
    expect(h["x-content-type-options"]).toBe("nosniff");
    expect(h["strict-transport-security"]).toBeDefined();
    expect(h["x-frame-options"]).toBeDefined();
    expect(h["x-powered-by"]).toBeUndefined();
  });

  it("rate-limits a single client", async () => {
    ({ app } = await makeApp(fakeDb(true)));
    let last = 0;
    for (let i = 0; i <= RATE_LIMIT_PER_MINUTE; i++) last = (await app.inject({ method: "GET", url: "/healthz" })).statusCode;
    expect(last).toBe(429);
  });

  it("does not log Authorization headers", async () => {
    const logs = collectLogs();
    ({ app } = await makeApp(fakeDb(true), logs));
    await app.inject({ method: "GET", url: "/healthz", headers: { authorization: `Bearer ${SECRET_PASSWORD}` } });
    expect(logs.lines.length).toBeGreaterThan(0);
    expect(logs.lines.join("")).not.toContain(SECRET_PASSWORD);
  });
});
