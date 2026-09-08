# 檢查 reivew_id複製的 除order_id以外欄位資訊是否相同？
# 結論：dup review_id 除order_id 以外欄位資訊都相同

WITH duplicated_reviews AS (
    SELECT *
    FROM (
        SELECT
            *,
            COUNT(*) OVER (
                PARTITION BY review_id
            ) AS review_cnt
        FROM olist_staging.stg_reviews
    ) AS t
    WHERE review_cnt > 1
)

SELECT
    review_id,
    COUNT(DISTINCT COALESCE(CAST(review_score AS CHAR), '<NULL>'))
        AS score_value_count,

    COUNT(DISTINCT COALESCE(review_comment_title, '<NULL>'))
        AS title_value_count,

    COUNT(DISTINCT COALESCE(review_comment_message, '<NULL>'))
        AS message_value_count,

    COUNT(DISTINCT COALESCE(CAST(review_creation_date AS CHAR), '<NULL>'))
        AS creation_date_value_count,

    COUNT(DISTINCT COALESCE(CAST(review_answer_timestamp AS CHAR), '<NULL>'))
        AS answer_timestamp_value_count

FROM duplicated_reviews
GROUP BY review_id
HAVING
       score_value_count > 1
    OR title_value_count > 1
    OR message_value_count > 1
    OR creation_date_value_count > 1
    OR answer_timestamp_value_count > 1;