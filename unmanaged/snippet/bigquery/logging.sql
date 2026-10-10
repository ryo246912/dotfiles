WITH target_traces AS (
  SELECT
    l.trace
  FROM
    logs.appengine_googleapis_com_request_log_20230524 AS l
  JOIN
    UNNEST(l.protoPayload.line) AS line
  ON TRUE
  WHERE
    line.logMessage LIKE "%xxx%"
)

SELECT
  log.timestamp,
  log.severity,
  log.insertId,
  log.protoPayload.ip,
  log.protoPayload.resource,
  line.time AS line_time,
  line.severity AS line_severity,
  line.logMessage AS line_logMessage,
  line.sourceLocation.file AS line_file,
  line.sourceLocation.line AS line_line,
  line.sourceLocation.functionName AS line_function,
  log.protoPayload.startTime as start_time,
  log.protoPayload.userAgent,
  log.protoPayload.latency,
  log.protoPayload.method,
  log.protoPayload.referrer
FROM
  logs.appengine_googleapis_com_request_log_20230524 AS log
JOIN
  target_traces t
ON
  log.trace = t.trace
JOIN
  UNNEST(log.protoPayload.line) AS line
ON TRUE
ORDER BY
  log.timestamp
LIMIT 50000
