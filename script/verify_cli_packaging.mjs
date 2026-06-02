#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(new URL("..", import.meta.url).pathname);
const cargoToml = fs.readFileSync(path.join(root, "Cargo.toml"), "utf8");
const version = cargoToml.match(/^version = "([^"]+)"/m)?.[1];
assert.ok(version, "Cargo.toml must contain a package version");

const mainPackagePath = path.join(root, "npm", "invoicegen", "package.json");
assert.ok(fs.existsSync(mainPackagePath), "missing npm/invoicegen/package.json");
const mainPackage = JSON.parse(fs.readFileSync(mainPackagePath, "utf8"));
assert.equal(mainPackage.name, "@megabyte0x/invoicegen");
assert.equal(mainPackage.version, version);
assert.equal(mainPackage.bin.invoicegen, "bin/invoicegen.js");
assert.equal(mainPackage.license, "MIT");
assert.equal(mainPackage.publishConfig?.access, "public");
assert.deepEqual(mainPackage.files, ["bin/"]);

const wrapperPath = path.join(root, "npm", "invoicegen", "bin", "invoicegen.js");
assert.ok(fs.existsSync(wrapperPath), "missing npm CLI wrapper");
const wrapper = fs.readFileSync(wrapperPath, "utf8");
assert.ok(wrapper.startsWith("#!/usr/bin/env node"), "wrapper must be executable by npm");
assert.ok(wrapper.includes("spawnSync"), "wrapper must delegate to the native binary");

const platforms = [
  ["darwin-arm64", "darwin", "arm64", "invoicegen-rs"],
  ["darwin-x64", "darwin", "x64", "invoicegen-rs"],
  ["linux-arm64", "linux", "arm64", "invoicegen-rs"],
  ["linux-x64", "linux", "x64", "invoicegen-rs"],
];
for (const [suffix, os, cpu, binaryName] of platforms) {
  const packagePath = path.join(root, "npm", `invoicegen-${suffix}`, "package.json");
  assert.ok(fs.existsSync(packagePath), `missing package manifest for ${suffix}`);
  const pkg = JSON.parse(fs.readFileSync(packagePath, "utf8"));
  assert.equal(pkg.name, `@megabyte0x/invoicegen-${suffix}`);
  assert.equal(pkg.version, version);
  assert.deepEqual(pkg.os, [os]);
  assert.deepEqual(pkg.cpu, [cpu]);
  assert.deepEqual(pkg.files, [`bin/${binaryName}`]);
  assert.equal(
    mainPackage.optionalDependencies[pkg.name],
    version,
    `main package must optionally depend on ${pkg.name}`,
  );
}

const formulaPath = path.join(root, "Formula", "invoicegen.rb");
assert.ok(fs.existsSync(formulaPath), "missing Homebrew formula template");
const formula = fs.readFileSync(formulaPath, "utf8");
assert.ok(formula.includes("class Invoicegen < Formula"));
assert.ok(formula.includes("depends_on \"rust\" => :build"));
assert.ok(formula.includes("system \"cargo\", \"install\""));

const releaseWorkflowPath = path.join(root, ".github", "workflows", "release-cli.yml");
assert.ok(fs.existsSync(releaseWorkflowPath), "missing CLI release workflow");
const releaseWorkflow = fs.readFileSync(releaseWorkflowPath, "utf8");
assert.ok(releaseWorkflow.includes("NPM_TOKEN"), "workflow must support npm publish token");
assert.ok(releaseWorkflow.includes("HOMEBREW_TAP_TOKEN"), "workflow must support Homebrew tap token");

console.log("CLI packaging metadata is ready.");
