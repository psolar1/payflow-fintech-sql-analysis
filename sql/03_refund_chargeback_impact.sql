-- PayFlow Fintech Analytics
-- Monthly Refund & Chargeback Impact


WITH monthly_data AS (
    SELECT
        DATE_TRUNC('month', t.transaction_time) AS month,

        SUM(t.amount * fx.rate_to_gbp) AS gross_tpv_gbp,

        COALESCE(
            SUM(r.refund_amount * fx.rate_to_gbp),
            0
        ) AS total_refunds_gbp,

        COALESCE(
            SUM(c.amount * fx.rate_to_gbp),
            0
        ) AS total_chargebacks_gbp

    FROM transactions t

    JOIN fx_rates fx
        ON DATE(t.transaction_time) = fx.date
        AND t.currency = fx.currency

    LEFT JOIN refunds r
        ON t.transaction_id = r.transaction_id

    LEFT JOIN chargebacks c
        ON t.transaction_id = c.transaction_id

    WHERE t.status = 'success'

    GROUP BY DATE_TRUNC('month', t.transaction_time)
)

SELECT
    month,

    ROUND(gross_tpv_gbp, 2) AS gross_tpv_gbp,

    ROUND(total_refunds_gbp, 2) AS total_refunds_gbp,

    ROUND(total_chargebacks_gbp, 2) AS total_chargebacks_gbp,

    ROUND(
        gross_tpv_gbp
        - total_refunds_gbp
        - total_chargebacks_gbp,
        2
    ) AS net_tpv_gbp,

    ROUND(
        100.0 * total_refunds_gbp / gross_tpv_gbp,
        2
    ) AS refund_rate,

    ROUND(
        100.0 * total_chargebacks_gbp / gross_tpv_gbp,
        2
    ) AS chargeback_rate

FROM monthly_data

ORDER BY month;
