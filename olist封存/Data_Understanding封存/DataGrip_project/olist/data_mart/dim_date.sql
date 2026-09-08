SET SESSION cte_max_recursion_depth = 2000;

DROP TABLE IF EXISTS olist_data_mart.dim_date;

CREATE TABLE olist_data_mart.dim_date(
    date_key INT UNSIGNED PRIMARY KEY,
    full_date DATE NOT NULL,
    year INT NOT NULL,
    quarter INT NOT NULL,
    month INT NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    day INT NOT NULL,
    day_of_week INT NOT NULL,
    day_name VARCHAR(20) NOT NULL,
    is_weekend TINYINT NOT NULL,
    is_holiday TINYINT NOT NULL,
    holiday_name VARCHAR(100),
    holiday_type VARCHAR(50)
);

INSERT INTO olist_data_mart.dim_date (
    date_key,
    full_date,
    year,
    quarter,
    month,
    month_name,
    day,
    day_of_week,
    day_name,
    is_weekend,
    is_holiday,
    holiday_name,
    holiday_type
)
WITH RECURSIVE date_series AS(
    SELECT DATE('2016-01-01') AS full_date

    UNION ALL

    SELECT DATE_ADD(full_date, INTERVAL 1 DAY)
    FROM date_series
    WHERE full_date < '2018-12-31'
    )

SELECT
    CAST(DATE_FORMAT(ds.full_date,'%Y%m%d')AS UNSIGNED) as date_key, # 轉成8碼日期key
    ds.full_date,
    YEAR(ds.full_date) as year,
    QUARTER(ds.full_date) as quarter,
    MONTH(ds.full_date) as month,
    MONTHNAME(ds.full_date) as month_name,
    DAY(ds.full_date) as day,
    WEEKDAY(ds.full_date)+1 as day_of_week,
    DAYNAME(ds.full_date) as day_name,
    CASE WHEN
        WEEKDAY(ds.full_date)+1 IN (6,7) THEN 1
        ELSE 0
        END as is_weekend,
    CASE WHEN
        bhl.holiday_date is not null THEN 1
        ELSE 0
        END as is_holiday,
    bhl.holiday_name,
    bhl.holiday_type





FROM date_series as ds
LEFT JOIN olist_data_mart.brazil_holiday_lookup as bhl
ON ds.full_date = bhl.holiday_date;
