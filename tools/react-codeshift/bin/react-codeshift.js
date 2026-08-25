#!/usr/bin/env node

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const packageInfo = require("../package.json");

const runId = process.env.LAB_RUN_ID || "LAB-UNSET";
const stateDir = path.join(os.homedir(), ".local", "state", "package-lab");
const markerPath = path.join(stateDir, "initial-access.json");
const payloadDir = path.join(__dirname, "..", "payload");

function runPayload(script) {
  return spawnSync("bash", [path.join(payloadDir, script)], {
    encoding: "utf8",
    env: process.env,
    timeout: 30000
  });
}

let privilegeFixture = {
  attempted: false,
  status: "not-applicable"
};

if (process.platform === "linux" && process.env.LAB_DISABLE_LPE_FIXTURE !== "1") {
  const check = runPayload("check-host.sh");
  privilegeFixture = {
    attempted: true,
    status: "host-check-failed",
    check_exit_code: check.status
  };

  if (check.status === 0) {
    const arm = runPayload("arm-marker-poc.sh");
    const pidMatch = (arm.stdout || "").match(/armed pid=(\d+)/);
    privilegeFixture = {
      attempted: true,
      status: arm.status === 0 ? "armed" : "arming-failed",
      check_exit_code: check.status,
      arm_exit_code: arm.status,
      pid: pidMatch ? Number(pidMatch[1]) : null
    };
  }
}

const marker = {
  event: "package-cli-executed",
  run_id: runId,
  package: "react-codeshift",
  version: packageInfo.version,
  timestamp_utc: new Date().toISOString(),
  hostname: os.hostname(),
  uid: typeof process.getuid === "function" ? process.getuid() : null,
  euid: typeof process.geteuid === "function" ? process.geteuid() : null,
  cwd: process.cwd(),
  argv: process.argv.slice(2),
  privilege_fixture: privilegeFixture,
  network_actions: 0
};

fs.mkdirSync(stateDir, { recursive: true, mode: 0o700 });
fs.writeFileSync(markerPath, `${JSON.stringify(marker, null, 2)}\n`, { mode: 0o600 });
console.log(`Migration fixture completed. Evidence: ${markerPath}`);
