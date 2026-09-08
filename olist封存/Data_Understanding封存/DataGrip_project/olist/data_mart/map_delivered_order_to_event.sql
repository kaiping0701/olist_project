DROP TABLE IF EXISTS olist_data_mart.map_delivered_order_to_event;

CREATE TABLE olist_data_mart.map_delivered_order_to_event(
    order_id VARCHAR(50) PRIMARY KEY,
    order_event_key INT UNSIGNED NOT NULL,
    customer_unique_id VARCHAR(50) NOT NULL,
    order_purchase_timestamp DATETIME NOT NULL,
    event_purchase_timestamp DATETIME NOT NULL
);

INSERT INTO olist_data_mart.map_delivered_order_to_event(
    order_id,
    order_event_key,
    customer_unique_id,
    order_purchase_timestamp,
    event_purchase_timestamp
)

WITH order_customer_previous_ts AS(

    SELECT
        o.order_id,
        o.order_purchase_timestamp,
        c.customer_unique_id,
        LAG(o.order_purchase_timestamp,1) OVER(PARTITION BY c.customer_unique_id
                                              ORDER BY o.order_purchase_timestamp ASC,o.order_id ASC)
                                        AS previous_ts
FROM olist_staging.stg_orders as o
INNER JOIN olist_staging.stg_customers as c
ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
),

order_customer_gap_seconds AS(
    SELECT *,
           TIMESTAMPDIFF(SECOND,previous_ts,order_purchase_timestamp) as gap_seconds
    FROM order_customer_previous_ts

),
order_customer_new_event_flag AS(
    SELECT *,
           CASE
               WHEN gap_seconds IS NULL THEN 1
               WHEN gap_seconds <= 60 THEN 0
               WHEN gap_seconds > 60 THEN 1
               ELSE NULL
           END AS new_event_flag
    FROM order_customer_gap_seconds
),

order_customer_local_event_id AS(
    SELECT *,
           SUM(new_event_flag) OVER(PARTITION BY customer_unique_id
                                    ORDER BY order_purchase_timestamp ASC,order_id ASC
                                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                    AS local_event_id
    FROM order_customer_new_event_flag
),
order_customer_event_key AS(
    SELECT *,
           DENSE_RANK() OVER(ORDER BY customer_unique_id ASC, local_event_id ASC)
            AS order_event_key
    FROM order_customer_local_event_id
)

SELECT
    order_id,
    order_event_key,
    customer_unique_id,
    order_purchase_timestamp,

    MIN(order_purchase_timestamp) OVER (
        PARTITION BY order_event_key
    ) AS event_purchase_timestamp

FROM order_customer_event_key;

