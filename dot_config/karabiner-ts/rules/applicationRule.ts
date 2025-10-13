import { ifApp, map, rule, withCondition } from "karabiner.ts";


// アプリケーション定義
const APPLICATIONS = {
  alacritty: "^org\\.alacritty$",
  arc: "^company\\.thebrowser\\.Browser$",
  chrome: "^com\\.google\\.Chrome$",
  dbeaver: "^org\\.jkiss\\.dbeaver\\.core\\.product$",
  finder: "^com\\.apple\\.finder$",
  gather: "^com\\.gather\\.Gather$",
  notion: "^notion\\.id$",
  slack: "^com\\.tinyspeck\\.slackmacgap$",
  system: "^com\\.apple\\.systempreferences$",
  vscode: "^com\\.microsoft\\.VSCode$",
};

// annotation
const shouldAnnotation = map("1", "left_option")
    .to("japanese_eisuu")
    .to("close_bracket")
    .to("s")
    .to("h")
    .to("o")
    .to("u")
    .to("l")
    .to("d")
    .to("backslash")

const optionalAnnotation = map("2", "left_option")
    .to("japanese_eisuu")
    .to("close_bracket")
    .to("o")
    .to("p")
    .to("t")
    .to("i")
    .to("o")
    .to("n")
    .to("a")
    .to("l")
    .to("backslash")

const imoAnnotation = map("3", "left_option")
    .to("japanese_eisuu")
    .to("close_bracket")
    .to("i")
    .to("m")
    .to("o")
    .to("backslash")

const qAnnotation = map("4", "left_option")
    .to("japanese_eisuu")
    .to("close_bracket")
    .to("q", "left_shift")
    .to("backslash")

const memoAnnotation = map("5", "left_option")
    .to("japanese_eisuu")
    .to("close_bracket")
    .to("m")
    .to("e")
    .to("m")
    .to("o")
    .to("backslash")

const mustAnnotation = map("6", "left_option")
    .to("japanese_eisuu")
    .to("close_bracket")
    .to("m")
    .to("u")
    .to("s")
    .to("t")
    .to("backslash")

// Arc 専用ルール
export const arcRules = rule("Arc shortcuts").manipulators([
  withCondition(ifApp([APPLICATIONS.arc]))(
    [shouldAnnotation, optionalAnnotation, imoAnnotation, qAnnotation, memoAnnotation, mustAnnotation]
  ),
]);

// VSCode 専用ルール
export const vscodeRules = rule("VSCode shortcuts").manipulators([
  withCondition(ifApp([APPLICATIONS.vscode]))(
    [shouldAnnotation, optionalAnnotation, imoAnnotation, qAnnotation, memoAnnotation, mustAnnotation]
  ),
]);

// Slack 専用ルール
export const slackRules = rule("Slack shortcuts").manipulators([
  withCondition(ifApp([APPLICATIONS.slack]))([
  map("f", ["left_command", "left_shift"])
    .to("japanese_eisuu")
    .to("f", "left_command")
    .to("spacebar")
    .to("f")
    .to("r")
    .to("o")
    .to("m")
    .to("quote")
    .to("open_bracket"),
  map("d", ["left_command", "left_control"])
    .to("japanese_eisuu")
    .to("t", "left_command")
    .to("d")
    .to("e")
    .to("v"),
  map("l", ["left_command", "left_control"])
    .to("japanese_eisuu")
    .to("t", "left_command")
    .to("l")
    .to("o")
    .to("g"),
  map("t", ["left_command", "left_control"])
    .to("japanese_eisuu")
    .to("t", "left_command")
    .to("t")
    .to("i")
    .to("m")
    .to("e")
    .to("s"),
])]);
