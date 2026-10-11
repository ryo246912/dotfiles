WITH RankedPaymentinfo AS (
    SELECT
        payer_id,
        created,
        RANK() OVER (PARTITION BY payer_id ORDER BY created) AS payment_rank
    FROM
        payments_paymentinfo
    WHERE
        created > CONVERT_TZ("{{date}}",'+00:00','+09:00')
),
_FirstAndSecondPaymentInfo AS (
    SELECT
        p1.payer_id AS user_id,
        p1.created AS first_payment_date,
        p2.created AS second_payment_date,
        RANK() OVER (PARTITION BY p2.payer_id ORDER BY p2.created) AS ranking
    FROM
        RankedPaymentinfo as p1
    LEFT JOIN
        RankedPaymentinfo as p2
    ON
        p1.payer_id = p2.payer_id
    WHERE
        p1.payment_rank = 1
        AND DATEDIFF(p2.created, p1.created) >= 1
),
FirstAndSecondPaymentInfo AS (
    SELECT
        user_id,
        first_payment_date,
        second_payment_date
    FROM
        _FirstAndSecondPaymentInfo
    WHERE
        ranking = 1
)

SELECT
    user.id as user_id,
    CONCAT('<a href="https://xxx/', user.old_key, 'full" target="_blank">',user.last_name, user.first_name,'</a>') as アカウント名,
    CONVERT_TZ(user.date_joined,'+00:00','+09:00') AS アカウント作成日時,
    CONVERT_TZ(first_payment_date,'+00:00','+09:00') AS 初回決済日時,
    CONVERT_TZ(second_payment_date,'+00:00','+09:00') AS 2回目決済日時,
    DATEDIFF(second_payment_date, first_payment_date) AS days_between_payments
FROM
    FirstAndSecondPaymentInfo
join xxxuser as user on FirstAndSecondPaymentInfo.user_id = user.id
where
    user.date_joined > CONVERT_TZ("{{date}}",'+00:00','+09:00');

WITH paymentinfo_summary AS (
SELECT
	DATE_FORMAT(CONVERT_TZ(paymentinfo.created, '+00:00', '+09:00'), '%Y-%m-%d') AS created_day
	,
	COUNT(paymentinfo.id) AS cnt
	,
	SUM(paymentinfo.price) AS price
FROM
	payments_paymentinfo AS paymentinfo
JOIN issues_proposal AS proposal ON
	paymentinfo.proposal_id = proposal.id
JOIN issues_issue AS issue ON
	paymentinfo.issue_id = issue.id
JOIN xxxuser AS user ON
	issue.author_id = user.old_key
WHERE
	1 = 1
	AND proposal.status IN ('delivered', 'payed')
	AND proposal.created > '2024-01-01'
	AND paymentinfo.is_canceled = 0
	AND issue.group_id = 0
GROUP BY
	created_day
)
