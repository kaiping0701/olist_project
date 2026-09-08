import json
import pandas as pd
import os
from typing import Literal
from pydantic import BaseModel
from openai import OpenAI
from sqlalchemy import create_engine

# 1. open ai 與 SQL連線
api_key = os.getenv("OPENAI_API_KEY")

if api_key is None:
    raise RuntimeError(
        "找不到 OPENAI_API_KEY"
    )

print("環境變數讀取成功")
client = OpenAI(api_key=api_key)


engine_staging = create_engine(
    "mysql+pymysql://root:a24967679@localhost:3306/"
    "olist_staging?charset=utf8mb4"
)

engine_mart = create_engine(
    "mysql+pymysql://root:a24967679@localhost:3306/"
    "olist_data_mart?charset=utf8mb4"
)

# 2. 1~5星分別隨機抽樣20筆 (共100筆)

sql = '''
WITH ranked_review AS(
    SELECT
        review_id,
        order_id,
        review_score,

        CONCAT_WS(
        ' ', 
        review_comment_title,
        review_comment_message
        ) AS review_comment_title_message,

        ROW_NUMBER() OVER(
            PARTITION BY review_score
            ORDER BY rand(100)) as rn


    FROM stg_reviews 
    WHERE 
        NULLIF(TRIM(review_comment_title), '') IS NOT NULL 
        OR
        NULLIF(TRIM(review_comment_message), '') IS NOT NULL 
)


SELECT 
    review_id,
    order_id,
    review_score,
    review_comment_title_message
FROM ranked_review
WHERE rn <= 20 
ORDER BY review_score ASC , rn ASC
'''
df = pd.read_sql(
    sql=sql,
    con=engine_staging
)
print("\n總筆數：", len(df))
print("\n各星等抽樣筆數：")
print(
    df["review_score"]
    .value_counts()
    .sort_index()
)

# 3. 約束 OpenAI輸出欄位
class ReviewResult(BaseModel):
    record_no: int
    review_translation_tw: str

    sentiment: Literal[
        "positive",
        "neutral",
        "mixed",
        "negative"
    ]

    t01_delivery_logistics: Literal[0, 1]
    t02_order_fulfillment: Literal[0, 1]
    t03_product_quality: Literal[0, 1]
    t04_product_consistency: Literal[0, 1]
    t05_packaging_protection: Literal[0, 1]
    t06_customer_service: Literal[0, 1]
    t07_price_transaction: Literal[0, 1]
    t08_platform_system: Literal[0, 1]

class BatchResult(BaseModel):
    results: list[ReviewResult]


# 4. 分類提示詞
PROMPT = '''
你是一位資深電商數據分析師。

你的任務是分析電商顧客評論，並依照指定規則完成評論翻譯、Sentiment 分類與 Topic 分類。

分類資料

每筆資料包含：
record_no
review_comment_title_message

record_no 是該筆評論的識別流水號。
你必須原樣回傳每一筆 record_no，不得修改、遺漏、重複或新增。

其中：

review_comment_title_message 已由系統完成組合。

請直接根據此欄位進行分析。

分析流程

請依序完成以下工作：

將 review_comment_title_message 翻譯成自然、流暢且符合台灣用語的繁體中文。
判斷一個 Sentiment。
判斷一個或多個 Topic。
分類原則

請嚴格遵守以下規則：

僅能根據 review_comment_title_message 判斷。
不得依據 review_score 或任何未提供資訊判斷。
不得自行推測評論未提及內容。
Topic 僅能標記評論中明確提及的業務面向。
若某個 Topic 無法明確確認，請輸出 0，不得猜測。
若評論沒有任何可辨識 Topic，則八個 Topic 全部輸出 0。
每筆評論只能有一個 Sentiment。
每筆評論可以有多個 Topic。
Topic 定義
T01 Delivery & Logistics（配送與物流）

商品如何送到。

包含：

配送速度
配送延遲
未收到商品
配送途中問題
物流服務
T02 Order Fulfillment（訂單履約）

訂單是否完整交付。

包含：

少件
缺件
錯件
缺貨
訂單未完整交付
T03 Product Quality（商品品質）

商品本身品質。

包含：

商品故障
品質不好
容易損壞
材質不好
功能異常
T04 Product Consistency（商品資訊一致性）

商品是否符合商品頁描述。

包含：

顏色不同
尺寸不同
規格不同
與照片不同
與商品描述不同
T05 Packaging & Protection（包裝與保護）

商品包裝是否妥善保護。

包含：

包裝破損
保護不足
包裝太薄
商品因包裝受損

注意：

只有評論明確提及包裝問題時才標記。

不得因商品損壞自行推論包裝有問題。

T06 Customer Service（客服與售後）

客服或賣家是否協助解決問題。

包含：

客服態度
客服回覆
售後服務
等待處理
退款
退貨
問題解決
T07 Price & Transaction（價格與交易）

交易成本是否合理。

包含：

商品價格
運費
付款
折扣
優惠
T08 Platform System（平台系統）

平台流程是否正常。

包含：

網站
APP
平台功能
系統
付款流程
發票
Sentiment 定義
positive

評論整體表達滿意。

幾乎沒有負面內容。

neutral

評論主要描述事實。

沒有明顯正面或負面情緒。

mixed

評論同時包含明顯正面與負面內容。

negative

評論整體表達不滿、抱怨、失望或批評。

幾乎沒有正面內容。

Sentiment 判斷原則

Sentiment 必須依據整體評論判斷。

不得依 Topic 個別判斷。

例如：

「配送很快，但是商品品質很差。」

Sentiment 應為：

mixed

record_no 必須與輸入資料完全一致。
每筆輸入都必須產生一筆結果，不得遺漏、重複或增加資料。
'''




# 4. 每20筆呼叫一次API

# 5. API 批次分類設定

batch_size = 20

MODEL_NAME = "gpt-5.4-nano"

# 單位：美元 / 1,000,000 tokens
INPUT_PRICE = 0.20
CACHED_INPUT_PRICE = 0.02
OUTPUT_PRICE = 1.25

total_input_tokens = 0
total_cached_tokens = 0
total_output_tokens = 0
total_cost_usd = 0

# 暫存每個批次的結果
# 全部批次成功後，再一次寫入 SQL
all_result_df = []


for start in range(0, len(df), batch_size):

    batch_df = (
        df.iloc[start:start + batch_size]
        .copy()
        .reset_index(drop=True)
    )

    # 使用全域流水號，例如：
    # 第一批 0～19
    # 第二批 20～39
    batch_df["record_no"] = range(
        start,
        start + len(batch_df)
    )

    input_data = batch_df[
        [
            "record_no",
            "review_comment_title_message"
        ]
    ].to_dict(orient="records")

    # 呼叫 OpenAI API
    response = client.responses.parse(
        model=MODEL_NAME,
        input=[
            {
                "role": "system",
                "content": PROMPT
            },
            {
                "role": "user",
                "content": json.dumps(
                    input_data,
                    ensure_ascii=False
                )
            }
        ],
        text_format=BatchResult
    )

    # ==============================
    # 1. 取得並計算 Token 成本
    # ==============================

    usage = response.usage

    if usage is None:
        raise ValueError(
            f"第 {start + 1}～"
            f"{start + len(batch_df)} 筆沒有 usage 資訊"
        )

    input_tokens = usage.input_tokens
    output_tokens = usage.output_tokens

    input_details = usage.input_tokens_details

    cached_tokens = (
        getattr(input_details, "cached_tokens", 0)
        if input_details is not None
        else 0
    )

    cached_tokens = cached_tokens or 0

    uncached_tokens = input_tokens - cached_tokens

    if uncached_tokens < 0:
        raise ValueError(
            "cached_tokens 不應大於 input_tokens"
        )

    batch_cost_usd = (
        uncached_tokens
        / 1_000_000
        * INPUT_PRICE

        + cached_tokens
        / 1_000_000
        * CACHED_INPUT_PRICE

        + output_tokens
        / 1_000_000
        * OUTPUT_PRICE
    )

    total_input_tokens += input_tokens
    total_cached_tokens += cached_tokens
    total_output_tokens += output_tokens
    total_cost_usd += batch_cost_usd

    # ==============================
    # 2. 解析 Structured Output
    # ==============================

    parsed = response.output_parsed

    if parsed is None:
        raise ValueError(
            f"第 {start + 1}～"
            f"{start + len(batch_df)} 筆："
            "模型沒有回傳可解析結果"
        )

    ai_df = pd.DataFrame(
        [
            result.model_dump()
            for result in parsed.results
        ]
    )

    # ==============================
    # 3. 驗證模型回傳資料
    # ==============================

    if len(ai_df) != len(batch_df):
        raise ValueError(
            f"第 {start + 1}～"
            f"{start + len(batch_df)} 筆："
            f"輸入 {len(batch_df)} 筆，"
            f"模型回傳 {len(ai_df)} 筆"
        )

    if ai_df["record_no"].duplicated().any():

        duplicated_record_no = (
            ai_df.loc[
                ai_df["record_no"].duplicated(
                    keep=False
                ),
                "record_no"
            ]
            .tolist()
        )

        raise ValueError(
            "模型回傳重複的 record_no："
            f"{duplicated_record_no}"
        )

    expected_record_no = set(
        batch_df["record_no"]
    )

    actual_record_no = set(
        ai_df["record_no"]
    )

    missing_record_no = (
        expected_record_no
        - actual_record_no
    )

    unexpected_record_no = (
        actual_record_no
        - expected_record_no
    )

    if missing_record_no or unexpected_record_no:
        raise ValueError(
            "模型回傳的 record_no 不一致。\n"
            f"缺少：{sorted(missing_record_no)}\n"
            f"額外：{sorted(unexpected_record_no)}"
        )

    # ==============================
    # 4. 接回原始資料
    # ==============================

    result_df = batch_df.merge(
        ai_df,
        on="record_no",
        how="inner",
        validate="one_to_one"
    )

    if len(result_df) != len(batch_df):
        raise ValueError(
            "資料合併後筆數不一致"
        )

    # record_no 只是暫時用於合併
    result_df = result_df.drop(
        columns="record_no"
    )

    # 固定欄位順序
    result_df = result_df[
        [
            "review_id",
            "order_id",
            "review_score",
            "review_comment_title_message",
            "review_translation_tw",
            "sentiment",
            "t01_delivery_logistics",
            "t02_order_fulfillment",
            "t03_product_quality",
            "t04_product_consistency",
            "t05_packaging_protection",
            "t06_customer_service",
            "t07_price_transaction",
            "t08_platform_system"
        ]
    ]

    # 暫存本批次，不立刻寫 SQL
    all_result_df.append(result_df)

    print(
        f"完成第 {start + 1}～"
        f"{start + len(batch_df)} 筆 | "
        f"Input：{input_tokens:,} | "
        f"Cached：{cached_tokens:,} | "
        f"Output：{output_tokens:,} | "
        f"成本：US${batch_cost_usd:.6f}"
    )


# ==============================
# 5. 全部成功後合併
# ==============================

final_result_df = pd.concat(
    all_result_df,
    ignore_index=True
)

if len(final_result_df) != len(df):
    raise ValueError(
        f"原始資料 {len(df)} 筆，"
        f"最終結果 {len(final_result_df)} 筆"
    )

# 最終主鍵完整性驗證
if final_result_df[
    ["review_id", "order_id"]
].duplicated().any():
    raise ValueError(
        "最終結果存在重複的 "
        "review_id + order_id"
    )


# ==============================
# 6. 寫入 SQL
# ==============================

final_result_df.to_sql(
    name="int_ai_sample",
    con=engine_mart,
    if_exists="append",
    index=False
)


print("\n========== 執行結果 ==========")
print(f"使用模型：{MODEL_NAME}")
print(f"完成筆數：{len(final_result_df):,}")
print(f"Input tokens：{total_input_tokens:,}")
print(
    f"Cached input tokens："
    f"{total_cached_tokens:,}"
)
print(f"Output tokens：{total_output_tokens:,}")
print(
    f"本次預估 API 成本："
    f"US${total_cost_usd:.6f}"
)
print("SQL 寫入：olist_data_mart.int_ai_sample")
print("==============================")