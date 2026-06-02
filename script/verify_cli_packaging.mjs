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
assert.ok(
  mainPackage.keywords.includes("invoice"),
  "main package should be discoverable by invoice keyword",
);
assert.deepEqual(mainPackage.files, ["bin/", "README.md"]);

const wrapperPath = path.join(root, "npm", "invoicegen", "bin", "invoicegen.js");
assert.ok(fs.existsSync(wrapperPath), "missing npm CLI wrapper");
const wrapper = fs.readFileSync(wrapperPath, "utf8");
assert.ok(wrapper.startsWith("#!/usr/bin/env node"), "wrapper must be executable by npm");
assert.ok(wrapper.includes("spawnSync"), "wrapper must delegate to the native binary");

const npmReadmePath = path.join(root, "npm", "invoicegen", "README.md");
assert.ok(fs.existsSync(npmReadmePath), "missing npm package README");
const npmReadme = fs.readFileSync(npmReadmePath, "utf8");
assert.ok(npmReadme.includes("npm install -g @megabyte0x/invoicegen"));
assert.ok(npmReadme.includes("invoicegen --help"));

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
  assert.equal(pkg.publishConfig?.access, "public");
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

const releaseWorkflowPath = path.join(root, ".github", "workflows", "publish.yml");
assert.ok(fs.existsSync(releaseWorkflowPath), "missing CLI release workflow");
const releaseWorkflow = fs.readFileSync(releaseWorkflowPath, "utf8");
assert.ok(releaseWorkflow.includes("id-token: write"), "workflow must support npm trusted publishing");
assert.ok(releaseWorkflow.includes("actions/setup-node@v6"), "workflow must set up a trusted-publishing capable npm");
assert.ok(releaseWorkflow.includes("node-version: \"24\""), "workflow must use Node 24 for npm trusted publishing");
assert.ok(releaseWorkflow.includes("NPM_CONFIG_PROVENANCE"), "workflow must publish npm packages with provenance");
assert.ok(!releaseWorkflow.includes("NODE_AUTH_TOKEN"), "workflow must not use token auth for npm publishing");
assert.ok(!releaseWorkflow.includes("NPM_TOKEN"), "workflow must not require an npm token for trusted publishing");
assert.ok(
  !releaseWorkflow.includes("//registry.npmjs.org/:_authToken"),
  "workflow must not write npm token auth to .npmrc",
);
assert.ok(releaseWorkflow.includes("HOMEBREW_TAP_TOKEN"), "workflow must support Homebrew tap token");

console.log("CLI packaging metadata is ready.");
