-- 計算Delivered Order三個生命週期間隔中位數
-- 1. Purchase → Approval
-- 2. Purchase → Carrier
-- 3. Purchase → Customer
-- 單位：秒

WITH valid_lifecycle_gap AS (

    -- 1. Purchase → Approval
    SELECT
        'purchase_to_approval' AS gap_type,

        TIMESTAMPDIFF(
            SECOND,
            order_purchase_timestamp,
            order_approved_at
        ) AS gap_seconds

    FROM olist_staging.stg_orders
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
      AND order_approved_at IS NOT NULL
      AND order_approved_at >= order_purchase_timestamp


    UNION ALL


    -- 2. Purchase → Carrier
    SELECT
        'purchase_to_carrier' AS gap_type,

        TIMESTAMPDIFF(
            SECOND,
            order_purchase_timestamp,
            order_delivered_carrier_date
        ) AS gap_seconds

    FROM olist_staging.stg_orders
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
      AND order_delivered_carrier_date IS NOT NULL
      AND order_delivered_carrier_date
          >= order_purchase_timestamp


    UNION ALL


    -- 3. Purchase → Customer
    -- 使用完整且順序正常的主生命週期計算
    SELECT
        'purchase_to_customer' AS gap_type,

        TIMESTAMPDIFF(
            SECOND,
            order_purchase_timestamp,
            order_delivered_customer_date
        ) AS gap_seconds

    FROM olist_staging.stg_orders
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
      AND order_delivered_carrier_date IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL

      AND order_delivered_carrier_date
          >= order_purchase_timestamp

      AND order_delivered_customer_date
          >= order_delivered_carrier_date
),

ranked_gap AS (
    SELECT
        gap_type,
        gap_seconds,

        ROW_NUMBER() OVER (
            PARTITION BY gap_type
            ORDER BY gap_seconds
        ) AS rn,

        COUNT(*) OVER (
            PARTITION BY gap_type
        ) AS gap_count

    FROM valid_lifecycle_gap
)

SELECT
    gap_type,
    MAX(gap_count) AS valid_order_cnt,

    AVG(gap_seconds) AS median_gap_seconds,

    ROUND(
        AVG(gap_seconds) / 3600,
        2
    ) AS median_gap_hours,

    ROUND(
        AVG(gap_seconds) / 86400,
        2
    ) AS median_gap_days

FROM ranked_gap

WHERE rn IN (
    FLOOR((gap_count + 1) / 2),
    FLOOR((gap_count + 2) / 2)
)

GROUP BY gap_type

ORDER BY
    CASE gap_type
        WHEN 'purchase_to_approval' THEN 1
        WHEN 'purchase_to_carrier' THEN 2
        WHEN 'purchase_to_customer' THEN 3
    END;