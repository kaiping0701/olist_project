# order表，進行order_status分組的日期缺失檢查，看看是否為業務正常缺失
USE olist_staging;
SELECT
    order_status,
    COUNT(*) AS row_count,

    SUM(order_approved_at IS NULL) AS null_approved_at,
    ROUND(SUM(order_approved_at IS NULL) / COUNT(*) * 100, 2) AS null_approved_at_rate,

    SUM(order_delivered_carrier_date IS NULL) AS null_carrier_date,
    ROUND(SUM(order_delivered_carrier_date IS NULL) / COUNT(*) * 100, 2) AS null_carrier_date_rate,

    SUM(order_delivered_customer_date IS NULL) AS null_customer_date,
    ROUND(SUM(order_delivered_customer_date IS NULL) / COUNT(*) * 100, 2) AS null_customer_date_rate

FROM stg_orders
GROUP BY order_status
ORDER BY row_count DESC;