/*
    Olist Data Mart Validation

    執行時機：所有 dimension、map、fact 建構完成後。
    使用方式：在 DataGrip 直接執行整份檔案。

    判定方式：
    1. 正式測試結果的 status 應全部為 PASS。
    2. violation_count 應全部為 0。
    3. 最後的 profile 為人工合理性檢查，不以固定門檻判定。

    本檔案全部為唯讀查詢，不會修改 Data Mart。
*/


/* =========================================================
   0. 執行環境
   ========================================================= */

SELECT
    'foreign_key_checks_enabled' AS test_name,
    1 AS expected_value,
    @@SESSION.foreign_key_checks AS actual_value,
    CASE
        WHEN @@SESSION.foreign_key_checks = 1 THEN 'PASS'
        ELSE 'FAIL'
    END AS status;


/* =========================================================
   1. Grain / Business Key 唯一性
   ========================================================= */

WITH grain_check AS (
    SELECT
        'dim_customer_customer_unique_id' AS test_name,
        COUNT(*) AS row_count,
        COUNT(DISTINCT customer_unique_id) AS grain_count
    FROM olist_data_mart.dim_customer

    UNION ALL

    SELECT
        'dim_date_full_date',
        COUNT(*),
        COUNT(DISTINCT full_date)
    FROM olist_data_mart.dim_date

    UNION ALL

    SELECT
        'dim_product_product_id',
        COUNT(*),
        COUNT(DISTINCT product_id)
    FROM olist_data_mart.dim_product

    UNION ALL

    SELECT
        'dim_seller_seller_id',
        COUNT(*),
        COUNT(DISTINCT seller_id)
    FROM olist_data_mart.dim_seller

    UNION ALL

    SELECT
        'map_one_row_per_order',
        COUNT(*),
        COUNT(DISTINCT order_id)
    FROM olist_data_mart.map_delivered_order_to_event

    UNION ALL

    SELECT
        'fact_item_one_row_per_order_item',
        COUNT(*),
        COUNT(DISTINCT order_id, order_item_id)
    FROM olist_data_mart.fact_delivered_order_item

    UNION ALL

    SELECT
        'fact_event_one_row_per_event',
        COUNT(*),
        COUNT(DISTINCT order_event_key)
    FROM olist_data_mart.fact_delivered_order_event
)
SELECT
    test_name,
    row_count,
    grain_count,
    row_count - grain_count AS violation_count,
    CASE
        WHEN row_count = grain_count THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM grain_check;


/* =========================================================
   2. Fact → Dimension / Map 關聯完整性
   ========================================================= */

WITH integrity_check AS (
    SELECT
        'fact_event_to_dim_customer' AS test_name,
        COALESCE(SUM(c.customer_key IS NULL), 0) AS violation_count
    FROM olist_data_mart.fact_delivered_order_event AS f
    LEFT JOIN olist_data_mart.dim_customer AS c
        ON f.customer_key = c.customer_key

    UNION ALL

    SELECT
        'fact_event_to_dim_date',
        COALESCE(SUM(d.date_key IS NULL), 0)
    FROM olist_data_mart.fact_delivered_order_event AS f
    LEFT JOIN olist_data_mart.dim_date AS d
        ON f.event_purchase_date_key = d.date_key

    UNION ALL

    SELECT
        'fact_item_to_map_order',
        COALESCE(SUM(m.order_id IS NULL), 0)
    FROM olist_data_mart.fact_delivered_order_item AS f
    LEFT JOIN olist_data_mart.map_delivered_order_to_event AS m
        ON f.order_id = m.order_id

    UNION ALL

    SELECT
        'fact_item_to_dim_product',
        COALESCE(SUM(p.product_key IS NULL), 0)
    FROM olist_data_mart.fact_delivered_order_item AS f
    LEFT JOIN olist_data_mart.dim_product AS p
        ON f.product_key = p.product_key

    UNION ALL

    SELECT
        'fact_item_to_dim_seller',
        COALESCE(SUM(s.seller_key IS NULL), 0)
    FROM olist_data_mart.fact_delivered_order_item AS f
    LEFT JOIN olist_data_mart.dim_seller AS s
        ON f.seller_key = s.seller_key
)
SELECT
    test_name,
    violation_count,
    CASE
        WHEN violation_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM integrity_check;


/* =========================================================
   3. Map → Event Fact 逐 Event 語意對帳
   ========================================================= */

WITH map_event AS (
    SELECT
        order_event_key,
        COUNT(*) AS order_count,
        MIN(order_purchase_timestamp) AS event_purchase_timestamp,
        MIN(customer_unique_id) AS customer_unique_id,
        COUNT(DISTINCT customer_unique_id) AS customer_count
    FROM olist_data_mart.map_delivered_order_to_event
    GROUP BY order_event_key
),
map_event_check AS (
    SELECT
        'map_event_missing_from_fact' AS test_name,
        COALESCE(SUM(f.order_event_key IS NULL), 0) AS violation_count
    FROM map_event AS m
    LEFT JOIN olist_data_mart.fact_delivered_order_event AS f
        ON m.order_event_key = f.order_event_key

    UNION ALL

    SELECT
        'fact_event_missing_from_map',
        COUNT(*)
    FROM olist_data_mart.fact_delivered_order_event AS f
    LEFT JOIN map_event AS m
        ON f.order_event_key = m.order_event_key
    WHERE m.order_event_key IS NULL

    UNION ALL

    SELECT
        'map_event_multiple_customers',
        COALESCE(SUM(customer_count <> 1), 0)
    FROM map_event

    UNION ALL

    SELECT
        'event_order_count_mismatch',
        COALESCE(SUM(f.cnt_event_order <> m.order_count), 0)
    FROM map_event AS m
    INNER JOIN olist_data_mart.fact_delivered_order_event AS f
        ON m.order_event_key = f.order_event_key

    UNION ALL

    SELECT
        'event_purchase_timestamp_mismatch',
        COALESCE(SUM(
            f.event_purchase_timestamp <> m.event_purchase_timestamp
        ), 0)
    FROM map_event AS m
    INNER JOIN olist_data_mart.fact_delivered_order_event AS f
        ON m.order_event_key = f.order_event_key

    UNION ALL

    SELECT
        'event_customer_mismatch',
        COALESCE(SUM(
            c.customer_unique_id <> m.customer_unique_id
        ), 0)
    FROM map_event AS m
    INNER JOIN olist_data_mart.fact_delivered_order_event AS f
        ON m.order_event_key = f.order_event_key
    INNER JOIN olist_data_mart.dim_customer AS c
        ON f.customer_key = c.customer_key
)
SELECT
    test_name,
    violation_count,
    CASE
        WHEN violation_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM map_event_check;


/* =========================================================
   4. Source / Lower-grain Fact → Event Fact 總量對帳
   ========================================================= */

WITH
map_total AS (
    SELECT
        COUNT(*) AS order_count,
        COUNT(DISTINCT order_event_key) AS event_count
    FROM olist_data_mart.map_delivered_order_to_event
),
item_total AS (
    SELECT
        COUNT(*) AS item_count,
        COALESCE(SUM(price), 0) AS price,
        COALESCE(SUM(freight_value), 0) AS freight
    FROM olist_data_mart.fact_delivered_order_item
),
payment_total AS (
    SELECT
        COUNT(*) AS payment_record_count,
        COALESCE(SUM(p.payment_value), 0) AS payment_value
    FROM olist_staging.stg_payments AS p
    INNER JOIN olist_data_mart.map_delivered_order_to_event AS m
        ON p.order_id = m.order_id
),
review_total AS (
    SELECT
        COUNT(*) AS review_count,
        COALESCE(SUM(r.review_score), 0) AS review_score
    FROM olist_staging.stg_reviews AS r
    INNER JOIN olist_data_mart.map_delivered_order_to_event AS m
        ON r.order_id = m.order_id
),
event_total AS (
    SELECT
        COUNT(*) AS event_count,
        COALESCE(SUM(cnt_event_order), 0) AS order_count,
        COALESCE(SUM(cnt_item), 0) AS item_count,
        COALESCE(SUM(sum_event_price), 0) AS price,
        COALESCE(SUM(sum_event_freight_value), 0) AS freight,
        COALESCE(SUM(cnt_payment_record), 0) AS payment_record_count,
        COALESCE(SUM(payment_value), 0) AS payment_value,
        COALESCE(SUM(cnt_review), 0) AS review_count,
        COALESCE(SUM(sum_review_score), 0) AS review_score
    FROM olist_data_mart.fact_delivered_order_event
),
reconciliation AS (
    SELECT
        'event_count' AS test_name,
        CAST(m.event_count AS DECIMAL(20,2)) AS source_value,
        CAST(e.event_count AS DECIMAL(20,2)) AS mart_value,
        CAST(0 AS DECIMAL(20,2)) AS tolerance
    FROM map_total AS m
    CROSS JOIN event_total AS e

    UNION ALL

    SELECT
        'order_count', m.order_count, e.order_count, 0
    FROM map_total AS m
    CROSS JOIN event_total AS e

    UNION ALL

    SELECT
        'item_count', i.item_count, e.item_count, 0
    FROM item_total AS i
    CROSS JOIN event_total AS e

    UNION ALL

    SELECT
        'item_price', i.price, e.price, 0.01
    FROM item_total AS i
    CROSS JOIN event_total AS e

    UNION ALL

    SELECT
        'item_freight', i.freight, e.freight, 0.01
    FROM item_total AS i
    CROSS JOIN event_total AS e

    UNION ALL

    SELECT
        'payment_record_count',
        p.payment_record_count,
        e.payment_record_count,
        0
    FROM payment_total AS p
    CROSS JOIN event_total AS e

    UNION ALL

    SELECT
        'payment_value', p.payment_value, e.payment_value, 0.01
    FROM payment_total AS p
    CROSS JOIN event_total AS e

    UNION ALL

    SELECT
        'review_count', r.review_count, e.review_count, 0
    FROM review_total AS r
    CROSS JOIN event_total AS e

    UNION ALL

    SELECT
        'review_score', r.review_score, e.review_score, 0
    FROM review_total AS r
    CROSS JOIN event_total AS e
)
SELECT
    test_name,
    source_value,
    mart_value,
    mart_value - source_value AS difference,
    CASE
        WHEN ABS(mart_value - source_value) <= tolerance THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM reconciliation;


/* =========================================================
   5. Event Fact 商業規則
   ========================================================= */

WITH rule_count AS (
    SELECT
        COALESCE(SUM(cnt_event_order < 1), 0)
            AS bad_event_order_count,

        COALESCE(SUM(
            cnt_late_order > cnt_event_order
            OR has_late_delivery <> IF(cnt_late_order > 0, 1, 0)
        ), 0) AS bad_late_delivery_logic,

        COALESCE(SUM(
            (cnt_late_order = 0 AND mean_delay_seconds <> 0)
            OR
            (cnt_late_order > 0 AND mean_delay_seconds <= 0)
        ), 0) AS bad_delay_logic,

        COALESCE(SUM(
            (
                cnt_review = 0
                AND (
                    has_review <> 0
                    OR mean_review_score IS NOT NULL
                    OR sum_review_score <> 0
                    OR first_review_creation_date IS NOT NULL
                    OR last_review_answer_timestamp IS NOT NULL
                )
            )
            OR
            (
                cnt_review > 0
                AND (
                    has_review <> 1
                    OR mean_review_score IS NULL
                    OR first_review_creation_date IS NULL
                    OR last_review_answer_timestamp IS NULL
                )
            )
        ), 0) AS bad_review_null_logic,

        COALESCE(SUM(
            cnt_review > 0
            AND (
                mean_review_score NOT BETWEEN 1 AND 5
                OR sum_review_score < cnt_review
                OR sum_review_score > cnt_review * 5
            )
        ), 0) AS bad_review_score_logic,

        COALESCE(SUM(
            cnt_distinct_payment_type <>
                (
                    has_credit_card
                    + has_boleto
                    + has_voucher
                    + has_debit_card
                    + has_not_defined
                )
            OR cnt_distinct_payment_type > cnt_payment_record
            OR cnt_distinct_payment_type > 5
            OR (
                cnt_payment_record = 0
                AND (
                    payment_value <> 0
                    OR max_payment_installments <> 0
                )
            )
            OR (
                cnt_payment_record > 0
                AND cnt_distinct_payment_type = 0
            )
        ), 0) AS bad_payment_logic,

        COALESCE(SUM(
            cnt_item < 1
            OR cnt_distinct_product < 1
            OR cnt_distinct_product > cnt_item
            OR cnt_distinct_product_category < 1
            OR cnt_distinct_product_category > cnt_distinct_product
            OR cnt_distinct_seller < 1
            OR cnt_distinct_seller > cnt_item
        ), 0) AS bad_item_logic,

        COALESCE(SUM(
            ABS(
                event_total_value
                - sum_event_price
                - sum_event_freight_value
            ) > 0.01
        ), 0) AS bad_event_total_value,

        COALESCE(SUM(
            event_total_value <= 0
            OR ABS(
                freight_ratio
                - ROUND(
                    sum_event_freight_value
                    / NULLIF(event_total_value, 0),
                    4
                )
            ) > 0.0001
        ), 0) AS bad_freight_ratio,

        COALESCE(SUM(
            ABS(
                mean_item_price
                - ROUND(
                    sum_event_price / NULLIF(cnt_item, 0),
                    2
                )
            ) > 0.01
        ), 0) AS bad_mean_item_price,

        COALESCE(SUM(
            min_item_price > mean_item_price
            OR mean_item_price > max_item_price
        ), 0) AS bad_item_price_range,

        COALESCE(SUM(
            event_purchase_date_key <>
            CAST(
                DATE_FORMAT(event_purchase_timestamp, '%Y%m%d')
                AS UNSIGNED
            )
        ), 0) AS bad_event_date_key,

        COALESCE(SUM(
            has_late_delivery NOT IN (0, 1)
            OR has_review NOT IN (0, 1)
            OR has_low_review NOT IN (0, 1)
            OR has_comment NOT IN (0, 1)
            OR has_positive NOT IN (0, 1)
            OR has_negative NOT IN (0, 1)
            OR has_mixed NOT IN (0, 1)
            OR has_neutral NOT IN (0, 1)
            OR has_t01_delivery_logistics NOT IN (0, 1)
            OR has_t02_order_fulfillment NOT IN (0, 1)
            OR has_t03_product_quality NOT IN (0, 1)
            OR has_t04_product_consistency NOT IN (0, 1)
            OR has_t05_packaging_protection NOT IN (0, 1)
            OR has_t06_customer_service NOT IN (0, 1)
            OR has_t07_price_transaction NOT IN (0, 1)
            OR has_t08_platform_system NOT IN (0, 1)
            OR has_credit_card NOT IN (0, 1)
            OR has_boleto NOT IN (0, 1)
            OR has_voucher NOT IN (0, 1)
            OR has_debit_card NOT IN (0, 1)
            OR has_not_defined NOT IN (0, 1)
        ), 0) AS bad_binary_flag

    FROM olist_data_mart.fact_delivered_order_event
),
rule_result AS (
    SELECT 'event_order_count' AS test_name,
           bad_event_order_count AS violation_count
    FROM rule_count

    UNION ALL
    SELECT 'late_delivery_logic', bad_late_delivery_logic FROM rule_count

    UNION ALL
    SELECT 'mean_delay_logic', bad_delay_logic FROM rule_count

    UNION ALL
    SELECT 'review_null_logic', bad_review_null_logic FROM rule_count

    UNION ALL
    SELECT 'review_score_logic', bad_review_score_logic FROM rule_count

    UNION ALL
    SELECT 'payment_logic', bad_payment_logic FROM rule_count

    UNION ALL
    SELECT 'item_count_logic', bad_item_logic FROM rule_count

    UNION ALL
    SELECT 'event_total_value', bad_event_total_value FROM rule_count

    UNION ALL
    SELECT 'freight_ratio', bad_freight_ratio FROM rule_count

    UNION ALL
    SELECT 'mean_item_price', bad_mean_item_price FROM rule_count

    UNION ALL
    SELECT 'item_price_range', bad_item_price_range FROM rule_count

    UNION ALL
    SELECT 'event_purchase_date_key', bad_event_date_key FROM rule_count

    UNION ALL
    SELECT 'binary_flags', bad_binary_flag FROM rule_count
)
SELECT
    test_name,
    violation_count,
    CASE
        WHEN violation_count = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM rule_result;


/* =========================================================
   6. 人工合理性摘要
   這不是固定 PASS / FAIL；確認日期、比例與極值符合預期。
   ========================================================= */

SELECT
    COUNT(*) AS event_count,
    MIN(event_purchase_timestamp) AS first_event_timestamp,
    MAX(event_purchase_timestamp) AS last_event_timestamp,
    MIN(cnt_event_order) AS min_orders_per_event,
    ROUND(AVG(cnt_event_order), 4) AS mean_orders_per_event,
    MAX(cnt_event_order) AS max_orders_per_event,
    SUM(cnt_event_order) AS total_order_count,
    SUM(cnt_item) AS total_item_count,
    ROUND(AVG(has_late_delivery) * 100, 2) AS late_event_rate_pct,
    ROUND(AVG(has_review) * 100, 2) AS reviewed_event_rate_pct,
    ROUND(AVG(mean_review_score), 2) AS mean_review_score_among_reviewed,
    SUM(payment_value) AS total_payment_value,
    SUM(event_total_value) AS total_item_and_freight_value
FROM olist_data_mart.fact_delivered_order_event;
