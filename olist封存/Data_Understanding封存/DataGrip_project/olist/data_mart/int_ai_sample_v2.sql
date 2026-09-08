DROP TABLE IF EXISTS olist_data_mart.int_ai_sample_v2;

CREATE TABLE olist_data_mart.int_ai_sample_v2 (

    review_id VARCHAR(50) NOT NULL,
    order_id VARCHAR(50) NOT NULL,

    review_score TINYINT NOT NULL,

    review_comment_title_message TEXT,
    review_translation_tw TEXT,

    sentiment VARCHAR(20),

    t01_delivery_logistics TINYINT(1) NOT NULL DEFAULT 0,
    t02_order_fulfillment TINYINT(1) NOT NULL DEFAULT 0,
    t03_product_quality TINYINT(1) NOT NULL DEFAULT 0,
    t04_product_consistency TINYINT(1) NOT NULL DEFAULT 0,
    t05_packaging_protection TINYINT(1) NOT NULL DEFAULT 0,
    t06_customer_service TINYINT(1) NOT NULL DEFAULT 0,
    t07_price_transaction TINYINT(1) NOT NULL DEFAULT 0,
    t08_platform_system TINYINT(1) NOT NULL DEFAULT 0,

    PRIMARY KEY (review_id, order_id)
);