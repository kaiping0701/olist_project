CREATE OR REPLACE VIEW olist_data_mart.vw_delivered_order_base AS
SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    c.customer_zip_code_prefix,
    map.order_event_key,
    map.event_purchase_timestamp,
    o.order_purchase_timestamp,
    TIMESTAMPDIFF(
        SECOND,
        o.order_purchase_timestamp,
        o.order_approved_at
    ) AS purchase_to_approval_seconds,

    TIMESTAMPDIFF(
        SECOND,
        o.order_approved_at,
        o.order_delivered_carrier_date
    ) AS approved_to_carrier_seconds,

    TIMESTAMPDIFF(
        SECOND,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date
    ) AS carrier_to_customer_seconds,

    TIMESTAMPDIFF(
        SECOND,
        o.order_purchase_timestamp,
        o.order_estimated_delivery_date
    ) AS estimated_delivery_seconds,

    TIMESTAMPDIFF(
        SECOND,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date
    ) AS delivery_seconds,

    TIMESTAMPDIFF(
        SECOND,
        o.order_estimated_delivery_date,
        o.order_delivered_customer_date
    ) AS delay_seconds,

   CASE
       WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 1
            ELSE 0
    END as is_late_delivery,

    COALESCE(r.cnt_review, 0) AS cnt_review,

    CASE
        WHEN COALESCE(r.cnt_review, 0) > 0 THEN 1
        ELSE 0
    END AS has_review,

    r.mean_review_score,
    COALESCE(r.sum_review_score, 0) AS sum_review_score,
    COALESCE(r.has_low_review, 0) AS has_low_review,
    COALESCE(r.has_comment, 0) AS has_comment,
    COALESCE(r.max_review_comment_length, 0)
        AS max_review_comment_length,

    COALESCE(r.has_positive, 0) AS has_positive,
    COALESCE(r.has_negative, 0) AS has_negative,
    COALESCE(r.has_mixed, 0) AS has_mixed,
    COALESCE(r.has_neutral, 0) AS has_neutral,

    COALESCE(r.has_t01_delivery_logistics, 0)
        AS has_t01_delivery_logistics,
    COALESCE(r.has_t02_order_fulfillment, 0)
        AS has_t02_order_fulfillment,
    COALESCE(r.has_t03_product_quality, 0)
        AS has_t03_product_quality,
    COALESCE(r.has_t04_product_consistency, 0)
        AS has_t04_product_consistency,
    COALESCE(r.has_t05_packaging_protection, 0)
        AS has_t05_packaging_protection,
    COALESCE(r.has_t06_customer_service, 0)
        AS has_t06_customer_service,
    COALESCE(r.has_t07_price_transaction, 0)
        AS has_t07_price_transaction,
    COALESCE(r.has_t08_platform_system, 0)
        AS has_t08_platform_system,

    r.first_review_creation_date,
    r.last_review_answer_timestamp,

    COALESCE(p.cnt_payment_record, 0) AS cnt_payment_record,
    COALESCE(p.payment_value, 0) AS payment_value,
    COALESCE(p.max_payment_installments, 0)
        AS max_payment_installments,
    COALESCE(p.cnt_distinct_payment_type, 0)
        AS cnt_distinct_payment_type,
    COALESCE(p.has_credit_card, 0) AS has_credit_card,
    COALESCE(p.has_boleto, 0) AS has_boleto,
    COALESCE(p.has_voucher, 0) AS has_voucher,
    COALESCE(p.has_debit_card, 0) AS has_debit_card,
    COALESCE(p.has_not_defined, 0) AS has_not_defined,
    i.cnt_item,
    i.cnt_distinct_product,
    i.cnt_distinct_category,
    i.cnt_distinct_seller,
    i.sum_order_price,
    i.sum_order_freight_value,
    i.order_total_value,
    ROUND(
        i.sum_order_freight_value
        / NULLIF(i.order_total_value, 0)
        ,4
        ) AS freight_ratio,
    i.mean_item_price,
    i.max_item_price,
    i.min_item_price



FROM olist_staging.vw_orders_clean as o
INNER JOIN olist_data_mart.map_delivered_order_to_event as map
ON o.order_id = map.order_id
INNER JOIN olist_staging.stg_customers as c
ON o.customer_id = c.customer_id
LEFT JOIN olist_data_mart.vw_delivered_order_review_agg as r
ON o.order_id = r.order_id
LEFT JOIN olist_data_mart.vw_delivered_order_payment_agg as p
ON o.order_id = p.order_id
LEFT JOIN olist_data_mart.vw_delivered_order_item_agg as i
ON o.order_id = i.order_id;
