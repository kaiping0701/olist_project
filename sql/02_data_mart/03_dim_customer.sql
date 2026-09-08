
DROP TABLE IF EXISTS olist_data_mart.dim_customer;

CREATE TABLE olist_data_mart.dim_customer(
    customer_key INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_unique_id VARCHAR(50) NOT NULL UNIQUE
);

INSERT INTO olist_data_mart.dim_customer
(
    customer_unique_id
)
SELECT DISTINCT
    customer_unique_id
FROM olist_staging.stg_customers;