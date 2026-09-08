SELECT
    MIN(payment_value) as min_payment_value,
    MAX(payment_value) as max_payment_value
FROM olist_staging.stg_payments
