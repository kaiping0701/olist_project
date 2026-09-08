CREATE TABLE IF NOT EXISTS olist_staging.stg_customers AS
SELECT *
FROM olist_raw.customers;