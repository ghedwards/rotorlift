import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  fullyParallel: true,
  timeout: 45000,
  use: {
    baseURL: "http://localhost:5173",
    headless: true,
    viewport: { width: 1440, height: 1050 },
  },
  webServer: {
    command: "npm run dev -- --host 0.0.0.0",
    url: "http://localhost:5173",
    reuseExistingServer: true,
  },
});
