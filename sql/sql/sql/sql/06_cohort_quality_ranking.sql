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
),

first_three_months AS (
    SELECT
        cohort_month,
        SUM(net_tpv_gbp) AS cumulative_net_tpv_first_3m,
        COUNT(DISTINCT customer_id) AS cohort_customers
    FROM cohort_activity
    WHERE months_since_start <= 2
    GROUP BY cohort_month
),

ranked_cohorts AS (
    SELECT
        cohort_month,
        cumulative_net_tpv_first_3m,
        cumulative_net_tpv_first_3m
        / NULLIF(cohort_customers, 0) AS avg_customer_value,

        RANK() OVER (
            ORDER BY cumulative_net_tpv_first_3m DESC
        ) AS performance_rank

    FROM first_three_months
)

SELECT
    cohort_month,
    ROUND(cumulative_net_tpv_first_3m, 2)
        AS cumulative_net_tpv_first_3m,
    ROUND(avg_customer_value, 2)
        AS avg_customer_value,
    performance_rank

FROM ranked_cohorts

ORDER BY performance_rank;
