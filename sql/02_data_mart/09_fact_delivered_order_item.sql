DROP TABLE IF EXISTS olist_data_mart.fact_delivered_order_item;

CREATE TABLE olist_data_mart.fact_delivered_order_item(
    order_item_key INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    order_id VARCHAR(50) NOT NULL,
    order_event_key INT UNSIGNED NOT NULL,
    order_item_id INT NOT NULL,
    product_key INT UNSIGNED NOT NULL,
    seller_key INT UNSIGNED NOT NULL,
    shipping_limit_date DATETIME NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    freight_value DECIMAL(10,2) NOT NULL,
    CONSTRAINT check_order_item_price
        CHECK(price>=0),
    CONSTRAINT check_order_item_freight_value
        CHECK(freight_value>=0),
    # 設定(order_id,order_item)組合必須唯一
    CONSTRAINT unique_order_id_order_item_id
        UNIQUE(order_id,order_item_id),
    # 把order_event_key 當成外鍵連map表
    CONSTRAINT fk_order_id
        FOREIGN KEY(order_id)
        REFERENCES olist_data_mart.map_delivered_order_to_event(order_id),
    # seller_key 和 product_key建立FK
    CONSTRAINT fk_seller_key
        FOREIGN KEY(seller_key)
        REFERENCES olist_data_mart.dim_seller(seller_key),

    CONSTRAINT fk_product_key
        FOREIGN KEY (product_key)
        REFERENCES olist_data_mart.dim_product(product_key)

);

INSERT INTO olist_data_mart.fact_delivered_order_item (
    order_id,
    order_event_key,
    order_item_id,
    product_key,
    seller_key,
    shipping_limit_date,
    price,
    freight_value
)

SELECT
    oi.order_id,
    map.order_event_key,
    oi.order_item_id,
    dim_p.product_key,
    dim_s.seller_key,
    oi.shipping_limit_date,
    oi.price,
    oi.freight_value

FROM olist_staging.stg_order_items as oi
INNER JOIN olist_data_mart.map_delivered_order_to_event as map
ON oi.order_id = map.order_id
LEFT JOIN olist_data_mart.dim_seller as dim_s
ON oi.seller_id = dim_s.seller_id
LEFT JOIN olist_data_mart.dim_product as dim_p
ON oi.product_id = dim_p.product_id
