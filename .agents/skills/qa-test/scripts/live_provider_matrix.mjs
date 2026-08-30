#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../../..");
const executableNames = process.platform === "win32"
  ? ["CodexBarCLI.exe", "CodexBarCLI.cmd", "CodexBarCLI"]
  : ["CodexBarCLI", "codexbar"];
const pathDirectories = (process.env.PATH || "").split(path.delimiter).filter(Boolean);
const candidates = [
  process.env.CODEXBAR_CLI,
  path.join(projectRoot, "CodexBar.app", "Contents", "Helpers", "CodexBarCLI"),
  path.join(projectRoot, "CodexBarCLI.exe"),
  path.join(projectRoot, "CodexBarCLI"),
  ...pathDirectories.flatMap((directory) => executableNames.map((name) => path.join(directory, name))),
].filter(Boolean);
const cli = candidates.find((candidate) => fs.existsSync(candidate));
const webTimeout = process.env.CODEXBAR_QA_WEB_TIMEOUT || "12";
const caseTimeoutMs = Number(process.env.CODEXBAR_QA_CASE_TIMEOUT || "60") * 1000;

function usage(stream = process.stdout) {
  stream.write([
    "Usage:",
    "  node live_provider_matrix.mjs --enabled",
    "  node live_provider_matrix.mjs --default",
    "  node live_provider_matrix.mjs --provider all",
    "  node live_provider_matrix.mjs --providers openai,zai,deepseek",
    "",
    "Environment:",
    "  CODEXBAR_CLI=/path/to/CodexBarCLI",
    "  CODEXBAR_CONFIG=/path/to/config.json",
    "  CODEXBAR_QA_WEB_TIMEOUT=12",
    "  CODEXBAR_QA_CASE_TIMEOUT=60",
    "",
  ].join("\n"));
}

function redact(value) {
  return String(value || "")
    .replace(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+/g, "<email>")
    .replace(/sk-[A-Za-z0-9_-]{12,}/g, "sk-REDACTED")
    .replace(/gsk_[A-Za-z0-9_-]{12,}/g, "gsk_REDACTED")
    .replace(/[A-Za-z0-9_-]{32,}/g, (match) => /[A-Za-z]/.test(match) && /[0-9]/.test(match) ? "<redacted-token>" : match);
}

function run(arguments_, timeout = caseTimeoutMs) {
  return spawnSync(cli, arguments_, {
    encoding: "utf8",
    env: process.env,
    timeout,
    windowsHide: true,
  });
}

const [mode, value] = process.argv.slice(2);
if (!mode || mode === "-h" || mode === "--help") {
  usage();
  process.exit(0);
}
if (!cli) {
  console.error("missing CodexBarCLI; checked CODEXBAR_CLI, the project app, and PATH");
  process.exit(2);
}
if (!Number.isFinite(caseTimeoutMs) || caseTimeoutMs <= 0) {
  console.error("CODEXBAR_QA_CASE_TIMEOUT must be a positive number");
  process.exit(2);
}

let providers;
if (mode === "--enabled") {
  const result = run(["config", "providers", "--format", "json", "--json-only"]);
  if (result.error || result.status !== 0) {
    console.error("failed to list providers via CodexBarCLI config providers: " + redact(result.stderr || result.error?.message));
    process.exit(2);
  }
  try {
    const payload = JSON.parse(result.stdout.trim());
    if (!Array.isArray(payload)) throw new Error("output is not an array");
    providers = payload.filter((item) => item?.enabled === true && typeof item.provider === "string" && item.provider).map((item) => item.provider);
  } catch (error) {
    console.error("failed to parse CodexBarCLI config providers output: " + redact(error.message));
    process.exit(2);
  }
  if (!providers.length) {
    console.error("no enabled providers found via CodexBarCLI config providers");
    process.exit(2);
  }
} else if (mode === "--default") providers = ["__default__"];
else if (mode === "--provider" && value) providers = [value];
else if (mode === "--providers" && value) providers = value.split(",").filter(Boolean);
else {
  console.error(mode === "--provider" || mode === "--providers" ? "missing provider value" : "unknown mode: " + mode);
  usage(process.stderr);
  process.exit(2);
}

let failed = false;
for (const provider of providers) {
  const name = provider === "__default__" ? "default" : provider;
  const providerArguments = provider === "__default__" ? [] : ["--provider", provider];
  const started = Date.now();
  const result = run(["usage", ...providerArguments, "--format", "json", "--json-only", "--web-timeout", webTimeout]);
  const elapsed = Math.floor((Date.now() - started) / 1000);
  const exitCode = result.status ?? (result.error?.code === "ETIMEDOUT" ? 124 : 1);
  let rows = [];
  try {
    const payload = result.stdout?.trim() ? JSON.parse(result.stdout.trim()) : [];
    for (const item of Array.isArray(payload) ? payload : [payload]) {
      rows.push(
        (item.provider || name) + ":" + (item.error ? "fail" : "ok") + ":source=" + (item.source || "unknown") +
        (item.account ? ",account=" + redact(item.account) : "") +
        (item.usage ? ",usage=yes" : "") +
        (item.credits ? ",credits=yes" : "") +
        (item.error ? ",error=" + redact(item.error.message).slice(0, 180) : ""),
      );
    }
  } catch (error) {
    rows = [name + ":parse-fail:error=" + redact(error.message) + " stdout=" + redact(result.stdout).slice(0, 200) + " stderr=" + redact(result.stderr).slice(0, 200)];
  }
  if (!rows.length) rows = [name + ":empty:stderr=" + redact(result.stderr || result.error?.message).slice(0, 200)];
  console.log("TEST " + name + " exit=" + exitCode + " elapsed=" + elapsed + "s :: " + rows.join(" | "));
  if (exitCode !== 0) failed = true;
}
process.exit(failed ? 1 : 0);
