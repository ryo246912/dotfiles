# Plannotator / Effective HTML

## HTML artifactを作成してreviewする

Codexで`$html`、`$html-wireframe`、`$html-prototype`などのskillを指定して
HTML artifactを作成します。

作成したHTMLはPlannotator skillからreviewできます。Plannotatorはskill実行時に起動するため、
container起動時にPlannotatorを常駐起動する必要はありません。

```text
$plannotator-annotate path/to/artifact.html --render-html
```

CLIを直接実行する場合は次を使います。

```bash
plannotator annotate path/to/artifact.html --render-html
```

## code diffをreviewする

current branchの変更は次のskillでreviewします。

```text
$plannotator-review
```

GitHub PRをreviewする場合はPR URLを渡します。

```text
$plannotator-review https://github.com/owner/repository/pull/123
```

## agentの最後の返答をreviewする

```text
$plannotator-last
```
