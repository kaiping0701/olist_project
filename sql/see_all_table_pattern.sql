-- 訂單主檔
CALL profile_table_patterns('olist', 'olist_orders_dataset');

-- 訂單品項
CALL profile_table_patterns('olist', 'olist_order_items_dataset');

-- 訂單付款
CALL profile_table_patterns('olist', 'olist_order_payments_dataset');

-- 訂單評論
CALL profile_table_patterns('olist', 'olist_order_reviews_dataset');

-- 客戶維度
CALL profile_table_patterns('olist', 'olist_customers_dataset');

-- 商品維度
CALL profile_table_patterns('olist', 'olist_products_dataset');

-- 賣家維度
CALL profile_table_patterns('olist', 'olist_sellers_dataset');

-- 地理位置
CALL profile_table_patterns('olist', 'olist_geolocation_dataset');

-- 商品類別翻譯表（請依你的實際表名擇一使用）
CALL profile_table_patterns('olist', 'product_category_name_translation');
-- 或
-- CALL profile_table_patterns('olist', 'olist_category_name_translation');
