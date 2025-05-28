SELECT
  JSON_VALUE(labels.instanceId),
  count(1) as cnt
FROM
  `xxx`
WHERE
  1 = 1
  and severity = "ERROR"
  and resource.type = "cloud_run_revision"
  and JSON_VALUE(labels.service) = "xxx"
GROUP BY JSON_VALUE(labels.instanceId)
ORDER BY cnt DESC;
