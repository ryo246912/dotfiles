SET @month_start = DATE_FORMAT('{{開始月}}', '%Y-%m-01');
SET @month_end = LAST_DAY(@month_start);
SET @target_price = {{目標決済金額(円)}};
SET @target_number = {{目標決済数}};

-- 'YYYY-MM-01'という日付から当該月の1日から最終日までの集合を再帰的に生成
-- 例)'2024-12-01' から '2024-12-01'~'2024-12-31'までの集合を生成
WITH RECURSIVE date_range AS (
  SELECT DATE(@month_start) AS generated_date
  UNION ALL
  SELECT DATE_ADD(generated_date, INTERVAL 1 DAY)
  FROM date_range
  WHERE generated_date < @month_end
)
-- 日付及びそれが平日or休日かを判定
, _dates AS (
SELECT
    generated_date as _date
    ,CASE
        WHEN DAYOFWEEK(generated_date) IN (1,7) THEN 0 -- 土日はカウントしないようにする
        WHEN FIND_IN_SET(DATE_FORMAT(generated_date,'%Y-%m-%d'),'{{祝日}}') THEN 0  -- 祝日の日付と一致するものはカウントしないようにする、祝日例)2024-11-03,2024-11-04
        ELSE 1
    END AS weekday
FROM date_range
)
-- 当月の平日数を算出
,dates AS (
SELECT
    *
    ,SUM(weekday) OVER (ORDER BY _date) as days -- 平日分が何日目かを算出
FROM _dates
)
-- 1日毎の目標を算出
, daily_target AS (
SELECT
    _date -- 日付
    -- N日での目標金額=目標決済金額 / (1ヶ月の平日数) * (平日N日目)
    ,FLOOR(@target_price / (SELECT SUM(weekday) FROM dates) * days) as price
    -- N日での目標決済数=目標決済数 / (1ヶ月の平日数) * (平日N日目)
    ,FLOOR(@target_number / (SELECT SUM(weekday) FROM dates) * days) as num
FROM dates
)
-- 1日毎の実際の決済金額・決済件数を算出
,paymentinfo_summary AS (
SELECT
	DATE_FORMAT(CONVERT_TZ(paymentinfo.created, '+00:00', '+09:00'), '%Y-%m-%d') AS _date -- 日付(YYYY-MM-DD)
	,COUNT(paymentinfo.id) AS num  -- 決済数
	,SUM(paymentinfo.price) AS price  -- 決済金額合計
	-- ,COUNT(distinct issue.author_id) AS reqnum  -- ユニーク依頼者数
FROM
	payments_paymentinfo AS paymentinfo
JOIN issues_proposal AS proposal ON
	paymentinfo.proposal_id = proposal.id
JOIN issues_issue AS issue ON
	paymentinfo.issue_id = issue.id
WHERE
	1 = 1
	AND proposal.status IN ('delivered', 'payed')
	AND CONVERT_TZ(paymentinfo.created, '+00:00', '+09:00') > @month_start
	AND paymentinfo.is_canceled = 0
	AND issue.group_id = 0 -- lite案件
GROUP BY
	_date
)

SELECT
	daily_target._date AS '日付'
    -- 決済金額(税込)
	,paymentinfo_summary.price AS '決済金額(daily)'
	,SUM(paymentinfo_summary.price) OVER (ORDER BY paymentinfo_summary._date) AS '決済金額(積み上げ)'
	,(SELECT SUM(price) FROM paymentinfo_summary) AS '当月決済金額'
	,daily_target.price AS '目標決済金額(積み上げ)'
	,@target_price AS '目標決済金額(合計)'
	,@target_price * 1 / 2 AS '目標決済金額(合計,50%)'
	-- 取扱高(決済金額の税抜)
	,paymentinfo_summary.price/1.1 AS '取扱高(daily)'
	,SUM(paymentinfo_summary.price/1.1) OVER (ORDER BY paymentinfo_summary._date) AS '取扱高(積み上げ)'
	,(SELECT SUM(price) FROM paymentinfo_summary)/1.1 AS '当月取扱高'
	,daily_target.price/1.1 AS '目標取扱高(積み上げ)'
	,@target_price/1.1 AS '目標取扱高(合計)'
	,@target_price/1.1 * 1 / 2 AS '目標取扱高(合計,50%)'
	-- 営業収益
	,paymentinfo_summary.price/1.1*0.3 AS '営業収益(daily)'
	,SUM(paymentinfo_summary.price/1.1*0.3) OVER (ORDER BY paymentinfo_summary._date) AS '営業収益(積み上げ)'
	,(SELECT SUM(price) FROM paymentinfo_summary)/1.1*0.3 AS '当月営業収益'
	,daily_target.price/1.1*0.3 AS '目標営業収益(積み上げ)'
	,@target_price/1.1*0.3 AS '目標営業収益(合計)'
	,@target_price/1.1*0.3 * 1 / 2 AS '目標営業収益(合計,50%)'
    -- 決済数
	,paymentinfo_summary.num  AS '決済件数(daily)'
	,SUM(paymentinfo_summary.num) OVER (ORDER BY paymentinfo_summary._date) AS '決済件数(積み上げ)'
	,(SELECT SUM(num) FROM paymentinfo_summary) AS '当月決済件数'
	,daily_target.num AS '目標決済件数(積み上げ)'
	,@target_number AS '目標決済件数(合計)'
	,@target_number * 1 / 2 AS '目標決済件数(合計,50%)'

FROM
    daily_target
LEFT JOIN paymentinfo_summary
ON paymentinfo_summary._date = daily_target._date
WHERE 1 = 1
    AND daily_target._date BETWEEN @month_start AND @month_end
ORDER BY daily_target._date;
