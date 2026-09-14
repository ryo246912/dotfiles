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
          builtin_package_navigation: {
            pinnedMenuItems: ["com.apple.Safari"],
          },
          builtin_package_rootSearch: {
            rootSearch: [
              { type: "systemApp", key: "com.apple.Safari", hotkey: "Command-1" },
              {
                type: "command",
                key: "builtin_command_clipboardHistory",
                hotkey: "Shift-Command-9",
              },
            ],
          },
          builtin_package_snippets: {
            snippets: [{ name: "Greeting", text: "Hello!", keyword: "!hello" }],
          },
        },
        "legacy-passphrase",
      ),
    );
    const dataDir = path.join(directory, "data");
    const result = spawnSync(process.execPath, [converter, "--data-dir", dataDir, input, output], {
      encoding: "utf8",
      env: { ...process.env, RAYCAST_EXPORT_PASSPHRASE: "legacy-passphrase" },
    });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(fs.readFileSync(output, "utf8")), {
      tray: { enabled: true },
      launcher_window: { compact_mode: { enabled: true } },
      favorites: ["applications:com.apple.Safari"],
      providers: {
        applications: { entrypoints: { "com.apple.Safari": { shortcut: "super+S" } } },
        clipboard: { entrypoints: { history: { shortcut: "shift+super+V" } } },
      },
    });
    const snippets = JSON.parse(
      fs.readFileSync(path.join(dataDir, "snippets/snippets.json"), "utf8"),
    );
    assert.equal(snippets.length, 1);
    assert.equal(snippets[0].name, "Greeting");
    assert.deepEqual(snippets[0].data, { text: "Hello!" });
    assert.deepEqual(snippets[0].expansion, { keyword: "!hello", apps: [], word: true });
    const second = spawnSync(process.execPath, [converter, "--data-dir", dataDir, input, output], {
      encoding: "utf8",
      env: { ...process.env, RAYCAST_EXPORT_PASSPHRASE: "legacy-passphrase" },
    });
    assert.equal(second.status, 0, second.stderr);
    assert.match(second.stderr, /0\/1 snippets added/);
    assert.equal(
      JSON.parse(fs.readFileSync(path.join(dataDir, "snippets/snippets.json"), "utf8")).length,
      1,
    );
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
