#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const root = path.resolve(new URL("..", import.meta.url).pathname);
const dryRun = process.env.NPM_PUBLISH_DRY_RUN === "1";
const packageDirs = [
  "dist/npm/invoicegen-darwin-arm64",
  "dist/npm/invoicegen-darwin-x64",
  "dist/npm/invoicegen-linux-arm64",
  "dist/npm/invoicegen-linux-x64",
  "dist/npm/invoicegen",
];

for (const packageDir of packageDirs) {
  const absolutePackageDir = path.join(root, packageDir);
  const manifestPath = path.join(absolutePackageDir, "package.json");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));

  if (!dryRun && packageVersionExists(manifest.name, manifest.version)) {
    console.log(`Skipping ${manifest.name}@${manifest.version}; already published.`);
    continue;
  }

  const args = ["publish", absolutePackageDir, "--access", "public"];
  if (dryRun) {
    args.push("--dry-run");
  }
  run("npm", args);
}

function packageVersionExists(name, version) {
  console.log(`Checking npm view ${name}@${version}`);
  const result = spawnSync("npm", ["view", `${name}@${version}`, "version"], {
    cwd: root,
    encoding: "utf8",
    windowsHide: true,
  });
  return result.status === 0 && result.stdout.trim() === version;
}

function run(command, args) {
  const result = spawnSync(command, args, {
    cwd: root,
    stdio: "inherit",
    shell: process.platform === "win32",
    windowsHide: true,
  });
  if (result.status !== 0) {
    const code = result.status ?? result.signal ?? "unknown";
    throw new Error(`${command} ${args.join(" ")} failed with ${code}`);
  }
}
