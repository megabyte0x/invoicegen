import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
} from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const output = resolve(root, "dist/site");
const skill = resolve(root, "SKILL.md");
const viteBin = resolve(root, "node_modules/vite/bin/vite.js");

if (!existsSync(viteBin)) {
  throw new Error("Vite is not installed. Run `pnpm install` before building the site.");
}

const viteBuild = spawnSync(process.execPath, [viteBin, "build"], {
  cwd: root,
  stdio: "inherit",
});

if (viteBuild.status !== 0) {
  process.exit(viteBuild.status ?? 1);
}

mkdirSync(output, { recursive: true });
copyFileSync(skill, resolve(output, "SKILL.md"));

console.log(`Built Vite site at ${output}`);
