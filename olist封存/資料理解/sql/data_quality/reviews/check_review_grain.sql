# 檢查 review表grain是否(order_id+review_id)
# review_grain (review_id  , order_id )
SELECT
    review_id,
    order_id,
    COUNT(*) AS row_count
FROM olist_staging.stg_reviews
GROUP BY
    review_id,
    order_id
HAVING COUNT(*) > 1;