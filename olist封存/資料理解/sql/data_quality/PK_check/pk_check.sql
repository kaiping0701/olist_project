USE olist_staging;
SELECT
    'stg_category_translation' AS table_name,
    'product_category_name' AS pk_column,
    COUNT(*) AS row_count,
    COUNT(DISTINCT product_category_name) AS distinct_count

FROM stg_category_translation

UNION ALL

SELECT
    'stg_customers',
    'customer_id',
    COUNT(*),
    COUNT(DISTINCT customer_id)

FROM stg_customers

UNION ALL

SELECT
    'stg_order_items',
    'order_id + order_item_id',
    COUNT(*),
    COUNT(DISTINCT CONCAT(order_id,'_',order_item_id))

FROM stg_order_items

UNION ALL

SELECT
    'stg_orders',
    'order_id',
    COUNT(*),
    COUNT(DISTINCT order_id)

FROM stg_orders

UNION ALL

SELECT
    'stg_payments',
    'order_id + payment_sequential',
    COUNT(*),
    COUNT(DISTINCT CONCAT(order_id,'_',payment_sequential))

FROM stg_payments

UNION ALL

SELECT
    'stg_products',
    'product_id',
    COUNT(*),
    COUNT(DISTINCT product_id)

FROM stg_products

UNION ALL

SELECT
    'stg_reviews',
    'review_id',
    COUNT(*),
    COUNT(DISTINCT review_id)

FROM stg_reviews

UNION ALL

SELECT
    'stg_sellers',
    'seller_id',
    COUNT(*),
    COUNT(DISTINCT seller_id)

FROM stg_sellers;