# Vicinae の shortcuts.json を「共有（dotfiles）＋ PC ごとの local」から組み立てる。
# tasks/vicinae.toml の vicinae:shortcuts:sync から呼ぶ。入力（--argjson）:
#   $shared  config-mac/vicinae/shortcuts.shared.json（公開してよいものだけ）
#   $local   ~/.config/vicinae/shortcuts.local.json（git 管理外。同じ id なら shared を上書き、
#            "hidden": true でこの PC では出さない）
#   $current Vicinae が今持っている shortcuts.json（GUI での変更・利用状況の取得元）
#   $synced  前回書き出した定義。GUI で変えたのか shared 側が変わったのかを区別するのに使う
#   $now     作成日時の既定値（epoch 秒）
# 出力: {shortcuts, local, synced, report}
#
# GUI での追加・編集・削除はすべて local に取り込み、shared には書き戻さない
# （仕事の URL などが公開リポジトリへ紛れ込まないように）。

def defkeys: ["name", "icon", "url", "app"];
def statkeys: ["openCount", "createdAt", "updatedAt", "lastUsedAt"];
def byid: map({key: .id, value: .}) | from_entries;
def only($ks): . as $o | reduce $ks[] as $k ({}; if $o | has($k) then .[$k] = $o[$k] else . end);
def ids: map(.id);

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

# 2. shared に local を重ねて書き出す。利用状況は今のファイルから引き継ぐ
| (.local | byid) as $lom
| [($shared | ids)[], ((.local | ids)[] | select($shm[.] == null))] as $order
| [$order[] as $id
    | (($shm[$id] // {}) + ($lom[$id] // {})) as $def
    | select(($def.hidden // false) | not)
    | select($def.url != null)
    | {id: $id} + ($def | only(defkeys))
      + ({openCount: 0, createdAt: $now, updatedAt: $now} + (($curm[$id] // {}) | only(statkeys)))
  ] as $out
| ($out | byid) as $outm
| .report += [$current[] | select($outm[.id] == null and $shm[.id] == null and $lom[.id] == null)
    | "削除（shared から削除済み）: \(.name)"]
| {
    shortcuts: $out,
    local: .local,
    synced: [$out[] | {id} + only(defkeys)],
    report: .report
  }
