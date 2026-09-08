CREATE OR REPLACE VIEW olist_staging.vw_orders_clean AS

WITH median_parameter AS (
    SELECT
        1236   AS median_purchase_to_approval_seconds,
        190542 AS median_purchase_to_carrier_seconds,
        883629 AS median_purchase_to_customer_seconds
),

-- 先處理Carrier
clean_carrier AS (
    SELECT
        o.*,

        CASE
            WHEN o.order_status = 'delivered'
             AND (
                    o.order_delivered_carrier_date IS NULL
                 OR o.order_delivered_carrier_date
                    < o.order_purchase_timestamp
             )
            THEN DATE_ADD(
                o.order_purchase_timestamp,
                INTERVAL m.median_purchase_to_carrier_seconds SECOND
            )
            ELSE o.order_delivered_carrier_date
        END AS carrier_clean,

        m.median_purchase_to_approval_seconds,
        m.median_purchase_to_customer_seconds

    FROM olist_staging.stg_orders AS o
    CROSS JOIN median_parameter AS m
),

-- 再處理Approval
clean_approval AS (
    SELECT
        *,

        CASE
            WHEN order_status = 'delivered'
             AND (
                    order_approved_at IS NULL
                 OR order_approved_at < order_purchase_timestamp
                 OR order_approved_at > carrier_clean
             )
            THEN LEAST(
                DATE_ADD(
                    order_purchase_timestamp,
                    INTERVAL median_purchase_to_approval_seconds SECOND
                ),
                carrier_clean
            )
            ELSE order_approved_at
        END AS approval_clean

    FROM clean_carrier
),

-- 最後處理Customer
clean_customer AS (
    SELECT
        *,

        CASE
            WHEN order_status = 'delivered'
             AND (
                    order_delivered_customer_date IS NULL
                 OR order_delivered_customer_date < carrier_clean
             )
            THEN GREATEST(
                DATE_ADD(
                    order_purchase_timestamp,
                    INTERVAL median_purchase_to_customer_seconds SECOND
                ),
                carrier_clean
            )
            ELSE order_delivered_customer_date
        END AS customer_clean

    FROM clean_approval
)

SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    approval_clean AS order_approved_at,
    carrier_clean AS order_delivered_carrier_date,
    customer_clean AS order_delivered_customer_date,
    order_estimated_delivery_date

FROM clean_customer;