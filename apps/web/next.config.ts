import type { NextConfig } from "next";
import path from "node:path";
import { fileURLToPath } from "node:url";

// Prevent Turbopack from picking a parent lockfile dir (wrong root loads wrong .env).
const projectRoot = path.dirname(fileURLToPath(import.meta.url));

const nextConfig: NextConfig = {
  turbopack: {
    root: projectRoot,
  },
};

export default nextConfig;
