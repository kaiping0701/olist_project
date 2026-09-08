
CREATE OR REPLACE VIEW olist_data_mart.vw_delivered_order_payment_agg AS
    SELECT
        p.order_id,
        COUNT(payment_sequential) AS cnt_payment_record,
        SUM(payment_value) AS payment_value,
        # 一筆order可能會有兩種以上付款方式
        # 例如： 信用卡分6期 ， 金融卡分1期 ，所以取max
        # 資料集裡面有兩筆不同的order id payment_installments=0
        # 且兩筆不同的order_id 的 payment_sequential均只有2
        MAX(
            CASE
                WHEN  p.payment_installments = 0 THEN 1
                ELSE p.payment_installments
            END
        ) AS max_payment_installments,
        COUNT(DISTINCT p.payment_type) AS cnt_distinct_payment_type,
        MAX(p.payment_type = 'credit_card') AS has_credit_card,
        MAX(p.payment_type = 'boleto') AS has_boleto,
        MAX(p.payment_type = 'voucher') AS has_voucher,
        MAX(p.payment_type = 'debit_card') AS has_debit_card,
        MAX(p.payment_type = 'not_defined') AS has_not_defined
    FROM olist_staging.stg_payments as p
    INNER JOIN olist_data_mart.map_delivered_order_to_event as map
    ON p.order_id = map.order_id
    GROUP BY p.order_id