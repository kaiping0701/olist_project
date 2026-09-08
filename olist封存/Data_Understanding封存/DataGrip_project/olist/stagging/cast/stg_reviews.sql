CREATE TABLE IF NOT EXISTS olist_staging.stg_reviews AS
SELECT
    review_id,
    order_id,

    CAST(review_score AS UNSIGNED) AS review_score,

    review_comment_title,
    review_comment_message,

    STR_TO_DATE(
        review_creation_date,
        '%Y-%m-%d %H:%i:%s'
    ) AS review_creation_date,

    STR_TO_DATE(
        review_answer_timestamp,
        '%Y-%m-%d %H:%i:%s'
    ) AS review_answer_timestamp

FROM olist_raw.reviews;