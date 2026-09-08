
(
    SELECT
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message
    FROM olist_staging.stg_reviews
    WHERE review_score = 1 AND review_comment_message IS NOT NULL
    ORDER BY RAND()
    LIMIT 5
)

UNION ALL

(
    SELECT
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message
    FROM olist_staging.stg_reviews
    WHERE review_score = 2 AND review_comment_message IS NOT NULL
    ORDER BY RAND()
    LIMIT 5
)

UNION ALL

(
    SELECT
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message
    FROM olist_staging.stg_reviews
    WHERE review_score = 3 AND review_comment_message IS NOT NULL
    ORDER BY RAND()
    LIMIT 5
)

UNION ALL

(
    SELECT
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message
    FROM olist_staging.stg_reviews
    WHERE review_score = 4 AND review_comment_message IS NOT NULL
    ORDER BY RAND()
    LIMIT 5
)

UNION ALL

(
    SELECT
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message
    FROM olist_staging.stg_reviews
    WHERE review_score = 5 AND review_comment_message IS NOT NULL
    ORDER BY RAND()
    LIMIT 5
);