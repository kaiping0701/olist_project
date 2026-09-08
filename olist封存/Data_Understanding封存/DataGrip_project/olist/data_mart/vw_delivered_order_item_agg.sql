# 建構 vw_order_item 把 fact delivered order item 壓縮到order level


CREATE OR REPLACE VIEW olist_data_mart.vw_delivered_order_item_agg AS

    WITH order_item_seller_product AS(
        SELECT
            fact_oi.order_id,
            fact_oi.order_item_id,
            fact_oi.price,
            fact_oi.freight_value,
            fact_oi.product_key,
            dim_p.product_category_name_english,
            dim_p.product_name_length,
            dim_p.product_description_length,
            dim_p.product_photos_qty,
            dim_p.product_weight_g,
            dim_p.product_length_cm,
            dim_p.product_height_cm,
            dim_p.product_width_cm,
            fact_oi.seller_key,
            dim_s.seller_city,
            dim_s.seller_state,
            dim_s.seller_zip_code_prefix

        FROM olist_data_mart.fact_delivered_order_item as fact_oi
        INNER JOIN olist_data_mart.dim_seller  as dim_s
        ON fact_oi.seller_key = dim_s.seller_key
        INNER JOIN olist_data_mart.dim_product as dim_p
        ON fact_oi.product_key = dim_p.product_key
        )
    -- 壓縮成order-level
    SELECT
        order_id,
        COUNT(order_item_id) AS cnt_item,
        COUNT(DISTINCT product_key) AS cnt_distinct_product,
        COUNT(DISTINCT product_category_name_english) AS cnt_distinct_category,
        COUNT(DISTINCT Seller_key) as cnt_distinct_seller,
        SUM(price) as sum_order_price,
        SUM(freight_value) as sum_order_freight_value,
        SUM(price+freight_value) as order_total_value,
        ROUND(AVG(price),2) as mean_item_price,
        MAX(price) as max_item_price,
        MIN(price) as min_item_price

    FROM order_item_seller_product
    GROUP BY order_id
