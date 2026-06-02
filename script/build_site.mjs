import { copyFileSync, cpSync, mkdirSync, rmSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const source = resolve(root, "site");
const output = resolve(root, "dist/site");
const skill = resolve(root, "SKILL.md");

rmSync(output, { force: true, recursive: true });
mkdirSync(output, { recursive: true });
cpSync(source, output, { recursive: true });
copyFileSync(skill, resolve(output, "SKILL.md"));

console.log(`Built static site at ${output}`);
