#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(new URL("..", import.meta.url).pathname);
const outRoot = path.join(root, "dist", "npm");
const version = process.env.INVOICEGEN_VERSION ?? readCargoVersion();
const allowMissingBinaries = process.env.ALLOW_MISSING_CLI_BINARIES === "1";
const platforms = [
  ["invoicegen-darwin-arm64", "aarch64-apple-darwin", "invoicegen-rs"],
  ["invoicegen-darwin-x64", "x86_64-apple-darwin", "invoicegen-rs"],
  ["invoicegen-linux-arm64", "aarch64-unknown-linux-gnu", "invoicegen-rs"],
  ["invoicegen-linux-x64", "x86_64-unknown-linux-gnu", "invoicegen-rs"],
];

fs.rmSync(outRoot, { recursive: true, force: true });
copyPackage("invoicegen");
rewritePackageVersion(path.join(outRoot, "invoicegen", "package.json"));

for (const [packageDir, rustTarget, binaryName] of platforms) {
  copyPackage(packageDir);
  const stagedPackageDir = path.join(outRoot, packageDir);
  rewritePackageVersion(path.join(stagedPackageDir, "package.json"));
  const sourceBinary = path.join(root, "dist", "cli", rustTarget, "bin", binaryName);
  const destBinary = path.join(stagedPackageDir, "bin", binaryName);
  if (fs.existsSync(sourceBinary)) {
    fs.mkdirSync(path.dirname(destBinary), { recursive: true });
    fs.copyFileSync(sourceBinary, destBinary);
    fs.chmodSync(destBinary, 0o755);
  } else if (!allowMissingBinaries) {
    throw new Error(`missing release binary for ${packageDir}: ${sourceBinary}`);
  }
}

console.log(`Staged npm packages in ${outRoot}`);

function copyPackage(packageDir) {
  const source = path.join(root, "npm", packageDir);
  const dest = path.join(outRoot, packageDir);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.cpSync(source, dest, { recursive: true });
}

function rewritePackageVersion(packagePath) {
  const pkg = JSON.parse(fs.readFileSync(packagePath, "utf8"));
  pkg.version = version;
  if (pkg.optionalDependencies) {
    for (const key of Object.keys(pkg.optionalDependencies)) {
      pkg.optionalDependencies[key] = version;
    }
  }
  fs.writeFileSync(packagePath, `${JSON.stringify(pkg, null, 2)}\n`);
}

function readCargoVersion() {
  const cargoToml = fs.readFileSync(path.join(root, "Cargo.toml"), "utf8");
  const version = cargoToml.match(/^version = "([^"]+)"/m)?.[1];
  if (!version) {
    throw new Error("Cargo.toml does not contain a package version");
  }
  return version;
}
