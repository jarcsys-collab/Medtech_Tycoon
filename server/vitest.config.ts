import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["tests/**/*.test.ts"],
    testTimeout: 60_000,
    hookTimeout: 180_000, // first run downloads a local mongod binary for the integration tests
  },
});
