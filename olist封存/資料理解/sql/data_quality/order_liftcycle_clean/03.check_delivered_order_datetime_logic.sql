-- 檢查delivered order 訂單生命週期是否符合邏輯

-- 檢查 delivered order 生命週期異常
-- Delivered order 生命週期邏輯異常類別分布


WITH order_lifecycle_check AS (
    SELECT
        order_id,

        -- Purchase → Approval
        CASE
            WHEN order_approved_at < order_purchase_timestamp
            THEN 1 ELSE 0
        END AS is_approved_before_purchase,

        -- Purchase → Carrier
        CASE
            WHEN order_delivered_carrier_date < order_purchase_timestamp
            THEN 1 ELSE 0
        END AS is_carrier_before_purchase,

        -- Purchase → Customer
        CASE
            WHEN order_delivered_customer_date < order_purchase_timestamp
            THEN 1 ELSE 0
        END AS is_customer_before_purchase,

        -- Approval → Carrier
        CASE
            WHEN order_delivered_carrier_date < order_approved_at
            THEN 1 ELSE 0
        END AS is_carrier_before_approval,

        -- Approval → Customer
        CASE
            WHEN order_delivered_customer_date < order_approved_at
            THEN 1 ELSE 0
        END AS is_customer_before_approval,

        -- Carrier → Customer
        CASE
            WHEN order_delivered_customer_date
                 < order_delivered_carrier_date
            THEN 1 ELSE 0
        END AS is_customer_before_carrier,

        -- 預估日期的基本合理性
        CASE
            WHEN order_estimated_delivery_date
                 < order_purchase_timestamp
            THEN 1 ELSE 0
        END AS is_estimated_before_purchase

    FROM olist_staging.stg_orders
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
      AND order_approved_at IS NOT NULL
      AND order_delivered_carrier_date IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),

anomaly_category AS (
    SELECT order_id, 'approved_before_purchase' AS anomaly_type
    FROM order_lifecycle_check
    WHERE is_approved_before_purchase = 1

    UNION ALL

    SELECT order_id, 'carrier_before_purchase'
    FROM order_lifecycle_check
    WHERE is_carrier_before_purchase = 1

    UNION ALL

    SELECT order_id, 'customer_before_purchase'
    FROM order_lifecycle_check
    WHERE is_customer_before_purchase = 1

    UNION ALL

    SELECT order_id, 'carrier_before_approval'
    FROM order_lifecycle_check
    WHERE is_carrier_before_approval = 1

    UNION ALL

    SELECT order_id, 'customer_before_approval'
    FROM order_lifecycle_check
    WHERE is_customer_before_approval = 1

    UNION ALL

    SELECT order_id, 'customer_before_carrier'
    FROM order_lifecycle_check
    WHERE is_customer_before_carrier = 1

    UNION ALL

    SELECT order_id, 'estimated_before_purchase'
    FROM order_lifecycle_check
    WHERE is_estimated_before_purchase = 1
),

anomaly_summary AS (
    SELECT
        COUNT(*) AS checked_order_cnt
    FROM order_lifecycle_check
),

anomaly_order_summary AS (
    SELECT
        COUNT(DISTINCT order_id) AS total_anomaly_order_cnt
    FROM anomaly_category
)

SELECT
    ac.anomaly_type,
    COUNT(DISTINCT ac.order_id) AS anomaly_order_cnt,

    ROUND(
        COUNT(DISTINCT ac.order_id) * 100.0 /
        s.checked_order_cnt,
        4
    ) AS pct_of_checked_orders,

    ROUND(
        COUNT(DISTINCT ac.order_id) * 100.0 /
        aos.total_anomaly_order_cnt,
        2
    ) AS pct_of_anomaly_orders

FROM anomaly_category AS ac
CROSS JOIN anomaly_summary AS s
CROSS JOIN anomaly_order_summary AS aos

GROUP BY
    ac.anomaly_type,
    s.checked_order_cnt,
    aos.total_anomaly_order_cnt

ORDER BY anomaly_order_cnt DESC;