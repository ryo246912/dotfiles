import { ifApp, layer, map, rule, withCondition, writeToProfile } from "karabiner.ts";

// プロファイル設定
const profileSettings = {
  "basic.simultaneous_threshold_milliseconds": 1000,
  "basic.to_delayed_action_delay_milliseconds": 200,
  "basic.to_if_alone_timeout_milliseconds": 500,
  "basic.to_if_held_down_threshold_milliseconds": 500,
};

// アプリケーション定義
const APPLICATIONS = {
  alacritty: "^org\\.alacritty$",
  arc: "^company\\.thebrowser\\.Browser$",
  chrome: "^com\\.google\\.Chrome$",
  dbeaver: "^org\\.jkiss\\.dbeaver\\.core\\.product$",
  finder: "^com\\.apple\\.finder$",
  gather: "^com\\.gather\\.Gather$",
  keeper: "^org\\.keepassxc\\.keepassxc$",
  notion: "^notion\\.id$",
  slack: "^com\\.tinyspeck\\.slackmacgap$",
  system: "^com\\.apple\\.systempreferences$",
  vscode: "^com\\.microsoft\\.VSCode$",
};

// Japanese Kana Mode Layer
const japaneseKanaLayer = layer(
  "japanese_kana",
  "japanese_kana mode"
).manipulators([
  // 基本のナビゲーションキー
  map("t").to("f2", "left_control"),
  map("y").to("close_bracket", ["left_shift", "left_command"]),
  map("u").to("page_down"),
  map("i").to("page_up"),
  map("o").to("backslash", ["left_shift", "left_command"]),
  map("p").to("tab", ["left_command", "left_shift"]),
  map("open_bracket").to("tab", ["left_command", "left_shift"]),

  map("g").to("f3", "left_control"),
  map("h").to("left_arrow"),
  map("j").to("down_arrow"),
  map("k").to("up_arrow"),
  map("l").to("right_arrow"),
  map("semicolon").to("tab", "left_command"),
  map("quote").to("tab", "left_command"),

  map("b").to("escape"),
  map("n").to("delete_or_backspace"),
  map("m").to("tab"),
  map("comma").to("tab", "left_shift"),
  map("period").to("return_or_enter"),
  map("slash").to("tab", "left_option"),

  // 右クリック機能（button2 = 右クリック）
  map("spacebar").to({ pointing_button: "button2" }),

  // 矢印キー with Ctrl
  map("left_arrow").to("left_arrow", "left_control"),
  map("down_arrow").to("down_arrow", "left_control"),
  map("up_arrow").to("up_arrow", "left_control"),
  map("right_arrow").to("right_arrow", "left_control"),

  // 入力ソース切り替え
  map("right_command").to("japanese_eisuu"),
]);

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
const arcRules = rule("Arc shortcuts").manipulators([
  withCondition(ifApp([APPLICATIONS.arc]))(
    [shouldAnnotation, optionalAnnotation, imoAnnotation, qAnnotation, memoAnnotation, mustAnnotation]
  ),
]);

// VSCode 専用ルール
const vscodeRules = rule("VSCode shortcuts").manipulators([
  withCondition(ifApp([APPLICATIONS.vscode]))(
    [shouldAnnotation, optionalAnnotation, imoAnnotation, qAnnotation, memoAnnotation, mustAnnotation]
  ),
]);

// Slack 専用ルール
const slackRules = rule("Slack shortcuts").manipulators([
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

// Left Option Mode ルール
// const leftOptionRules = rule("Left Option Mode").manipulators([
//   map("z", "left_option").to(toApp("System Preferences")),
// ]);

// Spacebar Mode
const spacebarModeRules = rule("Spacebar Mode").manipulators([
  // スペースバーモードの基本設定
  map("spacebar")
    .toVar("spacebar mode", 1)
    .toIfAlone("spacebar")
    .toAfterKeyUp([{ set_variable: { name: "spacebar mode", value: 0 } }]),

  // 修飾キーの状態制御（right_command で循環）
  // map("right_command")
  //   .to$(
  //     'osascript -e "display notification "modifier=command" with title "Karabiner""'
  //   )
  //   .toVar("modifier status", 1)
  //   .condition(toIfVariable("spacebar mode", 1))
  //   .condition(toUnlessVariable("modifier status", 1)),

  // map("right_command")
  //   .to$(
  //     'osascript -e "display notification "modifier=command+shift" with title "Karabiner""'
  //   )
  //   .toVar("modifier status", 2)
  //   .condition(toIfVariable("spacebar mode", 1))
  //   .condition(toIfVariable("modifier status", 1)),

  // map("right_command")
  //   .to$(
  //     'osascript -e "display notification "modifier=none" with title "Karabiner""'
  //   )
  //   .toVar("modifier status", 0)
  //   .condition(toIfVariable("spacebar mode", 1))
  //   .condition(toIfVariable("modifier status", 2)),

  // japanese_eisuu で修飾キーをリセット
  // map("japanese_eisuu")
  //   .to$(
  //     'osascript -e "display notification "modifier=none" with title "Karabiner""'
  //   )
  //   .toVar("modifier status", 0)
  //   .condition(toIfVariable("spacebar mode", 1)),

  // 矢印キー（Option付き）- modifier status 1
  // map("left_arrow")
  //   .to("left_arrow", "left_option")
  //   .toVar("modifier status", 0)
  //   .condition(toUnlessVariable("spacebar mode", 1))
  //   .condition(toIfVariable("modifier status", 1)),

  // map("right_arrow")
  //   .to("right_arrow", "left_option")
  //   .toVar("modifier status", 0)
  //   .condition(toUnlessVariable("spacebar mode", 1))
  //   .condition(toIfVariable("modifier status", 1)),
]);

// Spacebar Mode - Command キー（modifier status 1）
// const spacebarCommandRules = rule("Spacebar Mode - Command").manipulators([
//   // 数字キー
//   map("1")
//     .to("1", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("2")
//     .to("2", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("3")
//     .to("3", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("4")
//     .to("4", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("5")
//     .to("5", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("6")
//     .to("6", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("7")
//     .to("7", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("8")
//     .to("8", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("9")
//     .to("9", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("0")
//     .to("0", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),

//   // アルファベットキー
//   map("q")
//     .to("q", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("w")
//     .to("w", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("e")
//     .to("e", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("r")
//     .to("r", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("a")
//     .to("a", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("s")
//     .to("s", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("d")
//     .to("d", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("f")
//     .to("f", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("z")
//     .to("z", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("x")
//     .to("x", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("c")
//     .to("c", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("v")
//     .to("v", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),

//   // 追加キー（元のgoku設定にあったもの）
//   map("hyphen")
//     .to("hyphen", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("equal_sign")
//     .to("equal_sign", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("international3")
//     .to("international3", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("open_bracket")
//     .to("open_bracket", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("close_bracket")
//     .to("close_bracket", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("semicolon")
//     .to("semicolon", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("quote")
//     .to("quote", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("backslash")
//     .to("backslash", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("t")
//     .to("t", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("y")
//     .to("y", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("u")
//     .to("u", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("i")
//     .to("i", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("o")
//     .to("o", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("p")
//     .to("p", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("g")
//     .to("g", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("h")
//     .to("h", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("j")
//     .to("j", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("k")
//     .to("k", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("l")
//     .to("l", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("b")
//     .to("b", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("n")
//     .to("n", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("m")
//     .to("m", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("comma")
//     .to("comma", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("period")
//     .to("period", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("slash")
//     .to("slash", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("international1")
//     .to("international1", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
// ]);

// Spacebar Mode - Command+Shift キー（modifier status 2）
// const spacebarCommandShiftRules = rule(
//   "Spacebar Mode - Command+Shift"
// ).manipulators([
//   // 数字キー（Command+Shift）
//   map("1")
//     .to("1", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("2")
//     .to("2", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("3")
//     .to("3", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("4")
//     .to("4", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("5")
//     .to("5", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("6")
//     .to("6", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("7")
//     .to("7", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("8")
//     .to("8", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("9")
//     .to("9", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("0")
//     .to("0", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),

//   // アルファベットキー（Command+Shift）
//   map("q")
//     .to("q", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("w")
//     .to("w", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("e")
//     .to("e", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("r")
//     .to("r", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("a")
//     .to("a", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("s")
//     .to("s", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("d")
//     .to("d", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("f")
//     .to("f", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("z")
//     .to("z", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("x")
//     .to("x", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("c")
//     .to("c", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("v")
//     .to("v", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),

//   // 追加キー（Command+Shift版）
//   map("hyphen")
//     .to("hyphen", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("equal_sign")
//     .to("equal_sign", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("international3")
//     .to("international3", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("open_bracket")
//     .to("open_bracket", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("close_bracket")
//     .to("close_bracket", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("semicolon")
//     .to("semicolon", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("quote")
//     .to("quote", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("backslash")
//     .to("backslash", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("t")
//     .to("t", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("y")
//     .to("y", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("u")
//     .to("u", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("i")
//     .to("i", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("o")
//     .to("o", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("p")
//     .to("p", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("g")
//     .to("g", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("h")
//     .to("h", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("j")
//     .to("j", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("k")
//     .to("k", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("l")
//     .to("l", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("b")
//     .to("b", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("n")
//     .to("n", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("m")
//     .to("m", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("comma")
//     .to("comma", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("period")
//     .to("period", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("slash")
//     .to("slash", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("international1")
//     .to("international1", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toUnlessVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
// ]);

// Mirror-QWERTY - 基本（modifier status 0）
const mirrorQwertyBasicRules = rule("Mirror-QWERTY Basic").manipulators([
  withCondition(toIfVariable("spacebar mode", 1), toUnlessVariable("modifier status", 1))([
    // 数字行のミラー
    map("6").to("5").toVar("modifier status", 0),
    map("7").to("4").toVar("modifier status", 0),
    map("8").to("3").toVar("modifier status", 0),
    map("9").to("2").toVar("modifier status", 0),
    map("0").to("1").toVar("modifier status", 0),

    // 上段のミラー
    map("y").to("t").toVar("modifier status", 0),
    map("u").to("r").toVar("modifier status", 0),
    map("i").to("e").toVar("modifier status", 0),
    map("o").to("w").toVar("modifier status", 0),
    map("p").to("q").toVar("modifier status", 0),

    // ホーム行のミラー
    map("h").to("g").toVar("modifier status", 0),
    map("j").to("f").toVar("modifier status", 0),
    map("k").to("d").toVar("modifier status", 0),
    map("l").to("s").toVar("modifier status", 0),
    map("semicolon").to("a").toVar("modifier status", 0),

    // 下段のミラー
    map("n").to("b").toVar("modifier status", 0),
    map("m").to("v").toVar("modifier status", 0),
    map("comma").to("c").toVar("modifier status", 0),
    map("period").to("x").toVar("modifier status", 0),
    map("slash").to("z").toVar("modifier status", 0),
    ]
  )
]);

// Mirror-QWERTY - Command付き（modifier status 1）
// const mirrorQwertyCommandRules = rule("Mirror-QWERTY Command").manipulators([
//   // 数字行のミラー（Command付き）
//   map("6")
//     .to("5", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("7")
//     .to("4", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("8")
//     .to("3", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("9")
//     .to("2", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("0")
//     .to("1", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),

//   // 上段のミラー（Command付き）
//   map("y")
//     .to("t", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("u")
//     .to("r", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("i")
//     .to("e", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("o")
//     .to("w", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("p")
//     .to("q", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),

//   // ホーム行のミラー（Command付き）
//   map("h")
//     .to("g", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("j")
//     .to("f", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("k")
//     .to("d", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("l")
//     .to("s", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("semicolon")
//     .to("a", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),

//   // 下段のミラー（Command付き）
//   map("n")
//     .to("b", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("m")
//     .to("v", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("comma")
//     .to("c", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("period")
//     .to("x", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
//   map("slash")
//     .to("z", "left_command")
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 1)),
// ]);

// Mirror-QWERTY - Command+Shift付き（modifier status 2）
// const mirrorQwertyCommandShiftRules = rule(
//   "Mirror-QWERTY Command+Shift"
// ).manipulators([
//   // 数字行のミラー（Command+Shift付き）
//   map("6")
//     .to("5", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("7")
//     .to("4", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("8")
//     .to("3", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("9")
//     .to("2", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("0")
//     .to("1", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),

//   // 上段のミラー（Command+Shift付き）
//   map("y")
//     .to("t", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("u")
//     .to("r", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("i")
//     .to("e", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("o")
//     .to("w", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("p")
//     .to("q", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),

//   // ホーム行のミラー（Command+Shift付き）
//   map("h")
//     .to("g", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("j")
//     .to("f", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("k")
//     .to("d", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("l")
//     .to("s", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("semicolon")
//     .to("a", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),

//   // 下段のミラー（Command+Shift付き）
//   map("n")
//     .to("b", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("m")
//     .to("v", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("comma")
//     .to("c", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("period")
//     .to("x", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
//   map("slash")
//     .to("z", ["left_command", "left_shift"])
//     .toVar("modifier status", 0)
//     .condition(toIfVariable("spacebar mode", 1))
//     .condition(toIfVariable("modifier status", 2)),
// ]);

// ヘルパー関数
function toIfVariable(name: string, value: string | number | boolean) {
  return { type: "variable_if" as const, name: name, value: value };
}

function toUnlessVariable(name: string, value: string | number | boolean) {
  return { type: "variable_unless" as const, name: name, value: value };
}

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
  {
    name: writeTarget,
  },
  [
    japaneseKanaLayer,
    arcRules,
    vscodeRules,
    slackRules,
    // leftOptionRules,
    spacebarModeRules,
    // spacebarCommandRules,
    // spacebarCommandShiftRules,
    mirrorQwertyBasicRules,
    // mirrorQwertyCommandRules,
    // mirrorQwertyCommandShiftRules,
  ],
  profileSettings
);
