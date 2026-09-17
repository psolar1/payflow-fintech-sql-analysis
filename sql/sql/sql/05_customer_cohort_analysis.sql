WITH customer_monthly AS (
    SELECT
        t.customer_id,
        DATE_TRUNC('month', t.transaction_time)::date AS activity_month,

        SUM(t.amount * fx.rate_to_gbp) AS gross_tpv_gbp,

        COALESCE(
            SUM(r.refund_amount * fx.rate_to_gbp),
            0
        ) AS refund_total_gbp,

        COALESCE(
            SUM(c.amount * fx.rate_to_gbp),
            0
        ) AS chargeback_total_gbp

    FROM transactions t

    JOIN fx_rates fx
        ON DATE(t.transaction_time) = fx.date
        AND t.currency = fx.currency

    LEFT JOIN refunds r
        ON t.transaction_id = r.transaction_id

    LEFT JOIN chargebacks c
        ON t.transaction_id = c.transaction_id

    WHERE t.status = 'success'

    GROUP BY
        t.customer_id,
        DATE_TRUNC('month', t.transaction_time)::date
),

customer_net AS (
    SELECT
        customer_id,
        activity_month,
        gross_tpv_gbp
        - refund_total_gbp
        - chargeback_total_gbp AS net_tpv_gbp
    FROM customer_monthly
),

customer_cohorts AS (
    SELECT
        customer_id,
        MIN(activity_month) AS cohort_month
    FROM customer_net
    GROUP BY customer_id
),

cohort_activity AS (
    SELECT
        cc.cohort_month,
        cn.activity_month,

        (
            EXTRACT(YEAR FROM cn.activity_month)
            - EXTRACT(YEAR FROM cc.cohort_month)
        ) * 12
        +
        (
            EXTRACT(MONTH FROM cn.activity_month)
            - EXTRACT(MONTH FROM cc.cohort_month)
        ) AS months_since_start,

        cn.customer_id,
        cn.net_tpv_gbp

    FROM customer_net cn
    JOIN customer_cohorts cc
        ON cn.customer_id = cc.customer_id
)

SELECT
    cohort_month,
    activity_month,
    months_since_start,
    COUNT(DISTINCT customer_id) AS number_of_customers,
    ROUND(SUM(net_tpv_gbp), 2) AS total_net_tpv_gbp

FROM cohort_activity

GROUP BY
    cohort_month,
    activity_month,
    months_since_start

ORDER BY
    cohort_month,
    activity_month;
