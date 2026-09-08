DROP TABLE IF EXISTS olist_data_mart.dim_product;

CREATE TABLE olist_data_mart.dim_product (
    product_key INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id VARCHAR(50) NOT NULL UNIQUE,

    product_category_name_original VARCHAR(255) NOT NULL,
    product_category_name_english VARCHAR(255) NOT NULL,

    product_name_length INT UNSIGNED,
    product_description_length INT UNSIGNED,
    product_photos_qty INT UNSIGNED,

    product_weight_g INT UNSIGNED,
    product_length_cm INT UNSIGNED,
    product_height_cm INT UNSIGNED,
    product_width_cm INT UNSIGNED
);

INSERT INTO olist_data_mart.dim_product (
    product_id,
    product_category_name_original,
    product_category_name_english,

    product_name_length,
    product_description_length,
    product_photos_qty,

    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)

/*
    產品表中有 610 個產品：
    product_category_name 本身為 NULL。

    產品表中有 13 個產品：
    product_category_name 有值，
    但 translation table 沒有對應資料。

    這 13 個產品屬於兩個缺失品類：
    1. pc_gamer
    2. portateis_cozinha_e_preparadores_de_alimentos
*/

WITH manual_translation AS (
    SELECT
        'pc_gamer' AS product_category_name,
        'pc_gamer' AS product_category_name_english

    UNION ALL

    SELECT
        'portateis_cozinha_e_preparadores_de_alimentos',
        'portable_kitchen_and_food_preparation_appliances'
),

complete_translation AS (
    SELECT
        product_category_name,
        product_category_name_english
    FROM olist_staging.stg_category_translation

    UNION ALL

    SELECT
        product_category_name,
        product_category_name_english
    FROM manual_translation
),

product_transformed AS (
    SELECT
        p.product_id,

        COALESCE(
            p.product_category_name,
            'unknown'
        ) AS product_category_name_original,

        COALESCE(
            t.product_category_name_english,
            'unknown'
        ) AS product_category_name_english,

        p.product_name_lenght AS product_name_length,
        p.product_description_lenght AS product_description_length,
        p.product_photos_qty,

        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm

    FROM olist_staging.stg_products AS p
    LEFT JOIN complete_translation AS t
        ON p.product_category_name = t.product_category_name
)

SELECT
    product_id,
    product_category_name_original,
    product_category_name_english,

    product_name_length,
    product_description_length,
    product_photos_qty,

    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm

FROM product_transformed;