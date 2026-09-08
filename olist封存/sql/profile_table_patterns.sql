DROP PROCEDURE IF EXISTS profile_table_patterns;
DELIMITER $$

CREATE PROCEDURE profile_table_patterns (
    IN in_schema_name VARCHAR(64),
    IN in_table_name  VARCHAR(64)
)
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE v_column_name VARCHAR(64);
    DECLARE v_sql TEXT;

    DECLARE col_cursor CURSOR FOR
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = in_schema_name
          AND TABLE_NAME   = in_table_name
          AND COLUMN_NAME NOT IN ('review_comment_message','review_comment_title')
        ORDER BY ORDINAL_POSITION;

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
        FETCH col_cursor INTO v_column_name;
        IF done = 1 THEN LEAVE read_loop; END IF;

        -- 正確 UUID 偵測：長度 = 32 AND 全為 0-9 或 a-f
        SET @v_sql = CONCAT(
            'INSERT INTO tmp_pattern_stats ',
            '(schema_name, table_name, column_name, pattern, pattern_count) ',
            'SELECT ''', in_schema_name, ''', ''', in_table_name, ''', ''', v_column_name, ''', ',
            'CASE ',
            '   WHEN CHAR_LENGTH(CAST(`', v_column_name, '` AS CHAR)) = 32 ',
            '    AND LOWER(CAST(`', v_column_name, '` AS CHAR)) REGEXP ''^[0-9a-f]+$'' ',
            '       THEN ''9'' ',
            '   ELSE REGEXP_REPLACE(CAST(`', v_column_name, '` AS CHAR), ''[0-9]'',''9'') ',
            'END AS pattern, ',
            'COUNT(*) AS pattern_count ',
            'FROM `', in_schema_name, '`.`', in_table_name, '` ',
            'WHERE `', v_column_name, '` IS NOT NULL ',
            'GROUP BY pattern'
        );

        PREPARE stmt FROM @v_sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

    END LOOP;

    CLOSE col_cursor;

    SELECT *
    FROM tmp_pattern_stats
    ORDER BY column_name, pattern_count DESC;

END $$

DELIMITER ;
