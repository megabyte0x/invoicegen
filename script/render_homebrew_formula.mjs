#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(new URL("..", import.meta.url).pathname);
const version = process.env.INVOICEGEN_VERSION ?? readCargoVersion();
const sourceSha256 = process.env.INVOICEGEN_SOURCE_SHA256;
if (!sourceSha256) {
  throw new Error("INVOICEGEN_SOURCE_SHA256 is required");
}

const templatePath = path.join(root, "Formula", "invoicegen.rb");
const outDir = path.join(root, "dist", "homebrew");
fs.mkdirSync(outDir, { recursive: true });

const rendered = fs
  .readFileSync(templatePath, "utf8")
  .replace(/v\d+\.\d+\.\d+/g, `v${version}`)
  .replaceAll("REPLACE_WITH_SOURCE_TARBALL_SHA256", sourceSha256);
const outPath = path.join(outDir, "invoicegen.rb");
fs.writeFileSync(outPath, rendered);
console.log(`Rendered ${outPath}`);

function readCargoVersion() {
  const cargoToml = fs.readFileSync(path.join(root, "Cargo.toml"), "utf8");
  const version = cargoToml.match(/^version = "([^"]+)"/m)?.[1];
  if (!version) {
    throw new Error("Cargo.toml does not contain a package version");
  }
  return version;
}
