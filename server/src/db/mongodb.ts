import { MongoClient, type Db } from "mongodb";
import { describeError } from "./redact.js";

export type DbLogger = {
  info: (obj: object, msg: string) => void;
  warn: (obj: object, msg: string) => void;
};

/** What the HTTP layer needs from the database; lets tests swap in a fake. */
export interface DatabaseHealth {
  ping(): Promise<boolean>;
}

export type DatabaseOptions = {
  uri: string;
  dbName: string;
  logger: DbLogger;
  /** How long to wait for a reachable server before an operation fails. */
  serverSelectionTimeoutMS?: number;
  /** Upper bound for a readiness ping, so /readyz never hangs. */
  pingTimeoutMS?: number;
};

/**
 * One MongoClient (and its connection pool) per process, reused by every request.
 * The process starts even if Atlas is unreachable: /healthz stays up, /readyz reports 503,
 * and the driver keeps retrying on later operations.
 */
export class Database implements DatabaseHealth {
  readonly client: MongoClient;
  private readonly dbName: string;
  private readonly logger: DbLogger;
  private readonly pingTimeoutMS: number;
  private closed = false;

  constructor(opts: DatabaseOptions) {
    this.dbName = opts.dbName;
    this.logger = opts.logger;
    this.pingTimeoutMS = opts.pingTimeoutMS ?? 2000;
    this.client = new MongoClient(opts.uri, {
      appName: "medtechtycoon-api",
      serverSelectionTimeoutMS: opts.serverSelectionTimeoutMS ?? 5000,
      connectTimeoutMS: 10000,
      socketTimeoutMS: 30000,
      maxPoolSize: 10,
      minPoolSize: 0,
      retryWrites: true,
    });
  }

  get db(): Db {
    return this.client.db(this.dbName);
  }

  /** Initial connection. Never throws: failures are logged (redacted) and reported via ping(). */
  async connect(): Promise<boolean> {
    try {
      await this.client.connect();
      await this.db.command({ ping: 1 });
      this.logger.info({ db: this.dbName }, "MongoDB connected");
      return true;
    } catch (err) {
      this.logger.warn({ err: describeError(err), db: this.dbName }, "MongoDB not reachable yet; /readyz will report 503 until it is");
      return false;
    }
  }

  async ping(): Promise<boolean> {
    if (this.closed) return false;
    let timer: NodeJS.Timeout | undefined;
    try {
      const timeout = new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error("ping timed out")), this.pingTimeoutMS);
      });
      await Promise.race([this.db.command({ ping: 1 }, { timeoutMS: this.pingTimeoutMS }), timeout]);
      return true;
    } catch {
      return false;
    } finally {
      clearTimeout(timer);
    }
  }

  async close(): Promise<void> {
    if (this.closed) return;
    this.closed = true;
    await this.client.close();
    this.logger.info({}, "MongoDB connection closed");
  }
}
