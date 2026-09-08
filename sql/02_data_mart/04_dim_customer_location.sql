DROP TABLE IF EXISTS olist_data_mart.dim_customer_location;

CREATE TABLE olist_data_mart.dim_customer_location(
    customer_location_key INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_zip_code_prefix INT UNSIGNED NOT NULL,
    customer_city VARCHAR(100) NOT NULL,
    customer_state CHAR(2) NOT NULL,


    CONSTRAINT uq_customer_location
        UNIQUE(
            customer_zip_code_prefix,
            customer_city,
            customer_state
            )
);

INSERT INTO olist_data_mart.dim_customer_location(
    customer_zip_code_prefix,
    customer_city,
    customer_state
)

SELECT DISTINCT
    customer_zip_code_prefix,
    customer_city,
    customer_state
FROM olist_staging.stg_customers
ORDER BY customer_state ASC,
         customer_city ASC,
         customer_zip_code_prefix ASC;