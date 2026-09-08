/* =========================================================
   dq_fk_check.sql
   目的：
   檢查 Olist staging tables 的 FK 是否能對應到父表 PK
   ========================================================= */

USE olist_staging;

SELECT
    'stg_orders' AS child_table,
    'customer_id' AS fk_column,
    'stg_customers' AS parent_table,
    'customer_id' AS parent_column,
    COUNT(*) AS child_row_count,
    SUM(c.customer_id IS NULL) AS missing_fk_count
FROM stg_orders o
LEFT JOIN stg_customers c
    ON o.customer_id = c.customer_id

UNION ALL

SELECT
    'stg_order_items',
    'order_id',
    'stg_orders',
    'order_id',
    COUNT(*),
    SUM(o.order_id IS NULL)
FROM stg_order_items oi
LEFT JOIN stg_orders o
    ON oi.order_id = o.order_id

UNION ALL

SELECT
    'stg_order_items',
    'product_id',
    'stg_products',
    'product_id',
    COUNT(*),
    SUM(p.product_id IS NULL)
FROM stg_order_items oi
LEFT JOIN stg_products p
    ON oi.product_id = p.product_id

UNION ALL

SELECT
    'stg_order_items',
    'seller_id',
    'stg_sellers',
    'seller_id',
    COUNT(*),
    SUM(s.seller_id IS NULL)
FROM stg_order_items oi
LEFT JOIN stg_sellers s
    ON oi.seller_id = s.seller_id

UNION ALL

SELECT
    'stg_payments',
    'order_id',
    'stg_orders',
    'order_id',
    COUNT(*),
    SUM(o.order_id IS NULL)
FROM stg_payments pay
LEFT JOIN stg_orders o
    ON pay.order_id = o.order_id

UNION ALL

SELECT
    'stg_reviews',
    'order_id',
    'stg_orders',
    'order_id',
    COUNT(*),
    SUM(o.order_id IS NULL)
FROM stg_reviews r
LEFT JOIN stg_orders o
    ON r.order_id = o.order_id

UNION ALL

SELECT
    'stg_products',
    'product_category_name',
    'stg_category_translation',
    'product_category_name',
    COUNT(*),
    SUM(t.product_category_name IS NULL AND p.product_category_name IS NOT NULL)
FROM stg_products p
LEFT JOIN stg_category_translation t
    ON p.product_category_name = t.product_category_name;