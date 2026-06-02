#!/usr/bin/env node
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const platformPackages = {
  "darwin-arm64": ["@megabyte0x/invoicegen-darwin-arm64", "invoicegen-rs"],
  "darwin-x64": ["@megabyte0x/invoicegen-darwin-x64", "invoicegen-rs"],
  "linux-arm64": ["@megabyte0x/invoicegen-linux-arm64", "invoicegen-rs"],
  "linux-x64": ["@megabyte0x/invoicegen-linux-x64", "invoicegen-rs"],
  "win32-x64": ["@megabyte0x/invoicegen-win32-x64", "invoicegen-rs.exe"],
};

function resolveBinary() {
  if (process.env.INVOICEGEN_RS_BINARY) {
    return process.env.INVOICEGEN_RS_BINARY;
  }

  const key = `${process.platform}-${process.arch}`;
  const target = platformPackages[key];
  if (!target) {
    throw new Error(
      `Unsupported platform ${key}. Build from source with cargo install --path . or set INVOICEGEN_RS_BINARY.`,
    );
  }

  const [packageName, binaryName] = target;
  try {
    return require.resolve(`${packageName}/bin/${binaryName}`);
  } catch (error) {
    const devBinary = path.resolve(
      __dirname,
      "..",
      "..",
      "..",
      "target",
      "release",
      binaryName,
    );
    if (fs.existsSync(devBinary)) {
      return devBinary;
    }
    throw new Error(
      `Could not find native InvoiceGen binary package ${packageName}. Reinstall @megabyte0x/invoicegen or set INVOICEGEN_RS_BINARY.`,
    );
  }
}

try {
  const binary = resolveBinary();
  const result = spawnSync(binary, process.argv.slice(2), { stdio: "inherit" });
  if (result.error) {
    throw result.error;
  }
  process.exit(result.status ?? 1);
} catch (error) {
  console.error(error.message);
  process.exit(1);
}
