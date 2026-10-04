-- JankyBorders の枠の色をアプリ（プロセス）ごとに上書きするルール
--
-- 上から順に評価し、最初にマッチしたルールの色を使う（マッチしなければ bordersrc の既定色のまま）。
-- 条件は全て省略可能で、指定したものは全て満たす必要がある。
--   app   : アプリ名（hs.application:name()。アクティビティモニタの表示名とほぼ同じ）または bundle ID
--   args  : プロセスの起動引数に含まれる文字列（部分一致）。
--           同じアプリを --user-data-dir 等で複数起動している場合の判別に使う
--   title : ウィンドウタイトルにマッチする Lua パターン
-- 色の指定（0xAARRGGBB。JankyBorders の gradient(...) / glow(...) 記法も可）
--   color    : フォーカス時の色（必須）
--   inactive : 非フォーカス時の色。省略時は color のアルファを 0x88 にした色
--
-- 注意: args は部分一致なので、より具体的なルール（Claude2 等）を汎用ルールより上に書く
return {
  -- Claude Desktop（docs/setup.md の「カスタムアプリの作成手順」で --user-data-dir を分けて起動）
  { app = 'Claude', args = 'Application Support/ClaudeWork3', color = '0xff61afef' }, -- 青
  { app = 'Claude', args = 'Application Support/Claude2', color = '0xffe06c75' }, -- 赤
  { app = 'Claude', color = '0xffd19a66' }, -- 通常（オレンジ）

  -- Chrome（例: --user-data-dir でプロファイルを分けて起動している場合）
  -- { app = 'Google Chrome', args = 'chrome-profiles/profile3', color = '0xff98c379' },
  -- { app = 'Google Chrome', color = '0xffe5c07b' },
}
