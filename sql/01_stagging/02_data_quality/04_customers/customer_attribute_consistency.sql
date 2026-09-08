# 看同一個 customer 在同一個 purchase_ts 購買的組合是否有不同
# 的客戶資訊


SELECT
    c.customer_unique_id,
    o.order_purchase_timestamp,
    count(DISTINCT c.customer_zip_code_prefix) as zip_count,
    count(DISTINCT c.customer_city) as city_count,
    count(DISTINCT c.customer_state) as state_count

FROM olist_staging.stg_orders as o
LEFT JOIN olist_staging.stg_customers as c
    on o.customer_id = c.customer_id
GROUP BY c.customer_unique_id, o.order_purchase_timestamp
HAVING zip_count>1 or city_count>1 or state_count>1

# 每個order_event裡面都只有一組customer屬性