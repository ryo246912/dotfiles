```sh
% jq

# if
jq -r '. | (if .<key> then "◯" else "☓" end)'

# key-value output [ex:jq -r '.scripts | to_entries[] | [.key,.value] | @csv']
jq -r '.<key> | to_entries[] | [.key,.value]'

# sort [ex:jq 'sort_by(.updatedAt) | reverse | .[] | [.nameWithOwner ,.updatedAt]']
jq -r 'sort_by(.<key>) | reverse | .[]'

# str + str [ex:jq '"\(.time) \(.fields.operation.Snapshot.op.commit_hash) \(.fields.operation.Snapshot.repo)"']
jq -r '"\(.<key>) \(.<key2>)"'

# format time [ex:(.pushed_at | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S"))]
jq -r '(.<key> | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d %H:%M:%S"))'

# header
jq -r '["<key1>","<key2>"], (.[] | [.<key1> , .<key2>]) | @tsv'
```

$ xxx: echo xxx
;$
