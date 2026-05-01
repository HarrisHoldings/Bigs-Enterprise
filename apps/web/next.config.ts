import type { NextConfig } from "next";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

// Prevent Turbopack from picking a parent lockfile dir (wrong root loads wrong .env).
const projectRoot = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(projectRoot, "..", "..");

/**
 * Next only auto-loads `.env*` from `apps/web`. If Supabase keys live in the monorepo
 * root `Bigs-Enterprise/.env.local`, merge them for any variables not already set
 * (so `apps/web/.env.local` still wins).
 */
function mergeRootEnvFallback() {
  const files = [path.join(repoRoot, ".env"), path.join(repoRoot, ".env.local")];
  for (const filePath of files) {
    if (!fs.existsSync(filePath)) continue;
    const raw = fs.readFileSync(filePath, "utf8");
    for (let line of raw.split("\n")) {
      line = line.trim();
      if (!line || line.startsWith("#")) continue;
      const eq = line.indexOf("=");
      if (eq <= 0) continue;
      const key = line.slice(0, eq).trim();
      if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(key)) continue;
      let value = line.slice(eq + 1).trim();
      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1);
      }
      if (process.env[key] === undefined) {
        process.env[key] = value;
      }
    }
  }
}

mergeRootEnvFallback();

const nextConfig: NextConfig = {
  turbopack: {
    root: projectRoot,
  },
};

export default nextConfig;
