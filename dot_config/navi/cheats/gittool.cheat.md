```sh
% git-tool

# dura serve
dura serve | jq '"\(.time) \(.fields.operation.Snapshot.op.commit_hash) \(.fields.operation.Snapshot.repo)"'

# dura watch
(cd $(z | sort -rn | cut -c 12- | fzf) && ghq list --full-path | xargs -I % sh -c "cd % && dura watch")

# dura unwatch
(cd $(z | sort -rn | cut -c 12- | fzf) && ghq list --full-path | xargs -I % sh -c "cd % && dura unwatch")

# dura delete branch [optional:git branch -l "dura*" | grep -vE "dura/$(git rev-parse HEAD)"]
git branch -l 'dura*' | xargs -I % git branch -D %

# gita display repo dirs
gita freeze | column -ts, | awk '{print $3}'

# ghq clone [ex:ghq get x-motemen/ghq , ghq get https://github.com/x-motemen/ghq]
ghq get <url>
```

$ xxx: echo xxx
;$
