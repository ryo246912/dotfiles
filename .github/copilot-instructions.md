# RTK - Token-Optimized CLI

- 必ず日本語で回答してください。

## RTK の使い方

- shell command は可能な限り `rtk` を前置して実行してください。
- VS Code Copilot Chat では `.github/hooks/rtk-rewrite.json` が `updatedInput` で自動書き換えします。
- Copilot CLI は `updatedInput` 非対応のため、deny-with-suggestion で提案された `rtk ...` command をそのまま再実行してください。

## 代表例

```bash
rtk git status
rtk git log -10
rtk cargo test
rtk docker ps
rtk kubectl get pods
```

## Meta Commands

```bash
rtk gain
rtk gain --history
rtk discover
rtk proxy <cmd>
```
