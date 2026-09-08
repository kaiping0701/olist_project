CREATE TABLE IF NOT EXISTS olist_staging.stg_products AS
SELECT
    product_id,
    product_category_name,

    CAST(product_name_lenght AS UNSIGNED) AS product_name_lenght,

    CAST(product_description_lenght AS UNSIGNED) AS product_description_lenght,

    CAST(product_photos_qty AS UNSIGNED) AS product_photos_qty,

    CAST(product_weight_g AS UNSIGNED) AS product_weight_g,

    CAST(product_length_cm AS UNSIGNED) AS product_length_cm,

    CAST(product_height_cm AS UNSIGNED) AS product_height_cm,

    CAST(product_width_cm AS UNSIGNED) AS product_width_cm

FROM olist_raw.products;