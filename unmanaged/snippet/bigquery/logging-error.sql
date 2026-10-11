SELECT DISTINCT
  insertId as Id,
  timestamp as d,
  TIMESTAMP_ADD(timestamp, INTERVAL 9 HOUR) as datetime,
  protoPayload.resource as resource,
  protoPayload.startTime as startTime,
  protoPayload.userAgent as userAgent,
  protoPayload.latency as latency,
  protoPayload.method as method,
  protoPayload.referrer as referrer,
  ARRAY_TO_STRING(ARRAY (
    SELECT
    CASE
      WHEN CONTAINS_SUBSTR(logMessage,"Traceback")
      -- logMessageを各行で分割して配列にして、下3行を取得する
      THEN ARRAY_TO_STRING(
        ARRAY_REVERSE(
          ARRAY(
            SELECT x from unnest(SPLIT(logMessage,"\n")) as x WITH OFFSET AS offset ORDER BY offset DESC LIMIT 3
            )
        ),"\n")
      ELSE logMessage
    END
    from UNNEST(protoPayload.line) WITH OFFSET AS offset
  where severity = "ERROR"
  ORDER BY offset DESC LIMIT 3), "\n") AS message,
  RetrySuscess,
FROM
  (
    SELECT
      insertId,
      severity,
      timestamp,
      protoPayload,
      LOGICAL_OR(severity = "INFO" AND protoPayload.status=200) OVER (
        PARTITION BY COALESCE(CONCAT("[",protoPayload.method,"]", protoPayload.resource,"■", protoPayload.referrer,"■", protoPayload.userAgent),insertId)
        ORDER BY UNIX_SECONDS(timestamp)
        RANGE BETWEEN 120 PRECEDING AND 300 FOLLOWING
      ) AS RetrySuscess,
    FROM
      `logs.appengine_googleapis_com_request_log_*`
    WHERE
      1 = 1
      AND _TABLE_SUFFIX BETWEEN '20231123' AND '20231123'
      -- AND _TABLE_SUFFIX BETWEEN FORMAT_DATE("%Y%m%d", CURRENT_DATE("Asia/Tokyo") - 1) AND FORMAT_DATE("%Y%m%d", CURRENT_DATE("Asia/Tokyo"))
      -- AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  )
WHERE
  1 = 1
  AND (severity = "ERROR" OR severity = "CRITICAL")
ORDER BY timestamp ASC
LIMIT 1000;
