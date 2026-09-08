CREATE OR REPLACE VIEW olist_data_mart.vw_delivered_order_review_agg AS

    SELECT
        rai.order_id,
        count(rai.review_id) AS cnt_review,
        AVG(rai.review_score) AS mean_review_score,
        SUM(rai.review_score) AS sum_review_score,

        MAX(
            CASE
                WHEN rai.review_score <=3 THEN 1
                ELSE 0
                END
        ) as has_low_review,

        MAX(
        CASE
            WHEN NULLIF(TRIM(rai.review_comment_title_message), '') IS NULL
            THEN 0
        ELSE 1
        END
            ) AS has_comment,
        COALESCE(
        MAX(
        CHAR_LENGTH(
            NULLIF(
                TRIM(rai.review_comment_title_message),'')
                )
                ),
        0
            ) AS max_review_comment_length,

        MAX(
            CASE
                WHEN rai.sentiment = 'positive' THEN 1
                ELSE 0
            END
        ) has_positive,

        MAX(
            CASE
                WHEN rai.sentiment = 'negative' THEN 1
                ELSE 0
            END
        ) has_negative,

        MAX(
            CASE
                WHEN rai.sentiment = 'mixed' THEN 1
                ELSE 0
            END
        ) has_mixed,

        MAX(
            CASE
                WHEN rai.sentiment = 'neutral' THEN 1
                ELSE 0
            END
        ) has_neutral,


        MAX(COALESCE(rai.t01_delivery_logistics, 0))
            AS has_t01_delivery_logistics,

        MAX(COALESCE(rai.t02_order_fulfillment, 0))
            AS has_t02_order_fulfillment,

        MAX(COALESCE(rai.t03_product_quality, 0))
            AS has_t03_product_quality,

        MAX(COALESCE(rai.t04_product_consistency, 0))
            AS has_t04_product_consistency,

        MAX(COALESCE(rai.t05_packaging_protection, 0))
            AS has_t05_packaging_protection,

        MAX(COALESCE(rai.t06_customer_service, 0))
            AS has_t06_customer_service,

        MAX(COALESCE(rai.t07_price_transaction, 0))
            AS has_t07_price_transaction,

        MAX(COALESCE(rai.t08_platform_system, 0))
            AS has_t08_platform_system,

        MIN(rai.review_creation_date) AS first_review_creation_date,
        MAX(rai.review_answer_timestamp) AS last_review_answer_timestamp

    FROM olist_data_mart.vw_review_ai as rai
    INNER JOIN olist_data_mart.map_delivered_order_to_event as map
    ON rai.order_id = map.order_id
    GROUP BY rai.order_id
