CREATE OR REPLACE VIEW olist_data_mart.vw_review_ai AS
        SELECT
            r.review_id,
            r.order_id,
            r.review_score,
            NULLIF(TRIM(ai.review_comment_title_message), '') AS review_comment_title_message,
            NULLIF(TRIM(ai.review_translation_tw), '') AS review_translation_tw,
            r.review_creation_date,
            r.review_answer_timestamp,
            ai.sentiment,
            ai.t01_delivery_logistics,
            ai.t02_order_fulfillment,
            ai.t03_product_quality,
            ai.t04_product_consistency,
            ai.t05_packaging_protection,
            ai.t06_customer_service,
            ai.t07_price_transaction,
            ai.t08_platform_system
        FROM olist_staging.stg_reviews as r
        LEFT JOIN olist_data_mart.int_ai_annotation as ai
        ON r.review_id = ai.review_id
        AND r.order_id = ai.order_id
