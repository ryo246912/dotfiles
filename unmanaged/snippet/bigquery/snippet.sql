#standardSQL

DECLARE date_start_utc, date_last_utc DATE;
DECLARE table_suffix_start, table_suffix_last STRING;

SET date_start_utc = "2024-05-23";
SET date_last_utc = "2025-05-08";
SET table_suffix_start = FORMAT_DATE("%Y%m%d", date_start_utc);
SET table_suffix_last = FORMAT_DATE("%Y%m%d", date_last_utc);
-- SET table_suffix_start = FORMAT_DATE("%Y%m%d", CURRENT_DATE("Asia/Tokyo") - 1); -- i.e. yesterday
-- SET table_suffix_last = FORMAT_DATE("%Y%m%d", CURRENT_DATE("Asia/Tokyo")); -- i.e. today

WITH
logging AS (
  SELECT
    resource.labels.service_name as service_name,
    resource.labels.revision_name as revision_name,
    textpayload,
    timestamp,
    severity,
    insertId,
    jsonPayload.message as message,
  FROM
    `xxx_*`
  WHERE
    _TABLE_SUFFIX BETWEEN table_suffix_start AND table_suffix_last
    AND trace IN (
      SELECT
        trace
      FROM
        `xxx_*`
      WHERE
        1 = 1
        AND _TABLE_SUFFIX BETWEEN table_suffix_start AND table_suffix_last
        AND jsonPayload.message LIKE "%xxx%"
    )
),
traceIds AS (
  SELECT
    trace
  FROM
    `xxx_*`
  WHERE
    1 = 1
    AND _TABLE_SUFFIX BETWEEN table_suffix_start AND table_suffix_last
    AND jsonPayload.message LIKE "%xxx%"
)

SELECT
  resource.labels.service_name as service_name,
  resource.labels.revision_name as revision_name,
  textpayload,
  timestamp,
  severity,
  insertId,
  jsonPayload.message as message,
FROM
  `xxx_*`
WHERE
  1 = 1
  AND _TABLE_SUFFIX BETWEEN table_suffix_start AND table_suffix_last
  AND trace IN (
    SELECT
      trace
    FROM
      `xxx_*`
    WHERE
      _TABLE_SUFFIX BETWEEN table_suffix_start AND table_suffix_last
      AND jsonPayload.message LIKE "%xxx%"
  )
