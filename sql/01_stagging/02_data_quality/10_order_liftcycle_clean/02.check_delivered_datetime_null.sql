select
    *
FROM olist_staging.stg_orders

WHERE  order_status = "delivered" AND(
        order_purchase_timestamp is NULL or
      order_approved_at is NULL or
      order_delivered_carrier_date IS NULL or
      order_delivered_customer_date IS NULL or
      order_estimated_delivery_date IS NULL)