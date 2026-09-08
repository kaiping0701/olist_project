-- 計算同一 customer_unique_id 的相鄰 order gap 分布 (排除首購)

WITH order_previous_purchase_ts AS (
    SELECT
        o.order_id,
        o.order_purchase_timestamp,
        c.customer_unique_id,

        LAG(o.order_purchase_timestamp) OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY
                o.order_purchase_timestamp ASC,
                o.order_id ASC
        ) AS previous_purchase_timestamp

    FROM olist_staging.stg_orders AS o

    INNER JOIN olist_staging.stg_customers AS c
        ON o.customer_id = c.customer_id

    WHERE o.order_status = 'delivered'
),

order_gap_seconds AS (
    SELECT
        *,
        TIMESTAMPDIFF(
            SECOND,
            previous_purchase_timestamp,
            order_purchase_timestamp
        ) AS gap_seconds

    FROM order_previous_purchase_ts
),

gap_bucket AS (
    SELECT
        gap_seconds,

        CASE
            WHEN gap_seconds = 0 THEN '0秒'
            WHEN gap_seconds <= 60 THEN '1秒～60秒'
            WHEN gap_seconds <= 180 THEN '61秒～3分鐘'
            WHEN gap_seconds <= 600 THEN '3～10分鐘'
            WHEN gap_seconds <= 3600 THEN '10～60分鐘'
            WHEN gap_seconds <= 86400 THEN '1～24小時'
            ELSE '超過1天'
        END AS gap_group,

        CASE
            WHEN gap_seconds = 0 THEN 1
            WHEN gap_seconds <= 60 THEN 2
            WHEN gap_seconds <= 180 THEN 3
            WHEN gap_seconds <= 600 THEN 4
            WHEN gap_seconds <= 3600 THEN 5
            WHEN gap_seconds <= 86400 THEN 6
            ELSE 7
        END AS sort_key

    FROM order_gap_seconds

    WHERE gap_seconds IS NOT NULL
),

gap_group AS (
    SELECT
        gap_group,
        sort_key,
        COUNT(*) AS group_count,

        ROUND(
            COUNT(*) * 100.0
            / SUM(COUNT(*)) OVER (),
            3
        ) AS gap_pct

    FROM gap_bucket

    GROUP BY
        gap_group,
        sort_key
)

SELECT
    gap_group,
    group_count,
    gap_pct,

    ROUND(
        SUM(gap_pct) OVER (
            ORDER BY sort_key
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        2
    ) AS cum_pct

FROM gap_group

ORDER BY sort_key;