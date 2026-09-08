/* =========================================================
   dq_null_check.sql
   檢查所有 staging table 欄位缺失情況
   ========================================================= */

USE olist_staging;

SET SESSION group_concat_max_len = 1000000;

SET @sql = NULL;

SELECT
    GROUP_CONCAT(sql_text SEPARATOR '\nUNION ALL\n')
INTO @sql
FROM (
    SELECT
        CONCAT(
            'SELECT ',
            '''', table_name, ''' AS table_name, ',
            '''', column_name, ''' AS column_name, ',
            'COUNT(*) AS row_count, ',
            'SUM(`', column_name, '` IS NULL) AS null_count, ',
            'ROUND(SUM(`', column_name, '` IS NULL) / COUNT(*) * 100, 2) AS null_rate_pct ',
            'FROM `', table_schema, '`.`', table_name, '`'
        ) AS sql_text
    FROM information_schema.columns
    WHERE table_schema = 'olist_staging'
      AND table_name IN (
          'stg_category_translation',
          'stg_customers',
          'stg_order_items',
          'stg_orders',
          'stg_payments',
          'stg_products',
          'stg_reviews',
          'stg_sellers'
      )
    ORDER BY table_name, ordinal_position
) t;

SET @sql = CONCAT(
    'SELECT * FROM (',
    @sql,
    ') AS dq_null_report ',
    'ORDER BY null_rate_pct DESC, table_name, column_name;'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;