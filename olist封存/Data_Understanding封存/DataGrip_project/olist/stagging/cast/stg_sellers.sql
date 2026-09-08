CREATE TABLE IF NOT EXISTS olist_staging.stg_sellers AS
SELECT *
FROM olist_raw.sellers;