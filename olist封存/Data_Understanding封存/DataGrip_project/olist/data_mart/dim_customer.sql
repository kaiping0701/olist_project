
DROP TABLE IF EXISTS olist_data_mart.dim_customer;

CREATE TABLE olist_data_mart.dim_customer(
    customer_key INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_unique_id VARCHAR(50) NOT NULL UNIQUE,
    customer_zip_code_prefix INT,
    customer_city VARCHAR(100),
    customer_state CHAR(2)
);

INSERT INTO olist_data_mart.dim_customer
(
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
WITH customer_rank AS(
    SELECT c.customer_unique_id,
           o.order_purchase_timestamp,
           c.customer_zip_code_prefix,
           c.customer_city,
           c.customer_state,
           ROW_NUMBER() OVER(
               PARTITION BY c.customer_unique_id
               ORDER BY o.order_purchase_timestamp DESC,o.order_id DESC
               ) as rn
    FROM olist_staging.stg_orders as o
    LEFT JOIN olist_staging.stg_customers as c
    on o.customer_id = c.customer_id)

SELECT
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
FROM customer_rank
WHERE rn=1