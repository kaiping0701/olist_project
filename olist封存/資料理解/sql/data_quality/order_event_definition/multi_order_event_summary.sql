USE olist_staging;

WITH customer_ts_order AS (
    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp,
        o.order_id,
        o.order_status,

        COUNT(*) OVER (
            PARTITION BY c.customer_unique_id, o.order_purchase_timestamp
        ) AS order_cnt
    FROM stg_orders AS o
    LEFT JOIN stg_customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

event_level AS (
    SELECT DISTINCT
        customer_unique_id,
        order_purchase_timestamp,
        order_cnt
    FROM customer_ts_order
)

SELECT
    -- 1. multi order event count
    SUM(
        CASE
            WHEN order_cnt > 1 THEN 1
            ELSE 0
        END
    ) AS multi_order_event_cnt,

    -- 2. 總 order event count
    COUNT(*) AS total_order_event_cnt,

    -- 3. multi order event 佔總 order event 比例
    ROUND(
        SUM(
            CASE
                WHEN order_cnt > 1 THEN 1
                ELSE 0
            END
        ) / COUNT(*) * 100,
        4
    ) AS multi_order_event_rate_pct,

    -- 4. 隸屬於 multi order event 的 order count
    SUM(
        CASE
            WHEN order_cnt > 1 THEN order_cnt
            ELSE 0
        END
    ) AS multi_order_event_order_cnt,

    -- 5. 總 order count
    (
        SELECT COUNT(*)
        FROM customer_ts_order
    ) AS total_order_cnt,

    -- 6. multi order event order count 佔總 order count 比例
    ROUND(
        SUM(
            CASE
                WHEN order_cnt > 1 THEN order_cnt
                ELSE 0
            END
        ) / (
            SELECT COUNT(*)
            FROM customer_ts_order
        ) * 100,
        4
    ) AS multi_order_event_order_rate_pct

FROM event_level;