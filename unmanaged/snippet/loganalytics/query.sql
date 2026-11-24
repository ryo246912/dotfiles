SELECT
  timestamp,
  RANK() OVER (PARTITION BY trace ORDER BY timestamp_unix_nanos ASC) AS rank,
  severity_number,
  http_request.request_url,
  text_payload,
  http_request,
  labels,
  trace
FROM
  `xxx`
WHERE trace IN (
  SELECT
    trace
  FROM
    `xxx`
  WHERE
    1 = 1
    and severity = "ERROR"
    and resource.type = "cloud_run_revision"
    and JSON_VALUE(labels.service) = "xxx"
    and REGEXP_CONTAINS(http_request.request_url, r".*/api/v3/proposals/\d{6,7}/pay/webpay")
  )
ORDER BY TIMESTAMP_TRUNC(timestamp,MINUTE) DESC, trace, rank;
