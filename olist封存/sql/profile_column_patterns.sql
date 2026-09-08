DROP PROCEDURE IF EXISTS profile_column_patterns;
DELIMITER $$

CREATE PROCEDURE profile_column_patterns (
    IN in_schema_name VARCHAR(64)
)
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE v_table_name  VARCHAR(64);
    DECLARE v_column_name VARCHAR(64);
    DECLARE v_data_type   VARCHAR(64);
    DECLARE v_sql TEXT;

    DECLARE col_cursor CURSOR FOR
        SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = in_schema_name
        ORDER BY TABLE_NAME, ORDINAL_POSITION;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    DROP TEMPORARY TABLE IF EXISTS tmp_pattern_stats;
    CREATE TEMPORARY TABLE tmp_pattern_stats (
        schema_name   VARCHAR(64),
        table_name    VARCHAR(64),
        column_name   VARCHAR(64),
        pattern       TEXT,
        pattern_count BIGINT
    );

    OPEN col_cursor;

    read_loop: LOOP
        FETCH col_cursor INTO v_table_name, v_column_name, v_data_type;
        IF done = 1 THEN
            LEAVE read_loop;
        END IF;

        -- 1) ID 類欄位：全部變成 '9'
        IF v_column_name IN ('order_id','customer_id','seller_id','product_id','review_id')
           OR RIGHT(v_column_name, 3) = '_id' THEN

            SET @v_sql = CONCAT(
                'INSERT INTO tmp_pattern_stats (schema_name, table_name, column_name, pattern, pattern_count) ',
                'SELECT ''', in_schema_name, ''', ''', v_table_name, ''', ''', v_column_name, ''', ',
                '''9'' AS pattern, ',
                'COUNT(*) ',
                'FROM `', in_schema_name, '`.`', v_table_name, '` ',
                'WHERE `', v_column_name, '` IS NOT NULL ',
                'GROUP BY ''9'''
            );

        -- 2) comment / 描述類欄位：有值就視為 '9'
        ELSEIF v_column_name IN ('review_comment_message','review_comment_title')
            OR v_column_name LIKE '%comment%'
            OR v_column_name LIKE '%description%'
            OR v_column_name LIKE '%desc%'
            OR v_column_name LIKE '%message%' THEN

            SET @v_sql = CONCAT(
                'INSERT INTO tmp_pattern_stats (schema_name, table_name, column_name, pattern, pattern_count) ',
                'SELECT ''', in_schema_name, ''', ''', v_table_name, ''', ''', v_column_name, ''', ',
                '''9'' AS pattern, ',
                'COUNT(*) ',
                'FROM `', in_schema_name, '`.`', v_table_name, '` ',
                'WHERE `', v_column_name, '` IS NOT NULL ',
                'GROUP BY ''9'''
            );

        -- 3) 其他欄位：數字改為 9，字母保留
        ELSE
            SET @v_sql = CONCAT(
                'INSERT INTO tmp_pattern_stats (schema_name, table_name, column_name, pattern, pattern_count) ',
                'SELECT ''', in_schema_name, ''', ''', v_table_name, ''', ''', v_column_name, ''', ',
                'REGEXP_REPLACE(CAST(`', v_column_name, '` AS CHAR), ''[0-9]'',''9'') AS pattern, ',
                'COUNT(*) ',
                'FROM `', in_schema_name, '`.`', v_table_name, '` ',
                'WHERE `', v_column_name, '` IS NOT NULL ',
                'GROUP BY REGEXP_REPLACE(CAST(`', v_column_name, '` AS CHAR), ''[0-9]'',''9'')'
            );
        END IF;

        PREPARE stmt FROM @v_sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

    END LOOP;

    CLOSE col_cursor;

    SELECT *
    FROM tmp_pattern_stats
    ORDER BY table_name, column_name, pattern_count DESC;

END $$

DELIMITER ;
