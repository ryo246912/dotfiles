# Vicinae の shortcuts / snippets を「共有（dotfiles）＋ PC ごとの local」から組み立てる。
# tasks/vicinae.toml の vicinae:sync から種類ごとに呼ぶ。入力（--argjson）:
#   $kind    {defkeys, statkeys, required, defaults} 定義として扱うキー・利用状況のキー・必須キー・
#            利用状況の既定値（shortcuts と snippets で異なる）
#   $shared  config-mac/vicinae/<kind>.shared.json（公開してよいものだけ）
#   $local   ~/.config/vicinae/<kind>.local.json（git 管理外。同じ id なら shared を上書き、
#            "hidden": true でこの PC では出さない）
#   $current Vicinae が今持っている JSON（GUI での変更・利用状況の取得元）
#   $synced  前回書き出した定義。GUI で変えたのか shared 側が変わったのかを区別するのに使う
#   $secrets config-mac/vicinae/sync.secret.yml（git 管理外）。文字列中の {{secret.<key>}} を置き換える
# 出力: {items, local, synced, report}
#
# GUI での追加・編集・削除はすべて local に取り込み、shared には書き戻さない
# （仕事の URL などが公開リポジトリへ紛れ込まないように）。

def defkeys: $kind.defkeys;
def byid: map({key: .id, value: .}) | from_entries;
def only($ks): . as $o | reduce $ks[] as $k ({}; if $o | has($k) then .[$k] = $o[$k] else . end);
def ids: map(.id);
def secret_re: "\\{\\{secret\\.(?<k>[A-Za-z0-9_]+)\\}\\}";
def secret_refs: [.. | strings | [match(secret_re; "g") | .captures[0].string][]] | unique;
def render: walk(if type == "string" then gsub(secret_re; $secrets[.k] | tostring) else . end);

($shared | byid) as $shm
| ($current | byid) as $curm
| ($synced | byid) as $prevm

# 1. GUI での変更を local に取り込む
| reduce ($current[] | select($prevm[.id] == null and $shm[.id] == null)) as $c (
    {local: $local, report: []};
    if any(.local[]; .id == $c.id) then .
    else
      .local += [{id: $c.id} + ($c | only(defkeys))]
      | .report += ["local に追加（GUI で作成）: \($c.name)"]
    end)
| reduce ($current[] | select($prevm[.id] != null)) as $c (.;
    ($c | only(defkeys)) as $now_def
    | ($prevm[$c.id] | only(defkeys)) as $prev_def
    | ([defkeys[] as $k | select($now_def[$k] != $prev_def[$k]) | {key: $k, value: $now_def[$k]}] | from_entries) as $diff
    | if $diff == {} then .
      elif ($shm[$c.id] == null) and (all(.local[]; .id != $c.id)) then
        # shared から消えた（git pull で削除された）ものを GUI でも触っていた場合は local に残す
        .local += [{id: $c.id} + $now_def]
        | .report += ["local に追加（shared から削除済み・GUI で編集あり）: \($c.name)"]
      else
        .local = [.local[] | if .id == $c.id then . + $diff else . end]
        | (if all(.local[]; .id != $c.id) then .local += [{id: $c.id} + $diff] else . end)
        | .report += ["local に反映（GUI で編集）: \($c.name) \($diff | keys | join(","))"]
      end)
| reduce ($synced[] | select($curm[.id] == null)) as $p (.;
    if $shm[$p.id] != null then
      .local = [.local[] | if .id == $p.id then . + {hidden: true} else . end]
      | (if all(.local[]; .id != $p.id) then .local += [{id: $p.id, hidden: true}] else . end)
      | .report += ["この PC では非表示（GUI で削除）: \($p.name)"]
    else
      .local = [.local[] | select(.id != $p.id)]
      | .report += ["local から削除（GUI で削除）: \($p.name)"]
    end)

# 2. shared に local を重ねて書き出す。秘密の値を埋め、利用状況は今のファイルから引き継ぐ
| (.local | byid) as $lom
| [($shared | ids)[], ((.local | ids)[] | select($shm[.] == null))] as $order
| [$order[] as $id
    | (($shm[$id] // {}) + ($lom[$id] // {})) as $def
    | select(($def.hidden // false) | not)
    | select($def[$kind.required] != null)
    | {id: $id, def: ($def | only(defkeys)), missing: ($def | only(defkeys) | secret_refs | map(select($secrets[.] == null)))}
  ] as $built
| .report += [$built[] | select(.missing != []) | "書き出さない（sync.secret.yml に \(.missing | join(", ")) がない）: \(.def.name)"]
| [$built[] | select(.missing == [])
    | {id} + (.def | render)
      + ($kind.defaults + (($curm[.id] // {}) | only($kind.statkeys)))
  ] as $out
| ($out | byid) as $outm
| .report += [$current[] | select($outm[.id] == null and $shm[.id] == null and $lom[.id] == null)
    | "削除（shared から削除済み）: \(.name)"]
| {
    items: $out,
    local: .local,
    synced: [$out[] | {id} + only(defkeys)],
    report: .report
  }
