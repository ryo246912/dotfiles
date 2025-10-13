import { writeToProfile } from "karabiner.ts";
import * as application from "./rules/applicationRule";
import * as general from "./rules/generalRule";
import * as japaneseKana from "./rules/japaneseKanaRule";
import * as spacebar from "./rules/spacebarRule";

// プロファイル設定
const profileSettings = {
  "basic.simultaneous_threshold_milliseconds": 1000,
  "basic.to_delayed_action_delay_milliseconds": 200,
  "basic.to_if_alone_timeout_milliseconds": 500,
  "basic.to_if_held_down_threshold_milliseconds": 500,
};

// コマンドライン引数を処理
// @ts-ignore
const args = process.argv.slice(2);
const isDryRun = args.includes("--dry-run") || args.includes("--json");
const isHelp = args.includes("--help") || args.includes("-h");

if (isHelp) {
  console.log(`
Usage: bun karabiner.ts [options]

Options:
  --dry-run, --json    Print JSON configuration to console instead of writing to file
  --help, -h          Show this help message

Examples:
  bun karabiner.ts              # Write to Karabiner profile
  bun karabiner.ts --dry-run    # Print JSON to console
  bun karabiner.ts --json       # Same as --dry-run
`);
  // @ts-ignore
  process.exit(0);
}

const writeTarget = isDryRun ? "--dry-run" : "Default";

writeToProfile(
  writeTarget,
  [
    general.Rules,
    japaneseKana.Rules,
    application.arcRules,
    application.vscodeRules,
    application.slackRules,
    // leftOptionRules,
    spacebar.spacebarModeRules,
    // spacebarCommandRules,
    // spacebarCommandShiftRules,
    spacebar.mirrorQwertyBasicRules,
    // mirrorQwertyCommandRules,
    // mirrorQwertyCommandShiftRules,
  ],
  profileSettings
);
