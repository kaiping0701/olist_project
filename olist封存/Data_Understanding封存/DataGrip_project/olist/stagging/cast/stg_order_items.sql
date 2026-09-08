CREATE TABLE IF NOT EXISTS stg_order_items AS
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    STR_TO_DATE(
        shipping_limit_date,
        '%Y-%m-%d %H:%i:%s'
    ) AS shipping_limit_date,
    CAST(price AS DECIMAL(10,2)) as price,
    CAST(freight_value AS DECIMAL(10,2)) as freight_value
FROM olist_raw.order_items
