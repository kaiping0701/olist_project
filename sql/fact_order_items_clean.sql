DROP TABLE IF EXISTS fact_order_items_clean;

CREATE TABLE fact_order_items_clean AS
SELECT
    -- 主鍵組合
    o.order_id,
    CAST(oi.order_item_id AS UNSIGNED) AS order_item_id,
    
    -- 顧客資訊（之後要 join dim_customer）
    o.customer_id,
    
    -- ❗ 購買時間：支援 '-' 和 '/' 兩種格式
    CASE
        WHEN o.order_purchase_timestamp LIKE '%-%' THEN
            STR_TO_DATE(o.order_purchase_timestamp, '%Y-%m-%d %H:%i')
        WHEN o.order_purchase_timestamp LIKE '%/%' THEN
            STR_TO_DATE(o.order_purchase_timestamp, '%Y/%c/%e %H:%i')
        ELSE NULLw
    END AS order_purchase_timestamp,

    -- ❗ 實際送達時間
    CASE
        WHEN o.order_delivered_customer_date = '' OR o.order_delivered_customer_date IS NULL THEN
            NULL
        WHEN o.order_delivered_customer_date LIKE '%-%' THEN
            STR_TO_DATE(o.order_delivered_customer_date, '%Y-%m-%d %H:%i')
        WHEN o.order_delivered_customer_date LIKE '%/%' THEN
            STR_TO_DATE(o.order_delivered_customer_date, '%Y/%c/%e %H:%i')
        ELSE NULL
    END AS order_delivered_customer_date,

    -- ❗ 預估送達時間
    CASE
        WHEN o.order_estimated_delivery_date = '' OR o.order_estimated_delivery_date IS NULL THEN
            NULL
        WHEN o.order_estimated_delivery_date LIKE '%-%' THEN
            STR_TO_DATE(o.order_estimated_delivery_date, '%Y-%m-%d %H:%i')
        WHEN o.order_estimated_delivery_date LIKE '%/%' THEN
            STR_TO_DATE(o.order_estimated_delivery_date, '%Y/%c/%e %H:%i')
        ELSE NULL
    END AS order_estimated_delivery_date,

    -- 物流延遲（用上面已經轉好的 datetime 再算）
    CASE
        WHEN 
            (o.order_delivered_customer_date <> '' AND o.order_delivered_customer_date IS NOT NULL) AND
            (o.order_estimated_delivery_date <> '' AND o.order_estimated_delivery_date IS NOT NULL)
        THEN DATEDIFF(
            CASE
                WHEN o.order_delivered_customer_date LIKE '%-%' THEN
                    STR_TO_DATE(o.order_delivered_customer_date, '%Y-%m-%d %H:%i')
                WHEN o.order_delivered_customer_date LIKE '%/%' THEN
                    STR_TO_DATE(o.order_delivered_customer_date, '%Y/%c/%e %H:%i')
                ELSE NULL
            END,
            CASE
                WHEN o.order_estimated_delivery_date LIKE '%-%' THEN
                    STR_TO_DATE(o.order_estimated_delivery_date, '%Y-%m-%d %H:%i')
                WHEN o.order_estimated_delivery_date LIKE '%/%' THEN
                    STR_TO_DATE(o.order_estimated_delivery_date, '%Y/%c/%e %H:%i')
                ELSE NULL
            END
        )
        ELSE NULL
    END AS delivery_delay_days,

    CASE
        WHEN 
            (o.order_delivered_customer_date <> '' AND o.order_delivered_customer_date IS NOT NULL) AND
            (o.order_estimated_delivery_date <> '' AND o.order_estimated_delivery_date IS NOT NULL) AND
            (
                CASE
                    WHEN o.order_delivered_customer_date LIKE '%-%' THEN
                        STR_TO_DATE(o.order_delivered_customer_date, '%Y-%m-%d %H:%i')
                    WHEN o.order_delivered_customer_date LIKE '%/%' THEN
                        STR_TO_DATE(o.order_delivered_customer_date, '%Y/%c/%e %H:%i')
                    ELSE NULL
                END
                >
                CASE
                    WHEN o.order_estimated_delivery_date LIKE '%-%' THEN
                        STR_TO_DATE(o.order_estimated_delivery_date, '%Y-%m-%d %H:%i')
                    WHEN o.order_estimated_delivery_date LIKE '%/%' THEN
                        STR_TO_DATE(o.order_estimated_delivery_date, '%Y/%c/%e %H:%i')
                    ELSE NULL
                END
            )
        THEN 1 ELSE 0
    END AS is_delivered_late,

    -- 商品欄位
    oi.product_id,
    oi.seller_id,
    
    -- 金額欄位：TEXT → DECIMAL，先把空字串轉成 NULL，再 CAST
    CAST(NULLIF(oi.price,'') AS DECIMAL(10,2)) AS price,
    CAST(NULLIF(oi.freight_value,'') AS DECIMAL(10,2)) AS freight_value,
    
    -- 金額衍生：單筆商品行收入
    (CAST(NULLIF(oi.price,'') AS DECIMAL(10,2)) +
     CAST(NULLIF(oi.freight_value,'') AS DECIMAL(10,2))
    ) AS line_total

FROM
    olist_order_items_dataset AS oi
JOIN
    olist_orders_dataset AS o
    ON oi.order_id = o.order_id

WHERE
    -- 只保留已完成訂單
    o.order_status = 'delivered'
    
    -- 主鍵 & 必要欄位不可缺失 / 空字串
    AND o.order_id IS NOT NULL AND o.order_id <> ''
    AND oi.order_item_id IS NOT NULL AND oi.order_item_id <> ''
    AND oi.product_id IS NOT NULL AND oi.product_id <> ''
    
    -- price / freight_value 必須是非負數
    AND NULLIF(oi.price,'') IS NOT NULL
    AND NULLIF(oi.freight_value,'') IS NOT NULL
    AND CAST(NULLIF(oi.price,'') AS DECIMAL(10,2)) >= 0
    AND CAST(NULLIF(oi.freight_value,'') AS DECIMAL(10,2)) >= 0;
