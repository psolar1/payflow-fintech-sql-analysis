WITH customer_monthly AS (
    SELECT
        t.customer_id,
        DATE_TRUNC('month', t.transaction_time) AS month,

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
        DATE_TRUNC('month', t.transaction_time)
),

customer_metrics AS (
    SELECT
        customer_id,
        month,
        gross_tpv_gbp,
        refund_total_gbp,
        chargeback_total_gbp,

        gross_tpv_gbp
        - refund_total_gbp
        - chargeback_total_gbp AS net_tpv_gbp,

        100.0 * refund_total_gbp
        / NULLIF(gross_tpv_gbp, 0) AS refund_rate,

        100.0 * chargeback_total_gbp
        / NULLIF(gross_tpv_gbp, 0) AS chargeback_rate

    FROM customer_monthly
),

risk_queue AS (
    SELECT
        customer_id,
        COUNT(*) FILTER (
            WHERE chargeback_rate > 5
               OR refund_rate > 10
               OR net_tpv_gbp < 0
        ) AS flagged_months,

        SUM(net_tpv_gbp) AS total_net_tpv_gbp

    FROM customer_metrics

    GROUP BY customer_id
)

SELECT
    customer_id,
    flagged_months,
    ROUND(total_net_tpv_gbp, 2) AS total_net_tpv_gbp

FROM risk_queue

WHERE flagged_months > 0

ORDER BY
    flagged_months DESC,
    customer_id;
