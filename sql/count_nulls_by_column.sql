DELIMITER $$

CREATE PROCEDURE count_nulls_by_column (
    IN in_schema_name VARCHAR(64),
    IN in_table_name  VARCHAR(64)
)
BEGIN
    -- 1. 所有 DECLARE 必須集中在最前面
    DECLARE done INT DEFAULT 0;
    DECLARE v_column_name VARCHAR(64);
    DECLARE v_sql TEXT;

    -- 2. 宣告 cursor
    DECLARE col_cursor CURSOR FOR
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = in_schema_name
          AND TABLE_NAME   = in_table_name
        ORDER BY ORDINAL_POSITION;

    -- 3. 宣告 handler
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    -- 4. 以下才能開始寫 SQL、CREATE TABLE 等等
    DROP TEMPORARY TABLE IF EXISTS tmp_null_stats;

    CREATE TEMPORARY TABLE tmp_null_stats (
        column_name     VARCHAR(64),
        null_count      BIGINT,
        non_null_count  BIGINT,
        null_ratio      DECIMAL(10,4)
    );

    -- 5. 開啟 cursor
    OPEN col_cursor;

    read_loop: LOOP
        FETCH col_cursor INTO v_column_name;

        IF done = 1 THEN
            LEAVE read_loop;
        END IF;

        SET @v_sql = CONCAT(
            'INSERT INTO tmp_null_stats (column_name, null_count, non_null_count, null_ratio) ',
            'SELECT ''', v_column_name, ''' AS column_name, ',
            '       SUM(CASE WHEN `', v_column_name, '` IS NULL THEN 1 ELSE 0 END) AS null_count, ',
            '       SUM(CASE WHEN `', v_column_name, '` IS NOT NULL THEN 1 ELSE 0 END) AS non_null_count, ',
            '       CASE WHEN COUNT(*) = 0 THEN 0 ',
            '            ELSE SUM(CASE WHEN `', v_column_name, '` IS NULL THEN 1 ELSE 0 END) / COUNT(*) ',
            '       END AS null_ratio ',
            'FROM `', in_schema_name, '`.`', in_table_name, '`;'
        );

        PREPARE stmt FROM @v_sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

    END LOOP read_loop;

    CLOSE col_cursor;

    SELECT *
    FROM tmp_null_stats
    ORDER BY null_ratio DESC;

END $$

DELIMITER ;
