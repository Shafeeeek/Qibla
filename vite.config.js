import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";
import { spawn } from "node:child_process";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function autoStartBackend() {
  let backendProc = null;
  return {
    name: "auto-start-backend",
    configureServer(server) {
      const checkReq = http.get("http://127.0.0.1:3000/api/health", () => {});
      checkReq.on("error", () => {
        const serverScript = path.resolve(__dirname, "QiblaBackend", "server.js");
        backendProc = spawn(process.execPath, [serverScript], {
          cwd: path.resolve(__dirname, "QiblaBackend"),
          stdio: "inherit",
          env: process.env,
        });
      });
      const stop = () => {
        if (backendProc) {
          backendProc.kill();
          backendProc = null;
        }
      };
      server.httpServer?.on("close", stop);
      process.on("exit", stop);
      process.on("SIGINT", stop);
      process.on("SIGTERM", stop);
    },
  };
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  return {
    root: "QiblaWeb",
    envDir: "..",
    plugins: [react(), autoStartBackend()],
    server: {
      port: 5173,
      proxy: {
        "/api": {
          target: env.QIBLA_BACKEND_URL || "http://127.0.0.1:3000",
          changeOrigin: true,
        },
      },
    },
    build: { outDir: "../dist", emptyOutDir: true },
  };
});
