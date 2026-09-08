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
            ORDER BY rand(200   )) as rn


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
你是電商顧客評論分析師。

請根據每筆資料的 review_comment_title_message，完成：

1. 翻譯成自然、流暢、符合台灣用語的繁體中文
2. 判斷整則評論的 sentiment
3. 判斷評論涉及的 Topic

一、共同規則

1. 只能根據 review_comment_title_message 判斷，不得使用 review_score 或其他未提供資訊。
2. 不得推測評論未提及的內容。
3. Topic 代表評論正在談論的業務面向，不代表該面向一定是負面。
4. 一則評論可以同時包含多個 Topic。
5. sentiment 只能有一個，代表整則評論的整體情緒。
6. 若評論沒有明確涉及某個 Topic，該 Topic 輸出 0。
7. 正面、中性與負面評論都可以標記 Topic。
8. 必須逐筆處理所有輸入資料，保留每筆原始 record_no。
9. 不得遺漏、重複、修改或新增任何輸入資料。

二、Topic 定義

T01 Delivery & Logistics（配送與物流）

評論談論商品如何送到、配送過程或收貨狀況。

包含：

- 配送速度
- 配送延遲
- 配送很快或很慢
- 未收到商品
- 物流追蹤
- 配送途中問題
- 物流服務

T02 Order Fulfillment（訂單履約）

評論談論實際交付的商品內容，是否符合訂購的內容與數量。

包含：

- 少件、缺件
- 錯件或收到錯誤商品
- 缺貨
- 數量不足
- 只收到部分商品
- 訂單未完整交付

單純配送延遲或尚未收到商品，不標記 T02。

T03 Product & Quality（商品與品質）

評論明確評價商品本身、商品品質或使用體驗時標記為 1，不論評價正面、負面或中性。

包含：

- 商品品質、材質、做工
- 商品功能、耐用性
- 商品故障、損壞或瑕疵
- 對商品的喜愛、不滿或整體評價

若評論只是談論未收到商品、收到錯件、商品資訊不符或包裝問題，且沒有評價商品本身，則標記為 0。

不得僅因評論出現「商品」或「產品」就標記 T03。

T04 Product Consistency（商品資訊一致性）

評論談論實際商品是否符合網站、照片、商品頁面或原本提供的資訊。

包含：

- 顏色不同
- 尺寸不同
- 規格或型號不同
- 外觀與照片不同
- 商品與描述不同
- 實物與網站資訊不一致

T05 Packaging & Protection（包裝與保護）

評論明確談論包裝、包裹外觀或商品保護程度。

包含：

- 包裝完整或破損
- 包裝太薄或不良
- 保護不足
- 商品因包裝問題受損

只有評論明確提及包裝或保護時，才標記 T05。

不得因商品損壞自行推論包裝有問題。

若商品本身損壞或故障，標記 T03。

若評論明確指出商品因包裝或保護不足而損壞，則 T03 與 T05 都標記為 1。

T06 Customer Service & After-sales（客服與售後）

評論談論客服、賣家溝通或售後處理。

包含：

- 客服或賣家態度
- 客服或賣家回覆
- 聯絡客服
- 申訴
- 退款、退貨或換貨
- 售後服務
- 等待客服或賣家處理
- 問題解決

單純等待商品或配送延遲，不標記 T06。

T07 Price & Transaction（價格與交易）

評論談論價格、費用或付款交易。

包含：

- 商品價格
- 價格便宜、昂貴或划算
- 運費
- 折扣與優惠
- 付款
- 交易費用

T08 Platform System（平台系統）

評論談論電商平台本身的網站、APP、系統或平台流程。

包含：

- 網站或 APP
- 平台功能
- 系統錯誤
- 網站操作
- 結帳流程
- 平台付款流程
- 發票
- 平台功能異常

若只是一般付款或交易問題，但沒有明確提到平台或系統，標記 T07，不標記 T08。

三、Sentiment 定義

positive：

整體表達滿意、喜愛、稱讚或正面評價，且沒有重要的負面內容。

neutral：

主要描述事實、狀態或資訊，沒有明確正面或負面情緒。

mixed：

同時包含具有實質意義的正面與負面內容。

negative：

整體表達不滿、抱怨、失望、批評或不推薦，且負面內容主導整體語意。

Sentiment 必須依據整則評論的整體語意判斷，不得只根據單一正面詞或負面詞判斷。

單純描述商品、收貨、配送或包裹狀態，若沒有明確情緒，判定為 neutral。

若評論同時包含實質正面與負面內容，判定為 mixed。

若評論表達抱怨、失望、不滿、批評或不推薦，且負面內容主導整體語意，判定為 negative。
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
    name="int_ai_sample_v2",
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