SELECT
    payment_type,
    payment_installments,
    COUNT(*) AS cnt
FROM olist_staging.stg_payments
GROUP BY
    payment_type,
    payment_installments
ORDER BY
    payment_type,
    payment_installments;