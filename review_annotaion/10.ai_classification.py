
import json
import os
from typing import Literal

import pandas as pd
from openai import OpenAI
from pydantic import BaseModel
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL


# ============================================================
# 0. 人工執行設定
# ============================================================

# 先跑 1,000 筆：設為 1000
# 後續跑完全部剩餘資料：改成 None
#
# 此數字代表「目標表累計筆數上限」，不是每次重跑新增幾筆。
# 例如目標表已有 650 筆、設定 1000，本次只會再跑 350 筆。
TARGET_TOTAL_ROWS: int | None = None

# 每次 API 呼叫處理幾筆評論。
BATCH_SIZE = 50

MODEL_NAME = "gpt-5.4-nano"

# 單位：美元 / 1,000,000 tokens
INPUT_PRICE = 0.20
CACHED_INPUT_PRICE = 0.02
OUTPUT_PRICE = 1.25

STAGING_SCHEMA = "olist_staging"
MART_SCHEMA = "olist_data_mart"
SOURCE_TABLE = "stg_reviews"
TARGET_TABLE = "int_ai_annotation"


# ============================================================
# 1. OpenAI 與 MySQL 連線
# ============================================================

api_key = os.getenv("OPENAI_API_KEY")
db_password = os.getenv("OLIST_DB_PASSWORD")

if not api_key:
    raise RuntimeError("找不到環境變數 OPENAI_API_KEY")

if not db_password:
    raise RuntimeError("找不到環境變數 OLIST_DB_PASSWORD")

client = OpenAI(api_key=api_key)

staging_url = URL.create(
    drivername="mysql+pymysql",
    username="root",
    password=db_password,
    host="localhost",
    port=3306,
    database=STAGING_SCHEMA,
    query={"charset": "utf8mb4"},
)

mart_url = URL.create(
    drivername="mysql+pymysql",
    username="root",
    password=db_password,
    host="localhost",
    port=3306,
    database=MART_SCHEMA,
    query={"charset": "utf8mb4"},
)

engine_staging = create_engine(staging_url, pool_pre_ping=True)
engine_mart = create_engine(mart_url, pool_pre_ping=True)

print("OpenAI API Key 與資料庫密碼讀取成功")


# ============================================================
# 2. 檢查 target，計算本次應處理筆數
# ============================================================

with engine_mart.connect() as conn:
    target_exists = conn.execute(
        text(
            """
            SELECT COUNT(*)
            FROM information_schema.tables
            WHERE table_schema = :schema_name
              AND table_name = :table_name
            """
        ),
        {
            "schema_name": MART_SCHEMA,
            "table_name": TARGET_TABLE,
        },
    ).scalar_one()

    if target_exists == 0:
        raise RuntimeError(
            f"找不到目標表 {MART_SCHEMA}.{TARGET_TABLE}，請先執行 CREATE TABLE"
        )

    completed_before = conn.execute(
        text(f"SELECT COUNT(*) FROM `{TARGET_TABLE}`")
    ).scalar_one()

with engine_staging.connect() as conn:
    total_valid_reviews = conn.execute(
        text(
            f"""
            SELECT COUNT(*)
            FROM `{SOURCE_TABLE}`
            WHERE NULLIF(TRIM(review_comment_title), '') IS NOT NULL
               OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
            """
        )
    ).scalar_one()

remaining_reviews = max(total_valid_reviews - completed_before, 0)

if TARGET_TOTAL_ROWS is None:
    rows_to_process = remaining_reviews
else:
    if TARGET_TOTAL_ROWS < 0:
        raise ValueError("TARGET_TOTAL_ROWS 不可小於 0")

    rows_to_process = min(
        max(TARGET_TOTAL_ROWS - completed_before, 0),
        remaining_reviews,
    )

print(f"有效評論總數：{total_valid_reviews:,}")
print(f"目標表既有筆數：{completed_before:,}")
print(f"本次預計分類：{rows_to_process:,}")

if rows_to_process == 0:
    print("目前已達設定上限，沒有需要處理的資料。")
    raise SystemExit(0)


# ============================================================
# 3. 讀取尚未分類的評論
# ============================================================

source_sql = f"""
SELECT
    s.review_id,
    s.order_id,
    s.review_score,
    CONCAT_WS(
        ' ',
        NULLIF(TRIM(s.review_comment_title), ''),
        NULLIF(TRIM(s.review_comment_message), '')
    ) AS review_comment_title_message
FROM `{STAGING_SCHEMA}`.`{SOURCE_TABLE}` AS s
LEFT JOIN `{MART_SCHEMA}`.`{TARGET_TABLE}` AS t
    ON s.review_id = t.review_id
   AND s.order_id = t.order_id
WHERE (
       NULLIF(TRIM(s.review_comment_title), '') IS NOT NULL
    OR NULLIF(TRIM(s.review_comment_message), '') IS NOT NULL
)
AND t.review_id IS NULL
ORDER BY s.review_id, s.order_id
LIMIT {rows_to_process}
"""

df = pd.read_sql(source_sql, con=engine_staging)

if len(df) != rows_to_process:
    raise ValueError(
        f"預計讀取 {rows_to_process:,} 筆，實際讀取 {len(df):,} 筆"
    )

if df[["review_id", "order_id"]].duplicated().any():
    raise ValueError("來源資料存在重複的 review_id + order_id")

print(f"成功讀取待分類資料：{len(df):,} 筆")


# ============================================================
# 4. 約束 OpenAI Structured Output
# ============================================================

class ReviewResult(BaseModel):
    record_no: int
    review_translation_tw: str
    sentiment: Literal["positive", "neutral", "mixed", "negative"]
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


# ============================================================
# 5. v3 分類提示詞
# ============================================================

PROMPT = '''你是電商顧客評論分析師。

請根據每筆資料的 review_comment_title_message，完成：

1. 翻譯成自然、流暢、符合台灣用語的繁體中文
2. 判斷整則評論的 sentiment
3. 判斷評論涉及的 Topic

一、共同規則

1. 只能根據 review_comment_title_message 判斷，不得使用 review_score 或其他未提供的資訊。

2. 不得推測評論未明確提及的內容、原因、背景或責任歸屬。

3. Topic 代表評論實際談論的業務面向，不代表該面向一定是負面。

4. 一則評論可以同時包含多個 Topic。

5. sentiment 只能有一個，代表整則評論的整體情緒與語意傾向。

6. 若評論沒有明確涉及某個 Topic，該 Topic 輸出 0。

7. positive、neutral、mixed、negative 評論都可以標記 Topic。

8. 必須逐筆處理所有輸入資料，並保留每筆原始 record_no。

9. 不得遺漏、重複、修改或新增任何輸入資料。

10. 評論不需要說明問題產生的原因，才可以標記 Topic。

只要評論直接描述的對象、行為、狀態或結果符合某個 Topic 的定義，就應標記該 Topic。

例如：

* 「我沒有收到商品」直接符合未收到商品，標記 T01
* 「我訂兩件，只收到一件」直接符合缺件，標記 T02
* 「商品無法使用」直接符合功能異常，標記 T03
* 「包裝破掉了」直接符合包裝問題，標記 T05

11. 不得從一個已明確描述的問題，自行推論評論未提及的其他 Topic。

例如：

* 商品損壞，不得自行推論是包裝造成
* 未收到商品，不得自行推論是商家缺貨
* 要求退款，不得自行推論客服態度不好
* 收到錯誤商品，不得自行推論商品頁資訊錯誤

12. 不得僅因評論出現「商品」、「產品」、「問題」、「不好」、「失望」、「退貨」、「退款」或「換貨」等泛用詞語，就自動標記 Topic。

必須根據評論實際描述的對象、狀況與業務面向判斷。

13. Topic 與 sentiment 必須分開判斷。

* Topic 判斷評論在談論什麼業務面向
* sentiment 判斷評論整體是正面、中性、正負混合或負面

不得因評論是 negative 就任意增加 Topic，也不得因評論沒有情緒詞就忽略已明確提及的 Topic。

二、Topic 定義

T01 Delivery & Logistics（配送與物流）

核心問題：

商品如何送到，以及顧客是否順利收到商品。

評論明確談論商品配送、物流過程、配送速度或收貨狀況時，標記 T01=1。

包含：

* 配送速度
* 配送很快
* 配送很慢
* 配送延遲
* 超過預計到貨時間
* 尚未收到商品
* 完全未收到商品
* 物流追蹤
* 配送途中發生問題
* 配送人員或物流服務
* 商品被送到錯誤地址
* 商品顯示已送達，但顧客實際未收到

以下情況不標記 T01：

* 收到錯誤商品，但沒有談論配送問題
* 收到商品數量不足，但沒有談論配送問題
* 商品品質不好
* 商品與照片或描述不符
* 包裝破損，但沒有談論物流過程

不得因其他問題發生在收貨之後，就自行推論為配送問題。

T02 Order Fulfillment（訂單履約）

核心問題：

商家實際交付的商品，是否符合顧客原本下單的內容，以及訂單是否被完整履行。

T02 是訂單執行、揀貨或出貨內容錯誤。

包含：

* 顧客訂購某商品，卻收到另一個商品
* 顧客訂購某尺寸，卻收到其他尺寸
* 顧客訂購某顏色，卻收到其他顏色
* 顧客訂購某規格或型號，卻收到其他規格或型號
* 收到錯誤品項
* 收到錯誤類別的商品
* 少件
* 缺件
* 數量不足
* 只收到部分商品
* 訂購多件商品，但沒有全部收到
* 商家無法提供顧客已下單的商品
* 缺貨導致訂單取消或無法完整履行

只有在評論明確表示以下任一情況時，才標記 T02=1：

1. 收到的商品與顧客下單的內容不同
2. 訂單內容沒有被完整交付
3. 已下單商品因缺貨或商家原因無法提供

以下情況不標記 T02：

* 單純配送延遲
* 單純尚未收到整筆訂單
* 商品品質不好
* 商品故障或損壞
* 商品是假貨，但沒有表示收到完全不同的品項
* 實際商品與廣告、照片或商品頁描述不同
* 商品尺寸不合適，但沒有表示商家寄錯尺寸
* 顧客自己選錯商品或規格

T04 Product Consistency（商品資訊一致性）

核心問題：

實際收到的商品，是否符合商家在廣告、照片、網站、商品頁、描述或功能宣稱中提供的資訊。

T04 是商家提供的商品資訊與實際商品不一致。

包含：

* 商品外觀與商品照片不同
* 商品顏色與廣告或照片不同
* 商品尺寸與商品頁標示不同
* 商品規格與商品頁描述不同
* 商品功能與廣告或商品頁宣稱不同
* 商品與網站或商品描述不一致
* 商品材質與頁面描述不一致
* 商家宣稱為正品，但實際是假貨
* 商品品牌、真偽或授權狀態與商家宣稱不一致
* 廣告宣稱是全新商品，但實際收到疑似二手商品
* 商品圖片或描述具有誤導性

只有當評論明確提到以下資訊來源之一，或明確表達商家宣稱與實物不一致時，才標記 T04=1：

* 廣告
* 照片
* 圖片
* 網站
* 商品頁
* 商品描述
* 商品規格標示
* 功能宣稱
* 正品宣稱
* 品牌或真偽資訊

假貨或仿冒品規則：

* 「宣稱是正品，但收到假貨」→ T04=1
* 「商品是假貨，品質也很差」→ T03=1、T04=1
* 不得僅因評論出現「假貨」就標記 T02
* 除非評論明確表示收到完全不同的商品，否則假貨不屬於 T02

T02 與 T04 的核心區分：

* T02：實際收到的商品與顧客下單內容比較
* T04：實際收到的商品與商家頁面或宣稱比較

範例：

* 「我訂紅色，卻寄來藍色」
  → T02=1，T04=0

* 「網站照片是紅色，但收到的是藍色」
  → T02=0，T04=1

* 「我訂紅色，收到藍色，而且網站照片也是紅色」
  → T02=1，T04=1

* 「商品頁標示 M 號，但實際尺寸與標示不符」
  → T02=0，T04=1

* 「我訂 M 號，但商家寄來 L 號」
  → T02=1，T04=0

* 「尺寸不適合我」
  → T02=0，T04=0

* 「商品尺寸不正確」
  → 若沒有說明是寄錯尺寸，也沒有說明與商品頁標示不符，T02=0、T04=0

T03 Product & Quality（商品與品質）

核心問題：

評論是否直接評價商品本身、商品品質、功能、做工或實際使用體驗。

評論明確評價商品本身時，標記 T03=1。

包含：

* 商品整體很好或很差
* 商品品質
* 商品材質
* 商品做工
* 商品功能
* 商品效能
* 商品耐用性
* 商品故障
* 商品無法使用
* 商品功能異常
* 商品損壞
* 商品瑕疵
* 商品破裂
* 商品有刮痕
* 商品使用體驗
* 商品是否實用
* 商品是否符合需求
* 對商品本身的喜愛、不滿或整體評價
* 假貨造成的商品品質問題

正面、中性與負面的商品評價都屬於 T03。

例如：

* 「商品品質很好」→ T03=1
* 「這個商品很普通」→ T03=1
* 「我很喜歡這個商品」→ T03=1
* 「商品無法正常使用」→ T03=1
* 「品質很差」→ T03=1

以下情況不標記 T03：

* 只提到未收到商品
* 只提到配送速度
* 只提到收到錯件
* 只提到缺件或數量不足
* 只提到商品資訊與照片不符
* 只提到包裝問題
* 只提到客服或退款處理
* 只提到價格或付款問題

不得僅因評論出現「商品」或「產品」就標記 T03。

T05 Packaging & Protection（包裝與保護）

核心問題：

評論是否談論包裝、包裹外觀或商品在運送過程中的保護程度。

包含：

* 包裝完整
* 包裝破損
* 包裝太薄
* 包裝不良
* 包裝不牢固
* 包裝方式很好
* 商品保護充分
* 商品保護不足
* 缺少保護材料
* 包裹外觀損壞
* 商品因包裝問題受損

不得因商品損壞或故障，就自行推論包裝有問題。

分類規則：

* 商品本身損壞或故障，但沒有提到包裝
  → T03=1，T05=0

* 包裝破損，但沒有表示商品本身受損
  → T03=0，T05=1

* 商品明確因包裝或保護不足而損壞
  → T03=1，T05=1

* 包裝很好，商品也完好
  → T05=1；若同時評價商品本身，也可標記 T03=1

T06 Customer Service & After-sales（客服與售後）

核心問題：

評論是否明確談論客服、賣家溝通、申訴或售後處理過程。

包含：

* 客服態度
* 賣家態度
* 客服回覆
* 賣家回覆
* 客服沒有回覆
* 聯絡客服
* 聯絡賣家
* 溝通問題
* 申訴
* 退款處理
* 退貨處理
* 換貨處理
* 售後服務
* 等待客服或賣家處理
* 問題是否被解決
* 客服或賣家拒絕處理
* 客服成功協助解決問題

只有當評論明確談論服務、溝通或處理過程時，才標記 T06=1。

以下情況不標記 T06：

* 「我要退貨」，但沒有談論退貨處理或客服
* 「我要求退款」，但沒有談論退款處理或客服
* 「我打算換貨」，但沒有談論換貨處理或客服
* 單純等待商品
* 單純配送延遲
* 單純表示不滿，但沒有提到客服或賣家溝通

不得因評論出現退貨、退款或換貨，就自動推論 T06。

T07 Price & Transaction（價格與交易）

核心問題：

評論是否明確談論價格、費用、優惠或一般付款交易。

包含：

* 商品價格
* 價格便宜
* 價格昂貴
* 價格合理
* 商品划算
* 性價比
* 運費
* 額外費用
* 折扣
* 優惠
* 優惠券
* 付款
* 扣款
* 重複扣款
* 付款失敗
* 退款金額
* 交易費用
* 分期付款

若評論只是一般價格或付款交易問題，且沒有明確提到平台、網站、APP 或系統，標記 T07，不標記 T08。

T08 Platform System（平台系統）

核心問題：

評論是否明確談論電商平台本身的網站、APP、系統或平台操作流程。

包含：

* 網站
* APP
* 平台功能
* 系統錯誤
* 系統異常
* 網站操作
* APP 操作
* 結帳流程
* 平台付款流程
* 平台無法完成付款
* 訂單頁面
* 帳號功能
* 發票
* 發票資訊
* 平台通知
* 平台功能異常

分類規則：

* 明確提到平台、網站、APP 或系統造成付款問題
  → T08=1；若同時談論付款交易，也可標記 T07=1

* 只有一般付款或扣款問題，沒有提到平台或系統
  → T07=1，T08=0

* 只有商品、配送、客服或包裝問題
  → 不標記 T08

不得因評論是在電商平台上留下，就自行標記 T08。

三、Sentiment 定義

Sentiment 必須根據整則評論的整體語意判斷。

不得只依照單一正面詞、負面詞、標點符號或情緒詞判斷。

評論不需要出現「生氣」、「失望」、「不滿」等情緒詞，才可以判定為 negative。

評論直接描述的事件或結果本身，也可以具有明確的正面或負面意義。

positive

整體表達滿意、喜愛、稱讚、推薦或正面評價，而且沒有具有實質意義的負面內容。

包含：

* 稱讚商品
* 稱讚品質
* 稱讚配送
* 稱讚包裝
* 稱讚客服
* 表示喜歡、滿意或推薦
* 表示商品符合期待

範例：

* 「商品很好，我很喜歡」→ positive
* 「配送很快，包裝也很完整」→ positive
* 「品質不錯，值得購買」→ positive

neutral

主要是客觀資訊、一般詢問、無明顯好壞評價的描述，且沒有明確對顧客有利或不利的重要結果。

包含：

* 一般詢問
* 單純確認資訊
* 無評價的客觀描述
* 無法判斷正負傾向的陳述

範例：

* 「請問有黑色嗎？」→ neutral
* 「商品今天收到」→ neutral
* 「這個商品是 220V」→ neutral
* 「我購買了兩件」→ neutral

以下情況不得因為沒有情緒詞就判定為 neutral：

* 未收到商品
* 配送明顯延遲
* 收到錯誤商品
* 商品缺件
* 數量不足
* 商品故障
* 商品損壞
* 商品無法使用
* 商品是假貨
* 包裝破損
* 被重複扣款
* 客服未處理問題

以上情況本身就是明確的不利結果，通常應判定為 negative。

mixed

同一則評論同時包含具有實質意義的正面內容與負面內容。

正面與負面內容都必須是評論中的重要資訊，不能只有輕微語氣詞。

範例：

* 「商品很好，但是配送非常慢」→ mixed
* 「包裝很完整，但商品無法使用」→ mixed
* 「客服態度很好，不過退款等了很久」→ mixed
* 「品質不錯，可是寄錯顏色」→ mixed

以下情況不一定是 mixed：

* 「商品還可以，但沒有特別驚喜」
  → 如果整體只是普通評價，可判定 neutral

* 「雖然等了一下，但整體很滿意」
  → 若負面內容很輕微，整體仍可判定 positive

* 「商品看起來不錯，但根本不能用」
  → 主要負面結果嚴重，可判定 negative

必須依正面與負面內容的重要性判斷，而不是看到「但是」、「不過」就自動判定 mixed。

negative

整體表達不滿、抱怨、失望、批評、不推薦，或明確描述對顧客不利的失敗結果。

即使評論沒有出現情緒詞，只要明確描述重要的不利結果，也應判定為 negative。

包含：

* 未收到商品
* 商品嚴重延遲
* 收到錯誤商品
* 商品缺件或數量不足
* 商品故障
* 商品損壞
* 商品無法使用
* 商品品質差
* 商品是假貨
* 包裝破損或保護不足
* 客服沒有回覆或拒絕處理
* 退款或退貨處理失敗
* 付款或扣款發生問題
* 明確表示不滿、失望或不推薦

範例：

* 「我沒有收到商品」→ negative
* 「訂了兩件，只收到一件」→ negative
* 「商品完全不能使用」→ negative
* 「寄來的不是我訂的商品」→ negative
* 「客服一直沒有回覆」→ negative
* 「品質很差，不推薦」→ negative

四、Sentiment 判斷優先原則

依照以下順序判斷：

1. 先確認評論是否包含明確的不利結果或負面評價。

2. 再確認評論是否同時包含具有實質意義的正面內容。

3. 若同時有重要正面與重要負面內容，判定為 mixed。

4. 若負面內容明顯主導，或存在嚴重失敗結果，判定為 negative。

5. 若只有正面內容，且沒有重要負面內容，判定為 positive。

6. 只有在評論主要是客觀資訊、詢問或無法判斷好壞的陳述時，才判定為 neutral。

不得將「沒有情緒詞」直接等同於 neutral。

'''


# ============================================================
# 6. 欄位與成本累計設定
# ============================================================

OUTPUT_COLUMNS = [
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
    "t08_platform_system",
]

total_input_tokens = 0
total_cached_tokens = 0
total_output_tokens = 0
total_cost_usd = 0.0
api_processed_rows = 0
committed_rows = 0


# ============================================================
# 7. 分批分類、驗證、立即寫入 target
# ============================================================

try:
    for start in range(0, len(df), BATCH_SIZE):
        batch_df = (
            df.iloc[start : start + BATCH_SIZE]
            .copy()
            .reset_index(drop=True)
        )

        # record_no 只用於將 AI 結果安全接回原始資料。
        batch_df["record_no"] = range(len(batch_df))

        input_data = batch_df[
            ["record_no", "review_comment_title_message"]
        ].to_dict(orient="records")

        response = client.responses.parse(
            model=MODEL_NAME,
            input=[
                {"role": "system", "content": PROMPT},
                {
                    "role": "user",
                    "content": json.dumps(input_data, ensure_ascii=False),
                },
            ],
            text_format=BatchResult,
        )

        # ----------------------------------------------------
        # 7.1 計算本批 API 成本
        # ----------------------------------------------------

        usage = response.usage

        if usage is None:
            raise ValueError("API 回應沒有 usage 資訊")

        input_tokens = usage.input_tokens
        output_tokens = usage.output_tokens
        input_details = usage.input_tokens_details

        cached_tokens = (
            getattr(input_details, "cached_tokens", 0)
            if input_details is not None
            else 0
        ) or 0

        uncached_tokens = input_tokens - cached_tokens

        if uncached_tokens < 0:
            raise ValueError("cached_tokens 不應大於 input_tokens")

        batch_cost_usd = (
            uncached_tokens / 1_000_000 * INPUT_PRICE
            + cached_tokens / 1_000_000 * CACHED_INPUT_PRICE
            + output_tokens / 1_000_000 * OUTPUT_PRICE
        )

        # API 回應成功時，成本就已經產生，因此先計入。
        total_input_tokens += input_tokens
        total_cached_tokens += cached_tokens
        total_output_tokens += output_tokens
        total_cost_usd += batch_cost_usd
        api_processed_rows += len(batch_df)

        # ----------------------------------------------------
        # 7.2 解析與驗證模型輸出
        # ----------------------------------------------------

        parsed = response.output_parsed

        if parsed is None:
            raise ValueError("模型沒有回傳可解析結果")

        ai_df = pd.DataFrame(
            [item.model_dump() for item in parsed.results]
        )

        expected_record_no = set(batch_df["record_no"].tolist())
        actual_record_no = (
            set(ai_df["record_no"].tolist())
            if not ai_df.empty
            else set()
        )

        if len(ai_df) != len(batch_df):
            raise ValueError(
                f"輸入 {len(batch_df)} 筆，模型回傳 {len(ai_df)} 筆"
            )

        if ai_df["record_no"].duplicated().any():
            raise ValueError("模型回傳重複的 record_no")

        if expected_record_no != actual_record_no:
            raise ValueError(
                "模型回傳的 record_no 不一致；"
                f"缺少={sorted(expected_record_no - actual_record_no)}，"
                f"額外={sorted(actual_record_no - expected_record_no)}"
            )

        # ----------------------------------------------------
        # 7.3 接回原始資料並立即寫入 SQL
        # ----------------------------------------------------

        result_df = batch_df.merge(
            ai_df,
            on="record_no",
            how="inner",
            validate="one_to_one",
        ).drop(columns="record_no")

        result_df = result_df[OUTPUT_COLUMNS]

        with engine_mart.begin() as conn:
            result_df.to_sql(
                name=TARGET_TABLE,
                con=conn,
                if_exists="append",
                index=False,
                method="multi",
            )

        committed_rows += len(result_df)

        print(
            f"已提交 {committed_rows:,}/{len(df):,} 筆 | "
            f"本批成本 US${batch_cost_usd:.6f} | "
            f"本次累計 US${total_cost_usd:.6f}"
        )

finally:
    # 即使中途發生錯誤，也輸出本次已產生的成本資訊。
    print("\n========== 本次執行摘要 ==========")
    print(f"使用模型：{MODEL_NAME}")
    print(f"API 已處理筆數：{api_processed_rows:,}")
    print(f"SQL 成功寫入筆數：{committed_rows:,}")
    print(f"Input tokens：{total_input_tokens:,}")
    print(f"Cached input tokens：{total_cached_tokens:,}")
    print(f"Output tokens：{total_output_tokens:,}")
    print(f"本次預估 API 成本：US${total_cost_usd:.6f}")

    if api_processed_rows > 0:
        average_cost_per_row = total_cost_usd / api_processed_rows
        estimated_full_cost = average_cost_per_row * total_valid_reviews

        print(f"平均每筆成本：US${average_cost_per_row:.8f}")
        print(
            f"依本次平均估計 {total_valid_reviews:,} 筆全量成本："
            f"US${estimated_full_cost:.2f}"
        )

    print(f"SQL 寫入：{MART_SCHEMA}.{TARGET_TABLE}")
    print("==================================")


# ============================================================
# 8. 最終筆數確認
# ============================================================

with engine_mart.connect() as conn:
    completed_after = conn.execute(
        text(f"SELECT COUNT(*) FROM `{TARGET_TABLE}`")
    ).scalar_one()

expected_after = completed_before + committed_rows

if completed_after != expected_after:
    raise ValueError(
        f"目標表筆數異常：預期 {expected_after:,}，"
        f"實際 {completed_after:,}"
    )

print(f"目標表目前累計：{completed_after:,} 筆")