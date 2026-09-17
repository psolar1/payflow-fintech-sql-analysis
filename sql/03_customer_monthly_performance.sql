WITH monthly_data AS (
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
        ) AS chargeback_total_gbp,

        COUNT(t.transaction_id) AS transaction_count

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
)

SELECT
    customer_id,
    month,

    ROUND(gross_tpv_gbp, 2) AS gross_tpv_gbp,

    ROUND(refund_total_gbp, 2) AS refund_total_gbp,

    ROUND(chargeback_total_gbp, 2) AS chargeback_total_gbp,

    ROUND(
        gross_tpv_gbp
        - refund_total_gbp
        - chargeback_total_gbp,
        2
    ) AS net_tpv_gbp,

    transaction_count

FROM monthly_data

ORDER BY
    month,
    customer_id;
