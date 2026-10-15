import { z } from "zod";

/** Thrown when the environment is invalid. Lists variable names and rules only, never values. */
export class ConfigError extends Error {
  constructor(public readonly problems: string[]) {
    super(`Invalid environment configuration:\n  - ${problems.join("\n  - ")}`);
    this.name = "ConfigError";
  }
}

const origin = z.string().refine((value) => {
  try {
    const url = new URL(value);
    // A browser Origin is scheme + host + port only: no path, query, fragment, credentials or wildcard.
    return (url.protocol === "https:" || (url.protocol === "http:" && url.hostname === "localhost"))
      && url.origin === value && !value.includes("*");
  } catch {
    return false;
  }
}, "must be an exact origin like https://example.github.io (no path, no trailing slash, no wildcard)");

const schema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  MONGODB_URI: z.string().regex(/^mongodb(\+srv)?:\/\/\S+$/, "must be a mongodb:// or mongodb+srv:// connection string"),
  MONGODB_DB_NAME: z.string().regex(/^medtechtycoon_[a-z0-9_]+$/, "must be a medtechtycoon_* database (e.g. medtechtycoon_dev)"),
  ALLOWED_ORIGIN: z.string()
    .transform((value) => value.split(",").map((s) => s.trim()).filter(Boolean))
    .pipe(z.array(origin).min(1, "must list at least one origin")),
  // Phase 3 (Microsoft Entra). Optional now so the backend starts without them.
  ENTRA_TENANT_ID: z.uuid().optional(),
  ENTRA_API_AUDIENCE: z.string().min(1).optional(),
});

export type Config = {
  nodeEnv: "development" | "test" | "production";
  port: number;
  mongodbUri: string;
  mongodbDbName: string;
  allowedOrigins: string[];
  entra: { tenantId?: string; apiAudience?: string };
};

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  // Treat empty strings as unset so optional future-phase variables can be left blank.
  const cleaned = Object.fromEntries(Object.entries(env).filter(([, v]) => v !== undefined && v.trim() !== ""));
  const parsed = schema.safeParse(cleaned);
  if (!parsed.success) {
    throw new ConfigError(parsed.error.issues.map((issue) => {
      const name = issue.path[0] ?? "environment";
      return issue.code === "invalid_type" && issue.input === undefined ? `${String(name)} is required` : `${String(name)} ${issue.message}`;
    }));
  }
  const e = parsed.data;
  return {
    nodeEnv: e.NODE_ENV,
    port: e.PORT,
    mongodbUri: e.MONGODB_URI,
    mongodbDbName: e.MONGODB_DB_NAME,
    allowedOrigins: e.ALLOWED_ORIGIN,
    entra: { tenantId: e.ENTRA_TENANT_ID, apiAudience: e.ENTRA_API_AUDIENCE },
  };
}
