import { layer, map } from "karabiner.ts";

export const Rules = layer(
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
