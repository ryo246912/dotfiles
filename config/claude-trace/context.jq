# 最後の /v1/messages request に載っていた tool_result を大きい順に並べる
[.[] | select(.request.url | test("/v1/messages"))][-1].request.body.messages as $m
| ([$m[] | select(.role == "assistant") | .content | arrays | .[] | select(.type == "tool_use")
    | {key: .id, value: "\(.name) \(.input.command // .input.file_path // .input.pattern // "" | tostring | .[0:60])"}]
   | from_entries) as $uses
| $m[] | select(.role == "user") | .content | arrays | .[] | select(.type == "tool_result")
| [(.content | tostring | length), ($uses[.tool_use_id] // .tool_use_id)]
| @tsv
