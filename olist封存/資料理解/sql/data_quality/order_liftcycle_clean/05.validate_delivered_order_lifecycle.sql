SELECT
    COUNT(*) AS delivered_order_cnt,

    SUM(
        CASE
            WHEN order_purchase_timestamp <= order_approved_at
             AND order_approved_at <= order_delivered_carrier_date
             AND order_delivered_carrier_date <= order_delivered_customer_date
             AND order_estimated_delivery_date >= order_purchase_timestamp
            THEN 1
            ELSE 0
        END
    ) AS valid_lifecycle_order_cnt,

    SUM(
        CASE
            WHEN order_purchase_timestamp <= order_approved_at
             AND order_approved_at <= order_delivered_carrier_date
             AND order_delivered_carrier_date <= order_delivered_customer_date
             AND order_estimated_delivery_date >= order_purchase_timestamp
            THEN 0
            ELSE 1
        END
    ) AS invalid_lifecycle_order_cnt

FROM olist_staging.vw_orders_clean
WHERE order_status = 'delivered';