const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { test } = require("node:test");
const zlib = require("node:zlib");

const converter = path.resolve(__dirname, "../dot_local/bin/executable_raycast-to-vicinae");

function raycastExport(payload, passphrase) {
  const iv = Buffer.alloc(16, 1);
  const salt = Buffer.alloc(16, 2);
  const header = zlib.gzipSync(
    JSON.stringify({
      schemaVersion: 3,
      encryption: { iv: iv.toString("hex"), salt: salt.toString("hex") },
    }),
  );
  const key = crypto.scryptSync(passphrase, salt, 32, {
    N: 16384,
    r: 8,
    p: 1,
    maxmem: 64 * 1024 * 1024,
  });
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const ciphertext = Buffer.concat([
    cipher.update(zlib.gzipSync(JSON.stringify(payload))),
    cipher.final(),
  ]);
  const headerLength = Buffer.alloc(4);
  headerLength.writeUInt32LE(header.length);
  return Buffer.concat([
    Buffer.from("RAYCFG3\n"),
    headerLength,
    header,
    ciphertext,
    cipher.getAuthTag(),
  ]);
}

function legacyRaycastExport(payload, passphrase) {
  const iv = Buffer.alloc(16, 3);
  const key = crypto.createHash("sha256").update(passphrase, "utf8").digest();
  const cipher = crypto.createCipheriv("aes-256-cbc", key, iv);
  return Buffer.concat([iv, cipher.update(zlib.gzipSync(JSON.stringify(payload))), cipher.final()]);
}

test("converts settings with equivalent Vicinae fields", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "raycast-to-vicinae-"));
  try {
    const input = path.join(directory, "Raycast.rayconfig");
    const output = path.join(directory, "settings.json");
    fs.writeFileSync(
      input,
      raycastExport(
        {
          settings: {
            general: {
              globalHotkey: {
                kind: {
                  shortcut: {
                    key: { type: "LayoutIndependent", code: 49 },
                    modifiers: [{ modifier: "Meta" }, { modifier: "Alt" }],
                  },
                },
              },
              showInMenuBar: false,
              windowMode: "compact",
              openAtLogin: true,
            },
          },
        },
        "test-passphrase",
      ),
    );

    const result = spawnSync(process.execPath, [converter, input, output], {
      encoding: "utf8",
      env: { ...process.env, RAYCAST_EXPORT_PASSPHRASE: "test-passphrase" },
    });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(fs.readFileSync(output, "utf8")), {
      global_shortcuts: { toggle: "super+alt+SPACE" },
      tray: { enabled: false },
      launcher_window: { compact_mode: { enabled: true } },
    });
    assert.match(result.stderr, /launch at login/);
    assert.equal(fs.statSync(output).mode & 0o777, 0o600);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test("rejects an incorrect passphrase without writing output", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "raycast-to-vicinae-"));
  try {
    const input = path.join(directory, "Raycast.rayconfig");
    const output = path.join(directory, "settings.json");
    fs.writeFileSync(input, raycastExport({ settings: {} }, "correct-passphrase"));
    const result = spawnSync(process.execPath, [converter, input, output], {
      encoding: "utf8",
      env: { ...process.env, RAYCAST_EXPORT_PASSPHRASE: "wrong-passphrase" },
    });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /check the passphrase/);
    assert.equal(fs.existsSync(output), false);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test("converts a headerless Raycast 1.x export", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "raycast-to-vicinae-"));
  try {
    const input = path.join(directory, "Raycast.rayconfig");
    const output = path.join(directory, "settings.json");
    fs.writeFileSync(
      input,
      legacyRaycastExport(
        {
          raycast_version: "1.104.0",
          builtin_package_raycastPreferences: {
            preferencesAppearance: {
              statusBarIsVisible: true,
              raycastPreferredWindowMode: "compact",
            },
          },
        },
        "legacy-passphrase",
      ),
    );
    const result = spawnSync(process.execPath, [converter, input, output], {
      encoding: "utf8",
      env: { ...process.env, RAYCAST_EXPORT_PASSPHRASE: "legacy-passphrase" },
    });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(fs.readFileSync(output, "utf8")), {
      tray: { enabled: true },
      launcher_window: { compact_mode: { enabled: true } },
    });
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
