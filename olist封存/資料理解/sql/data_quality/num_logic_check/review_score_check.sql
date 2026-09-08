USE olist_staging;

SELECT
    'stg_reviews' AS table_name,
    'review_score_not_between_1_and_5' AS check_name,
    COUNT(*) AS row_count,
    SUM(review_score < 1 OR review_score > 5) AS issue_count
FROM stg_reviews;