DROP TABLE IF EXISTS olist_data_mart.dim_seller;

CREATE TABLE olist_data_mart.dim_seller(
    seller_key INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    seller_id VARCHAR(50) NOT NULL UNIQUE,
    seller_city VARCHAR(100) NOT NULL,
    seller_state CHAR(2) NOT NULL,
    seller_zip_code_prefix INT NOT NULL
);

INSERT INTO olist_data_mart.dim_seller(
    seller_id,
    seller_city,
    seller_state,
    seller_zip_code_prefix
)

SELECT
    seller_id,
    seller_city,
    seller_state,
    seller_zip_code_prefix
FROM olist_staging.stg_sellers;