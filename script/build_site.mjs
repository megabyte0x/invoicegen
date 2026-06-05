import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const output = resolve(root, "dist/site");
const skill = resolve(root, "SKILL.md");
const viteBin = resolve(root, "node_modules/vite/bin/vite.js");
const dateModified = new Date().toISOString().slice(0, 10);
const version = readReleaseVersion();

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
replaceBuiltPlaceholders(output);

console.log(`Built Vite site at ${output}`);

function replaceBuiltPlaceholders(path) {
  if (!existsSync(path)) return;

  const stat = statSync(path);
  if (stat.isDirectory()) {
    for (const entry of readdirSync(path)) {
      replaceBuiltPlaceholders(resolve(path, entry));
    }
    return;
  }

  if (!/\.(html|xml|txt|md)$/.test(path)) return;

  const source = readFileSync(path, "utf8");
  writeFileSync(
    path,
    source
      .replaceAll("__INVOICEGEN_DATE_MODIFIED__", dateModified)
      .replaceAll("__INVOICEGEN_VERSION__", version),
  );
}

function readReleaseVersion() {
  const cargoTomlPath = resolve(root, "Cargo.toml");
  if (existsSync(cargoTomlPath)) {
    const cargoToml = readFileSync(cargoTomlPath, "utf8");
    const versionMatch = cargoToml.match(/^version = "([^"]+)"/m);
    if (versionMatch) {
      return versionMatch[1];
    }
  }

  const packageJson = JSON.parse(readFileSync(resolve(root, "package.json"), "utf8"));
  if (typeof packageJson.version === "string" && packageJson.version.length > 0) {
    return packageJson.version;
  }

  throw new Error("Neither Cargo.toml nor package.json contains a release version");
}
