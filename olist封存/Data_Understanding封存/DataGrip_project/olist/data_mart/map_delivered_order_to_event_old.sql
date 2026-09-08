DROP TABLE IF EXISTS olist_data_mart.map_delivered_order_to_event;

CREATE TABLE olist_data_mart.map_delivered_order_to_event(
    order_id VARCHAR(50) PRIMARY KEY,
    order_event_key INT NOT NULL,
    customer_unique_id VARCHAR(50) NOT NULL,
    order_purchase_timestamp DATETIME NOT NULL
);

INSERT INTO olist_data_mart.map_delivered_order_to_event(
    order_id,
    order_event_key,
    customer_unique_id,
    order_purchase_timestamp
)
WITH customer_order AS(
    SELECT
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp


    FROM olist_staging.stg_orders as o
    INNER JOIN olist_staging.stg_customers as c
    ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

order_event_map AS(
    SELECT
        order_id,
        DENSE_RANK() OVER( ORDER BY order_purchase_timestamp ASC,customer_unique_id ASC)
        AS order_event_key,
        customer_unique_id,
        order_purchase_timestamp
    FROM customer_order
)

SELECT
    order_id,
    order_event_key,
    customer_unique_id,
    order_purchase_timestamp
FROM order_event_map;
