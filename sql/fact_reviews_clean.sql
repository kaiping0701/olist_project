	DROP TABLE IF EXISTS fact_reviews_clean;

	CREATE TABLE fact_reviews_clean AS
	SELECT
		r.review_id,
		r.order_id,

		-- 評分：只保留 1~5 分，轉成 TINYINT
		CAST(r.review_score AS SIGNED) AS review_score,

		r.review_comment_title,
		r.review_comment_message,

		-- 評價建立時間（支援 '-' 與 '/' 兩種格式）
		CASE
			WHEN r.review_creation_date LIKE '%-%' THEN
				STR_TO_DATE(r.review_creation_date, '%Y-%m-%d %H:%i')
			WHEN r.review_creation_date LIKE '%/%' THEN
				STR_TO_DATE(r.review_creation_date, '%Y/%c/%e %H:%i')
			ELSE NULL
		END AS review_creation_datetime,

		-- 平台回覆時間
		CASE
			WHEN r.review_answer_timestamp LIKE '%-%' THEN
				STR_TO_DATE(r.review_answer_timestamp, '%Y-%m-%d %H:%i')
			WHEN r.review_answer_timestamp LIKE '%/%' THEN
				STR_TO_DATE(r.review_answer_timestamp, '%Y/%c/%e %H:%i')
			ELSE NULL
		END AS review_answer_datetime

	FROM
		olist_order_reviews_dataset AS r
	WHERE
		r.review_id IS NOT NULL AND r.review_id <> ''
		AND r.order_id IS NOT NULL AND r.order_id <> ''
		AND r.review_score IS NOT NULL AND r.review_score <> ''
		AND CAST(r.review_score AS SIGNED) BETWEEN 1 AND 5;
	;


ALTER TABLE fact_reviews_clean
    MODIFY COLUMN review_id CHAR(32) NOT NULL,
    MODIFY COLUMN order_id CHAR(32) NOT NULL,
    MODIFY COLUMN review_score TINYINT NOT NULL,
    -- 建索引就好，不設 PRIMARY KEY
    ADD INDEX idx_review_id (review_id),
    ADD INDEX idx_review_order (order_id),
    ADD INDEX idx_review_score (review_score);
