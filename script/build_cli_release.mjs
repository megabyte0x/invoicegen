#!/usr/bin/env node
import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const root = path.resolve(new URL("..", import.meta.url).pathname);
const version = process.env.INVOICEGEN_VERSION ?? readCargoVersion();
const target = process.env.CARGO_BUILD_TARGET || rustHostTriple();
const binaryName = target.includes("windows") ? "invoicegen-rs.exe" : "invoicegen-rs";
const distDir = path.join(root, "dist", "cli", target);
const stagedBinDir = path.join(distDir, "bin");
const releaseArgs = ["build", "--release"];

if (process.env.CARGO_BUILD_TARGET) {
  releaseArgs.push("--target", target);
}

run("cargo", releaseArgs);
fs.rmSync(distDir, { recursive: true, force: true });
fs.mkdirSync(stagedBinDir, { recursive: true });

const binaryPath = process.env.CARGO_BUILD_TARGET
  ? path.join(root, "target", target, "release", binaryName)
  : path.join(root, "target", "release", binaryName);
const stagedBinaryPath = path.join(stagedBinDir, binaryName);
fs.copyFileSync(binaryPath, stagedBinaryPath);
fs.chmodSync(stagedBinaryPath, 0o755);

const archiveName = `invoicegen-rs-${version}-${target}.tar.gz`;
const archivePath = path.join(root, "dist", "cli", archiveName);
run("tar", ["-czf", archivePath, "-C", stagedBinDir, binaryName]);

const sha256 = createHash("sha256").update(fs.readFileSync(archivePath)).digest("hex");
fs.writeFileSync(`${archivePath}.sha256`, `${sha256}  ${archiveName}\n`);
fs.writeFileSync(
  path.join(distDir, "manifest.json"),
  `${JSON.stringify({ version, target, binaryName, archiveName, sha256 }, null, 2)}\n`,
);

console.log(`Built ${archivePath}`);

function readCargoVersion() {
  const cargoToml = fs.readFileSync(path.join(root, "Cargo.toml"), "utf8");
  const version = cargoToml.match(/^version = "([^"]+)"/m)?.[1];
  if (!version) {
    throw new Error("Cargo.toml does not contain a package version");
  }
  return version;
}

function rustHostTriple() {
  const result = spawnSync("rustc", ["-vV"], { encoding: "utf8" });
  if (result.status !== 0) {
    throw new Error(result.stderr || "failed to detect rust host target");
  }
  const host = result.stdout.match(/^host: (.+)$/m)?.[1];
  if (!host) {
    throw new Error("failed to parse rustc host target");
  }
  return host;
}

function run(command, args) {
  const result = spawnSync(command, args, { cwd: root, stdio: "inherit" });
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed`);
  }
}
