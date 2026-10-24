# yomiyasu（日本語の文章を読みやすく整える）

[yomiyasu](https://github.com/nanaism/yomiyasu) は、AI が生成した日本語を、意味と条件を保ったまま読みやすく整える skill です。
APM で `nanaism/yomiyasu/skills/yomiyasu` を user scope へ配布します（`apm/apm.yml`、配布先は
`~/.claude/skills/yomiyasu/`・`~/.agents/skills/yomiyasu/`）。

## skill として使う

文章を貼るか、ファイルを指定して呼びます。

```text
/yomiyasu docs/draft.md を読みやすくして        # Claude Code
$yomiyasu docs/draft.md を読みやすくして         # Codex
```

- 文書の種類（`pr`・`article`・`incident`・`proposal`・`minutes`・`manual`・`slides`・`essay`・`formal`・
  `promo`・`mail`・`paper`・`script`）と読者（`expert`・`informed`・`general`）は依頼文で伝えられる。
  伝えなければ行き先と本文から推定する。
- 原文のファイルは書き換えず、最終稿を同じフォルダの別名で保存する。
- 返答の末尾に「変えたところ」「残したAIっぽいところ」「書き手に確かめたい点」「確認の記録」が付く。

## 付属スクリプト

skill と一緒に `scripts/` が配られる。Python の標準ライブラリだけで動く。

| スクリプト          | 用途                                                         |
| ------------------- | ------------------------------------------------------------ |
| `yomiyasu_lint.py`  | 表現・書式の見直し候補を出す（意味や読みやすさは判定しない） |
| `yomiyasu_diff.py`  | 推敲の前後を比べる                                           |
| `yomiyasu_check.py` | lint と diff をまとめて実行し、検査記録を残す                |
| `yomiyasu_hook.py`  | 登録した原稿の最終稿が検査記録と合うかを確かめる hook        |

```bash
S=~/.claude/skills/yomiyasu/scripts
python3 -B $S/yomiyasu_lint.py --doc-type article docs/draft.md   # 種類を指定すると、その種類で普通な書き方は候補から外れる
python3 -B $S/yomiyasu_lint.py --fail-on warn docs/draft.md       # warn 以上があれば終了コード 1
```

語の一覧（`allow.txt`・`flag.txt`）は git の最上位の `.yomiyasu-words/` に置くと自動で読まれる。

## hook

hook は rulesync（`config/rulesync/.rulesync/hooks.json`）で設定する。upstream は hook を plugin として
配らないため、APM ではなく rulesync で足している。

### 登録した原稿の検査（`yomiyasu_hook.py`）

`yomiyasu_check.py start --source docs/draft.md` で登録した原稿だけが対象。返答の終わりに最終稿が検査記録と
合うかを確かめ、合わなければ作業を続けさせる（2 回まで）。登録していない原稿には何もしない。
Claude Code は `UserPromptExpansion`・`UserPromptSubmit`・`PreToolUse`・`Stop`・`SessionEnd`、
Codex は `UserPromptSubmit`・`PreToolUse`・`PostToolUse`・`Stop`・`SessionEnd` で呼ぶ。

投稿（`gh pr create` など）の本文は、`yomiyasu_check.py export --final 最終稿` で書き出した写しを使う。
照合が合わない投稿は止められる。

### Markdown の編集後 lint（`yomiyasu-md-hook`）

Claude Code が `.md` を `Write`・`Edit`・`MultiEdit` で編集するたびに、`local/bin/yomiyasu-md-hook`
（適用後は `~/.local/bin/yomiyasu-md-hook`）が `yomiyasu_lint.py --fail-on warn` を実行する。

- 日本語を含む `.md` だけが対象。英語だけのファイル、`node_modules/`・`.yomiyasu/`・`.git/` 配下は何もしない。
- warn 以上の候補があれば、先頭 40 行を標準エラーへ出して終了コード 2 で終わる。Claude に推敲を促すだけで、
  ファイルは書き換えない。候補なので、直すかどうかは文脈で判断する。
- 止めるには環境変数 `YOMIYASU_MD_HOOK=0` を設定する。
- skill や python3 が無い環境では何もせず終了する。

Codex の編集（`apply_patch`）は入力の形が違うため、この hook は Claude Code のみ。

### APM の hook との関係

rulesync は `preserveUnownedHooks: true` のため、rulesync が書いていない hook（APM が配る ponytail・
i-have-adhd・plannotator）を残したまま、自分の hook を追加する。置き換えにはならない。
同じ event と matcher の hook は 1 つのグループにまとまる。詳細は [rulesync.md](rulesync.md)。
