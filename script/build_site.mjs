import { copyFileSync, cpSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const source = resolve(root, "site");
const output = resolve(root, "dist/site");
const skill = resolve(root, "SKILL.md");
const version = readCargoVersion();
const dateModified = new Date().toISOString().slice(0, 10);

rmSync(output, { force: true, recursive: true });
mkdirSync(output, { recursive: true });
cpSync(source, output, { recursive: true });
copyFileSync(skill, resolve(output, "SKILL.md"));

const indexPath = resolve(output, "index.html");
const index = readFileSync(indexPath, "utf8")
  .replaceAll("__INVOICEGEN_VERSION__", version)
  .replaceAll("__INVOICEGEN_DATE_MODIFIED__", dateModified);
writeFileSync(indexPath, index);

console.log(`Built static site at ${output}`);

function readCargoVersion() {
  const cargoToml = readFileSync(resolve(root, "Cargo.toml"), "utf8");
  const version = cargoToml.match(/^version = "([^"]+)"/m)?.[1];
  if (!version) {
    throw new Error("Cargo.toml does not contain a package version");
  }
  return version;
}
