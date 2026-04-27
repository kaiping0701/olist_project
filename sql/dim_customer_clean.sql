DROP TABLE IF EXISTS dim_customer_clean;

CREATE TABLE dim_customer_clean AS
SELECT
    -- 主鍵
    c.customer_id,
    c.customer_unique_id,
    
    -- 郵遞區前綴：空字串視為 NULL，其餘轉成 INT
    CASE
        WHEN c.customer_zip_code_prefix IS NULL OR c.customer_zip_code_prefix = '' THEN NULL
        ELSE CAST(c.customer_zip_code_prefix AS UNSIGNED)
    END AS customer_zip_code_prefix,
    
    c.customer_city,
    c.customer_state
FROM
    olist_customers_dataset AS c
WHERE
    c.customer_id IS NOT NULL AND c.customer_id <> ''
    AND c.customer_unique_id IS NOT NULL AND c.customer_unique_id <> '';
;

-- 收緊 schema + 索引
ALTER TABLE dim_customer_clean
    MODIFY COLUMN customer_id CHAR(32) NOT NULL,
    MODIFY COLUMN customer_unique_id CHAR(32) NOT NULL,
    ADD PRIMARY KEY (customer_id),
    ADD INDEX idx_customer_unique (customer_unique_id),
    ADD INDEX idx_customer_state (customer_state);
