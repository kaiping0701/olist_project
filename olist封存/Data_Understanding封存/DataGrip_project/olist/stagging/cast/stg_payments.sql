CREATE TABLE IF NOT EXISTS olist_staging.stg_payments AS
SELECT
    order_id,

    CAST(payment_sequential AS UNSIGNED)
        AS payment_sequential,

    payment_type,

    CAST(payment_installments AS UNSIGNED)
        AS payment_installments,

    CAST(payment_value AS DECIMAL(10,2))
        AS payment_value

FROM olist_raw.payments;