import { describe, expect, it } from "vitest";
import { ConfigError, loadConfig } from "../src/config/env.js";
import { FAKE_URI, SECRET_PASSWORD } from "./helpers.js";

const valid = {
  NODE_ENV: "production",
  PORT: "8080",
  MONGODB_URI: FAKE_URI,
  MONGODB_DB_NAME: "medtechtycoon_dev",
  ALLOWED_ORIGIN: "https://jarcsys-collab.github.io",
};

function problems(env: Record<string, string | undefined>): string[] {
  try {
    loadConfig(env);
  } catch (err) {
    expect(err).toBeInstanceOf(ConfigError);
    return (err as ConfigError).problems;
  }
  throw new Error("expected loadConfig to throw");
}

describe("environment validation", () => {
  it("accepts a valid Phase 2 configuration without Entra variables", () => {
    const c = loadConfig(valid);
    expect(c).toMatchObject({ nodeEnv: "production", port: 8080, mongodbDbName: "medtechtycoon_dev", allowedOrigins: ["https://jarcsys-collab.github.io"] });
    expect(c.entra).toEqual({ tenantId: undefined, apiAudience: undefined });
  });

  it("treats blank Entra variables as unset", () => {
    expect(loadConfig({ ...valid, ENTRA_TENANT_ID: "", ENTRA_API_AUDIENCE: "  " }).entra.tenantId).toBeUndefined();
  });

  it("defaults PORT and NODE_ENV", () => {
    const { PORT, NODE_ENV, ...rest } = valid;
    expect(loadConfig(rest)).toMatchObject({ port: 3000, nodeEnv: "development" });
  });

  it("reports every missing required variable by name", () => {
    const p = problems({});
    expect(p).toEqual(expect.arrayContaining(["MONGODB_URI is required", "MONGODB_DB_NAME is required", "ALLOWED_ORIGIN is required"]));
  });

  it("never includes values in the error, even for a bad URI", () => {
    const err = (() => { try { loadConfig({ ...valid, MONGODB_URI: `postgres://u:${SECRET_PASSWORD}@h/db` }); } catch (e) { return e as Error; } })();
    expect(err).toBeInstanceOf(ConfigError);
    expect(err!.message).toContain("MONGODB_URI");
    expect(err!.message).not.toContain(SECRET_PASSWORD);
  });

  it.each([
    ["path", "https://jarcsys-collab.github.io/Medtech_Tycoon/"],
    ["trailing slash", "https://jarcsys-collab.github.io/"],
    ["wildcard", "*"],
    ["wildcard host", "https://*.github.io"],
    ["plain http", "http://jarcsys-collab.github.io"],
    ["not a URL", "jarcsys-collab.github.io"],
  ])("rejects an ALLOWED_ORIGIN with a %s", (_label, value) => {
    expect(problems({ ...valid, ALLOWED_ORIGIN: value })[0]).toMatch(/^ALLOWED_ORIGIN/);
  });

  it("accepts a comma-separated origin list including localhost for development", () => {
    expect(loadConfig({ ...valid, ALLOWED_ORIGIN: "https://jarcsys-collab.github.io, http://localhost:8060" }).allowedOrigins)
      .toEqual(["https://jarcsys-collab.github.io", "http://localhost:8060"]);
  });

  it("only allows medtechtycoon_* database names", () => {
    expect(problems({ ...valid, MONGODB_DB_NAME: "receiptflow" })[0]).toMatch(/^MONGODB_DB_NAME/);
  });

  it("rejects a malformed ENTRA_TENANT_ID when one is provided", () => {
    expect(problems({ ...valid, ENTRA_TENANT_ID: "not-a-guid" })[0]).toMatch(/^ENTRA_TENANT_ID/);
  });

  it("rejects an invalid PORT", () => {
    expect(problems({ ...valid, PORT: "99999" })[0]).toMatch(/^PORT/);
  });
});
