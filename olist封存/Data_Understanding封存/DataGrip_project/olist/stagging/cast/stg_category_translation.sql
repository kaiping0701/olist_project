CREATE TABLE IF NOT EXISTS olist_staging.stg_category_translation AS
SELECT
    product_category_name,
    product_category_name_english

FROM olist_raw.category_translation;