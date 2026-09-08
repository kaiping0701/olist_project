/*
    產品表610 個產品：
    product_category_name 本身為 NULL

    產品表13 個產品：
    product_category_name 有值
    但 translation table 沒有對應資料

    13 個產品所屬的缺失品類只有 2 種：
    pc_gamer
    portateis_cozinha_e_preparadores_de_alimentos
 */

SELECT SUM( p.product_category_name IS NULL ) AS original_category_null_rows,
       SUM( p.product_category_name IS NOT NULL AND t.product_category_name IS NULL ) AS missing_translation_rows,
       COUNT( DISTINCT CASE WHEN p.product_category_name IS NOT NULL
                                     AND t.product_category_name IS NULL
           THEN p.product_category_name END ) AS missing_translation_category_count
FROM olist_staging.stg_products AS p
    LEFT JOIN olist_staging.stg_category_translation AS t
        ON p.product_category_name = t.product_category_name;