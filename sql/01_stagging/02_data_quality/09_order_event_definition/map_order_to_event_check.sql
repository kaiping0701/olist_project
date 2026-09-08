WITH delivered_order_count AS (
    SELECT
        COUNT(*) AS delivered_orders
    FROM olist_staging.stg_orders
    WHERE order_status = 'delivered'
),

map_summary AS (
    SELECT
        COUNT(*) AS map_rows,
        COUNT(DISTINCT order_id) AS distinct_order_count
    FROM olist_data_mart.map_delivered_order_to_event
),

cross_customer_event AS (
    SELECT
        COUNT(*) AS invalid_event_count
    FROM (
        SELECT
            order_event_key
        FROM olist_data_mart.map_delivered_order_to_event
        GROUP BY order_event_key
        HAVING COUNT(DISTINCT customer_unique_id) > 1
    ) AS invalid_events
)

SELECT
    d.delivered_orders,
    m.map_rows,
    m.distinct_order_count,
    c.invalid_event_count,

    CASE
        WHEN d.delivered_orders = m.map_rows
         AND m.map_rows = m.distinct_order_count
         AND c.invalid_event_count = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_status

FROM delivered_order_count AS d
CROSS JOIN map_summary AS m
CROSS JOIN cross_customer_event AS c;