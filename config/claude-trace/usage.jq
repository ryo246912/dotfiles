# claude-trace の JSONL から /v1/messages の request ごとに token 内訳を出す
def sse: [.response.body_raw // "" | splits("\n") | select(startswith("data: ")) | .[6:] | fromjson?];
def usage:
  if .response.body.usage then .response.body.usage
  else (sse) as $e
    | (($e | map(select(.type == "message_start"))[0].message.usage) // {})
      + {output_tokens: (($e | map(select(.type == "message_delta"))[-1].usage.output_tokens) // 0)}
  end;
select(.request.url | test("/v1/messages"))
| usage as $u
| [ (.request.timestamp | floor | todate),
    (.request.body.model // "-"),
    ((.request.body.messages // []) | length),
    ((.request.body.tools // []) | length),
    ($u.input_tokens // 0),
    ($u.cache_read_input_tokens // 0),
    ($u.cache_creation_input_tokens // 0),
    ($u.output_tokens // 0) ]
| @tsv
