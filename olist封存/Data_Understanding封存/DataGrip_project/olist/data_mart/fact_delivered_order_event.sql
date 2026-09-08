DROP TABLE IF EXISTS olist_data_mart.fact_delivered_order_event;
CREATE TABLE olist_data_mart.fact_delivered_order_event(
    /* 識別鍵 */
    order_event_key INT UNSIGNED NOT NULL,
    customer_key INT UNSIGNED NOT NULL,
    event_purchase_date_key INT UNSIGNED NOT NULL,

    /* event資訊 */
    event_purchase_timestamp DATETIME NOT NULL,
    cnt_event_order INT UNSIGNED NOT NULL,

    /* 訂單生命週期資訊 */
    mean_purchase_to_approval_seconds INT UNSIGNED NOT NULL,
    mean_approved_to_carrier_seconds  INT UNSIGNED NOT NULL,
    mean_carrier_to_customer_seconds  INT UNSIGNED NOT NULL,
    mean_estimated_delivery_seconds   INT UNSIGNED NOT NULL,
    mean_delivery_seconds INT UNSIGNED NOT NULL,
    mean_delay_seconds INT UNSIGNED NOT NULL,

    /* 運送flag */
    has_late_delivery TINYINT UNSIGNED NOT NULL,
    cnt_late_order INT UNSIGNED NOT NULL,

    /* review資訊 */
    cnt_review INT UNSIGNED NOT NULL,
    has_review TINYINT UNSIGNED NOT NULL,
    mean_review_score DECIMAL(3,2) ,
    sum_review_score INT UNSIGNED NOT NULL,
    has_low_review TINYINT UNSIGNED NOT NULL,
    has_comment TINYINT UNSIGNED NOT NULL,
    max_review_comment_length INT UNSIGNED NOT NULL,
    has_positive TINYINT UNSIGNED NOT NULL,
    has_negative TINYINT UNSIGNED NOT NULL,
    has_mixed TINYINT UNSIGNED NOT NULL,
    has_neutral TINYINT UNSIGNED NOT NULL,
    has_t01_delivery_logistics TINYINT UNSIGNED NOT NULL,
    has_t02_order_fulfillment TINYINT UNSIGNED NOT NULL,
    has_t03_product_quality TINYINT UNSIGNED NOT NULL,
    has_t04_product_consistency TINYINT UNSIGNED NOT NULL,
    has_t05_packaging_protection TINYINT UNSIGNED NOT NULL,
    has_t06_customer_service TINYINT UNSIGNED NOT NULL,
    has_t07_price_transaction TINYINT UNSIGNED NOT NULL,
    has_t08_platform_system TINYINT UNSIGNED NOT NULL,
    first_review_creation_date DATETIME,
    last_review_answer_timestamp DATETIME,

    /* payment 資訊*/
    cnt_payment_record INT UNSIGNED NOT NULL,
    payment_value DECIMAL(14,2) UNSIGNED NOT NULL,
    max_payment_installments SMALLINT UNSIGNED NOT NULL,
    cnt_distinct_payment_type TINYINT UNSIGNED NOT NULL,
    has_credit_card TINYINT UNSIGNED NOT NULL,
    has_boleto TINYINT UNSIGNED NOT NULL,
    has_voucher TINYINT UNSIGNED NOT NULL,
    has_debit_card TINYINT UNSIGNED NOT NULL,
    has_not_defined TINYINT UNSIGNED NOT NULL,

    /* order_item 資訊*/
    cnt_item INT UNSIGNED NOT NULL,
    cnt_distinct_product INT UNSIGNED NOT NULL,
    cnt_distinct_product_category INT UNSIGNED NOT NULL,
    cnt_distinct_seller INT UNSIGNED NOT NULL,
    sum_event_price DECIMAL(14,2) UNSIGNED NOT NULL,
    sum_event_freight_value DECIMAL(14,2) UNSIGNED NOT NULL,
    event_total_value DECIMAL(14,2) UNSIGNED NOT NULL,
    freight_ratio DECIMAL(6,4) UNSIGNED NOT NULL,
    mean_item_price DECIMAL(14,2) UNSIGNED NOT NULL,
    max_item_price DECIMAL(14,2) UNSIGNED NOT NULL,
    min_item_price DECIMAL(14,2) UNSIGNED NOT NULL,

    CONSTRAINT pk_order_event_key
        PRIMARY KEY(order_event_key),

    CONSTRAINT fk_fact_order_event_customer
        FOREIGN KEY(customer_key)
        REFERENCES olist_data_mart.dim_customer(customer_key),

    CONSTRAINT fk_fact_event_purchase_date
        FOREIGN KEY(event_purchase_date_key)
        REFERENCES olist_data_mart.dim_date(date_key)
);

INSERT INTO olist_data_mart.fact_delivered_order_event (
    order_event_key,
    customer_key,
    event_purchase_date_key,
    event_purchase_timestamp,
    cnt_event_order,
    mean_purchase_to_approval_seconds,
    mean_approved_to_carrier_seconds,
    mean_carrier_to_customer_seconds,
    mean_estimated_delivery_seconds,
    mean_delivery_seconds,
    mean_delay_seconds,
    has_late_delivery,
    cnt_late_order,
    cnt_review,
    has_review,
    mean_review_score,
    sum_review_score,
    has_low_review,
    has_comment,
    max_review_comment_length,
    has_positive,
    has_negative,
    has_mixed,
    has_neutral,
    has_t01_delivery_logistics,
    has_t02_order_fulfillment,
    has_t03_product_quality,
    has_t04_product_consistency,
    has_t05_packaging_protection,
    has_t06_customer_service,
    has_t07_price_transaction,
    has_t08_platform_system,
    first_review_creation_date,
    last_review_answer_timestamp,
    cnt_payment_record,
    payment_value,
    max_payment_installments,
    cnt_distinct_payment_type,
    has_credit_card,
    has_boleto,
    has_voucher,
    has_debit_card,
    has_not_defined,
    cnt_item,
    cnt_distinct_product,
    cnt_distinct_product_category,
    cnt_distinct_seller,
    sum_event_price,
    sum_event_freight_value,
    event_total_value,
    freight_ratio,
    mean_item_price,
    max_item_price,
    min_item_price
)

WITH event_vw_order_agg AS(
    /* 把vw_delivered_order_base 聚合成 event-level */
    SELECT
        order_event_key,
        min(customer_unique_id) as customer_unique_id, #每組order_event_key只有一種customer_key
        min(event_purchase_timestamp)as event_purchase_timestamp,# event_purchase_ts取最小order_purchase_ts
        COUNT(*) as cnt_event_order,
        ROUND(AVG(purchase_to_approval_seconds),0) as mean_purchase_to_approval_seconds,
        ROUND(AVG(approved_to_carrier_seconds),0)  as mean_approved_to_carrier_seconds,
        ROUND(AVG(carrier_to_customer_seconds),0)  as mean_carrier_to_customer_seconds,
        ROUND(AVG(estimated_delivery_seconds),0)   as mean_estimated_delivery_seconds,
        ROUND(AVG(delivery_seconds),0) as mean_delivery_seconds,
        -- 只取delay order 算平均延遲秒數
        -- AVG會忽略NULL因此delay_seconds<=0 不會參與計算
        -- 沒有延遲訂單紀錄為0
        COALESCE(ROUND(AVG(
                        CASE
                            WHEN delay_seconds > 0 THEN delay_seconds
                        END
                    ),0
                ),0) as mean_delay_seconds,
        MAX(is_late_delivery) as has_late_delivery,
        SUM(is_late_delivery) as cnt_late_order,
        SUM(cnt_review) as cnt_review,
        MAX(has_review) as has_review,
        SUM(sum_review_score) as sum_review_score,
        ROUND(SUM(sum_review_score) / NULLIF(SUM(cnt_review),0),2) as mean_review_score,
        MAX(has_low_review) as has_low_review,
        MAX(has_comment) as has_comment,
        MAX(max_review_comment_length) as max_review_comment_length,
        MAX(has_positive) as has_positive,
        MAX(has_negative) as has_negative,
        MAX(has_mixed) as has_mixed,
        MAX(has_neutral) as has_neutral,
        MAX(has_t01_delivery_logistics) as has_t01_delivery_logistics,
        MAX(has_t02_order_fulfillment) as has_t02_order_fulfillment,
        MAX(has_t03_product_quality) as has_t03_product_quality,
        MAX(has_t04_product_consistency) as has_t04_product_consistency,
        MAX(has_t05_packaging_protection) as has_t05_packaging_protection,
        MAX(has_t06_customer_service) as has_t06_customer_service,
        MAX(has_t07_price_transaction) as has_t07_price_transaction,
        MAX(has_t08_platform_system) as has_t08_platform_system,
        MIN(first_review_creation_date) as first_review_creation_date,
        MAX(last_review_answer_timestamp) as last_review_answer_timestamp,
        SUM(cnt_payment_record) as cnt_payment_record,
        SUM(payment_value) as payment_value,
        MAX(max_payment_installments) as max_payment_installments,
        MAX(has_credit_card) AS has_credit_card,
        MAX(has_boleto) AS has_boleto,
        MAX(has_voucher) AS has_voucher,
        MAX(has_debit_card) AS has_debit_card,
        MAX(has_not_defined) AS has_not_defined,

        (MAX(has_credit_card)
        + MAX(has_boleto)
        + MAX(has_voucher)
        + MAX(has_debit_card)
        + MAX(has_not_defined)) AS cnt_distinct_payment_type,
        SUM(cnt_item) as cnt_item,
        SUM(sum_order_price) as sum_event_price,
        SUM(sum_order_freight_value) as sum_event_freight_value,
        SUM(order_total_value) as event_total_value,
        ROUND(SUM(sum_order_freight_value) / NULLIF(SUM(order_total_value),0),4) as freight_ratio,
        ROUND(
            SUM(sum_order_price) / NULLIF(SUM(cnt_item), 0),2
            ) AS mean_item_price,
        ROUND(MAX(max_item_price),2) as max_item_price,
        ROUND(MIN(min_item_price),2) as min_item_price

    FROM olist_data_mart.vw_delivered_order_base
    GROUP BY order_event_key
),

event_item_distinct AS(
    /* distinct欄位需要從order_item-level計算*/
    /* cnt_distinct_product */
    /* cnt_distinct_product_category */
    /* cnt_distict_seller */
    SELECT
        order_event_key,
        COUNT(DISTINCT oi.product_key) as cnt_distinct_product,
        COUNT(DISTINCT p.product_category_name_english) as cnt_distinct_product_category,
        COUNT(DISTINCT oi.seller_key) as cnt_distinct_seller
    FROM olist_data_mart.fact_delivered_order_item as oi
    INNER JOIN olist_data_mart.dim_product as p
    ON oi.product_key = p.product_key
    GROUP BY order_event_key
),
final_event AS(
    SELECT
        e.order_event_key,
        c.customer_key,
        d.date_key as event_purchase_date_key,
        e.event_purchase_timestamp,
        e.cnt_event_order,
        e.mean_purchase_to_approval_seconds,
        e.mean_approved_to_carrier_seconds,
        e.mean_carrier_to_customer_seconds,
        e.mean_estimated_delivery_seconds,
        e.mean_delivery_seconds,
        e.mean_delay_seconds,
        e.has_late_delivery,
        e.cnt_late_order,
        e.cnt_review,
        e.has_review,
        e.mean_review_score,
        e.sum_review_score,
        e.has_low_review,
        e.has_comment,
        e.max_review_comment_length,
        e.has_positive,
        e.has_negative,
        e.has_mixed,
        e.has_neutral,
        e.has_t01_delivery_logistics,
        e.has_t02_order_fulfillment,
        e.has_t03_product_quality,
        e.has_t04_product_consistency,
        e.has_t05_packaging_protection,
        e.has_t06_customer_service,
        e.has_t07_price_transaction,
        e.has_t08_platform_system,
        e.first_review_creation_date,
        e.last_review_answer_timestamp,
        e.cnt_payment_record,
        e.payment_value,
        e.max_payment_installments,
        e.cnt_distinct_payment_type,
        e.has_credit_card,
        e.has_boleto,
        e.has_voucher,
        e.has_debit_card,
        e.has_not_defined,
        e.cnt_item,
        oid.cnt_distinct_product,
        oid.cnt_distinct_product_category,
        oid.cnt_distinct_seller,
        e.sum_event_price,
        e.sum_event_freight_value,
        e.event_total_value,
        e.freight_ratio,
        e.mean_item_price,
        e.max_item_price,
        e.min_item_price




    FROM event_vw_order_agg as e
    INNER JOIN event_item_distinct as oid
    ON e.order_event_key = oid.order_event_key
    INNER JOIN olist_data_mart.dim_customer as c
    ON e.customer_unique_id = c.customer_unique_id
    INNER JOIN olist_data_mart.dim_date as d
    ON d.full_date = date(e.event_purchase_timestamp))

SELECT *
FROM final_event

