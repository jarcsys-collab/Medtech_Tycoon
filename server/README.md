# medtechtycoon-api

Node.js backend for MedTechTycoon, deployed on Railway with MongoDB Atlas behind it.
The Godot game stays at the repository root; this folder is built and deployed on its own
(`.gdignore` keeps Godot from importing it).

**Phase 2 scope:** infrastructure only. There is no sign-in, no player data and no write endpoint.
Microsoft Entra, cloud saves, leaderboards and multiplayer come in later phases.

| Endpoint | Purpose | Response |
|---|---|---|
| `GET /healthz` | Liveness: the process is up (no database call) | `200 {"status":"ok","service":"medtechtycoon-api"}` |
| `GET /readyz` | Readiness: MongoDB answers a ping within 2 s | `200 {"status":"ready",...}` or `503 {"status":"unavailable",...}` |
| `GET /status` | Deployed version and uptime | `200 {"service","version","uptimeSeconds"}` |

None of them return configuration, hostnames, connection strings or stack traces.

## Local development

Requires Node.js 24 LTS.

```sh
cd server
npm ci
cp .env.example .env      # fill in a dev MONGODB_URI; .env is git-ignored
npm run dev               # tsx watch, loads .env
npm test                  # unit + integration tests (throwaway local mongod, never Atlas)
npm run build && npm start
```

Configuration is checked at startup (`src/config/env.ts`). A missing or invalid variable stops the
process with the variable's name and the rule it broke, never its value.

| Variable | Required | Notes |
|---|---|---|
| `PORT` | no (3000) | Railway sets this automatically |
| `NODE_ENV` | no (development) | `production` on Railway |
| `MONGODB_URI` | yes | Atlas SRV string for the dedicated MedTechTycoon user. Railway variables only |
| `MONGODB_DB_NAME` | yes | `medtechtycoon_dev`; only `medtechtycoon_*` names are accepted |
| `ALLOWED_ORIGIN` | yes | Comma-separated exact origins, e.g. `https://jarcsys-collab.github.io` (no path) |
| `ENTRA_TENANT_ID`, `ENTRA_API_AUDIENCE` | no | Phase 3; may be blank |

## Security defaults

- **CORS:** exact-origin allowlist, no credentials; only `Authorization` and `Content-Type` headers are allowed.
- **Headers (helmet):** `default-src 'none'` CSP, HSTS, `nosniff`, frame denial.
- **Requests:** bodies are capped at 16 KiB, and each client IP gets 120 requests per minute.
- **Errors:** 5xx responses are generic. Logs redact `Authorization`, cookies and connection-string credentials.
- **MongoDB:** one shared client, 5 s server selection, 2 s readiness ping. The process still starts if Atlas is down.
- **Shutdown:** on SIGTERM/SIGINT the server stops accepting requests, finishes in-flight ones, closes MongoDB, and exits within 10 s.

## Deployment

Railway service with root directory `/server`, using the config file `/server/railway.json`:
- Railpack builds it with `npm run build` and starts it with `node dist/index.js`.
- The health check is `/readyz`, and the service restarts on failure.
- Only changes under `/server/**` trigger a deploy.

`.github/workflows/server.yml` runs type-check, tests, build, `npm audit` and a smoke test on every change to `server/`.

`src/db/collections.ts` declares the planned collections and indexes for later phases. Nothing creates them yet.
