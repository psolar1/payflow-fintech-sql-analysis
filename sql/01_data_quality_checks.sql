-- PayFlow Fintech Analytics
-- Data quality checks
-- Monthly Gross TPV in GBP

SELECT
    DATE_TRUNC('month', t.transaction_time)::date AS month,
    ROUND(SUM(t.amount * f.rate_to_gbp), 2) AS total_gross_tpv_gbp,
    COUNT(*) AS transaction_count,
    COUNT(DISTINCT t.customer_id) AS active_customers
FROM transactions AS t
JOIN fx_rates AS f
    ON CAST(t.transaction_time AS DATE) = CAST(f.date AS DATE)
    AND t.currency = f.currency
WHERE t.status = 'success'
GROUP BY
    DATE_TRUNC('month', t.transaction_time)::date
ORDER BY
    month;
