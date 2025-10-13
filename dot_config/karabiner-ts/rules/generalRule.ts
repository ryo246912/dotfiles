import { map, rule } from "karabiner.ts";

export const Rules = rule("general").manipulators([
    // Quit application by holding command-q
    map({
      key_code: "q",
      modifiers: { mandatory: ["command"], optional: ["caps_lock"] },
    })
      .toIfHeldDown({
        key_code: "q",
        modifiers: ["left_command"],
        repeat: false,
      }),
  ])
