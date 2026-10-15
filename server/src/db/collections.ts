/**
 * Planned collection shapes and indexes for later phases.
 * Phase 2 only DECLARES these; nothing here creates collections, indexes or documents.
 * They will be applied by a reviewed migration once Entra sign-in (Phase 3) exists.
 */
import type { IndexDescription, ObjectId } from "mongodb";

export const COLLECTIONS = {
  players: "players",
  playerProgress: "player_progress",
  scores: "scores",
  leaderboards: "leaderboards",
  gameSessions: "game_sessions",
  achievements: "achievements",
  multiplayerRooms: "multiplayer_rooms",
} as const;

/** One per Entra user. Identity comes from the validated token (tid + oid), never from the client. */
export interface Player {
  _id: ObjectId;
  tenantId: string;
  entraObjectId: string;
  displayName: string;
  roles: string[];
  createdAt: Date;
  lastSeenAt: Date;
}

/** Cloud save. `state` is the existing GameState.to_dict() payload; `rev` gives optimistic concurrency. */
export interface PlayerProgress {
  _id: ObjectId;
  playerId: ObjectId;
  slot: string;
  saveVersion: number;
  state: Record<string, unknown>;
  rev: number;
  updatedAt: Date;
}

/** Server-computed results only; clients never submit a score value directly. */
export interface Score {
  _id: ObjectId;
  playerId: ObjectId;
  metric: "revenue" | "deals" | "level";
  value: number;
  sessionId?: ObjectId;
  validated: boolean;
  createdAt: Date;
}

/** Materialised top-N, rebuilt from `scores` (e.g. boardId "revenue:2026-W42"). */
export interface Leaderboard {
  _id: ObjectId;
  boardId: string;
  entries: { playerId: ObjectId; displayName: string; value: number; rank: number }[];
  computedAt: Date;
}

export interface GameSession {
  _id: ObjectId;
  playerIds: ObjectId[];
  mode: "solo" | "shared";
  status: "active" | "ended" | "abandoned";
  seed: number;
  eventCount: number;
  startedAt: Date;
  endedAt?: Date;
  expiresAt?: Date;
}

export interface Achievement {
  _id: ObjectId;
  playerId: ObjectId;
  achievementId: string;
  unlockedAt: Date;
}

/** Room metadata only. Live movement stays in memory on the WebSocket hub and is never stored. */
export interface MultiplayerRoom {
  _id: ObjectId;
  code: string;
  hostId: ObjectId;
  members: ObjectId[];
  maxPlayers: number;
  state: "open" | "in_game" | "closed";
  expiresAt: Date;
}

export const PLANNED_INDEXES: Record<keyof typeof COLLECTIONS, IndexDescription[]> = {
  players: [{ key: { tenantId: 1, entraObjectId: 1 }, unique: true }],
  playerProgress: [{ key: { playerId: 1, slot: 1 }, unique: true }],
  scores: [{ key: { metric: 1, value: -1 } }, { key: { playerId: 1 } }],
  leaderboards: [{ key: { boardId: 1 }, unique: true }],
  gameSessions: [{ key: { status: 1 } }, { key: { expiresAt: 1 }, expireAfterSeconds: 0 }],
  achievements: [{ key: { playerId: 1, achievementId: 1 }, unique: true }],
  multiplayerRooms: [{ key: { code: 1 }, unique: true }, { key: { expiresAt: 1 }, expireAfterSeconds: 0 }],
};
