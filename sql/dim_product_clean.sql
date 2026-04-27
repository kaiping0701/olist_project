DROP TABLE IF EXISTS dim_product_clean;

CREATE TABLE dim_product_clean AS
SELECT
    p.product_id,

    -- 類別：無翻譯者設為 Unknown
    COALESCE(t.product_category_name_english, 'Unknown') AS category,

    -- 商品重量（純數字才轉，否則給 NULL）
    CASE 
        WHEN TRIM(p.product_weight_g) REGEXP '^[0-9]+$' 
        THEN CAST(TRIM(p.product_weight_g) AS DECIMAL(10,2))
        ELSE NULL
    END AS product_weight_g,

    CASE 
        WHEN TRIM(p.product_length_cm) REGEXP '^[0-9]+$' 
        THEN CAST(TRIM(p.product_length_cm) AS DECIMAL(10,2))
        ELSE NULL
    END AS product_length_cm,

    CASE 
        WHEN TRIM(p.product_height_cm) REGEXP '^[0-9]+$' 
        THEN CAST(TRIM(p.product_height_cm) AS DECIMAL(10,2))
        ELSE NULL
    END AS product_height_cm,

    CASE 
        WHEN TRIM(p.product_width_cm) REGEXP '^[0-9]+$' 
        THEN CAST(TRIM(p.product_width_cm) AS DECIMAL(10,2))
        ELSE NULL
    END AS product_width_cm

FROM
    olist_products_dataset AS p
LEFT JOIN
    product_category_name_translation AS t
    ON p.product_category_name = t.product_category_name

WHERE
    p.product_id IS NOT NULL AND p.product_id <> '';
;
