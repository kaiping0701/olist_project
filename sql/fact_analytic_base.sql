DROP TABLE IF EXISTS fact_analytic_base;

CREATE TABLE fact_analytic_base AS
SELECT
    -- 訂單 × 商品 基本欄位（來自 fact_order_items_clean）
    f.order_id,
    f.order_item_id,
    f.customer_id,
    f.product_id,
    f.seller_id,

    -- 時間與物流
    f.order_purchase_timestamp,
    f.order_delivered_customer_date,
    f.order_estimated_delivery_date,
    f.delivery_delay_days,
    f.is_delivered_late,

    -- 金額
    f.price,
    f.freight_value,
    f.line_total,

    -- 顧客維度
    dc.customer_unique_id,
    dc.customer_city,
    dc.customer_state,
    dc.customer_zip_code_prefix,

    -- 商品維度
    COALESCE(dp.category, 'Unknown') AS category,
    dp.product_weight_g,
    dp.product_length_cm,
    dp.product_height_cm,
    dp.product_width_cm,

    -- 評價（允許沒有評價，LEFT JOIN）
    fr.review_score,
    fr.review_creation_datetime,
    fr.review_answer_datetime,
    fr.review_comment_title,
    fr.review_comment_message,
    CASE WHEN fr.review_score IS NOT NULL THEN 1 ELSE 0 END AS has_review,
    CASE WHEN fr.review_comment_message IS NOT NULL THEN 1 ELSE 0 END AS has_comment

FROM
    fact_order_items_clean AS f
JOIN
    dim_customer_clean AS dc
    ON f.customer_id = dc.customer_id
LEFT JOIN
    dim_product_clean AS dp
    ON f.product_id = dp.product_id
LEFT JOIN
    fact_reviews_clean AS fr
    ON f.order_id = fr.order_id;
;
