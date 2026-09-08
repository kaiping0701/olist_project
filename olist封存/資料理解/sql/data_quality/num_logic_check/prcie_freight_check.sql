USE olist_staging;

SELECT
    'stg_order_items' AS table_name,
    'negative_price' AS check_name,
    COUNT(*) AS row_count,
    SUM(price < 0) AS issue_count
FROM stg_order_items

UNION ALL

SELECT
    'stg_order_items',
    'negative_freight_value',
    COUNT(*),
    SUM(freight_value < 0)
FROM stg_order_items

UNION ALL

SELECT
    'stg_order_items',
    'price_over_80000',
    COUNT(*),
    SUM(price > 80000)
FROM stg_order_items

UNION ALL

SELECT
    'stg_order_items',
    'freight_over_12000',
    COUNT(*),
    SUM(freight_value > 12000)
FROM stg_order_items;