## 0. 目的與最終架構

撰寫好的文件的本質: 我如何把混亂、粒度不一的資料，根據分析目的轉化成可靠的、可重複分析的資料模型
也就是展現資料建模決策能力。



根據分析需求建構資料倉儲，規劃三層架構以支援後續分析。
1. olist_stging: 統一資料型態，資料理解，清理stg_orders邏輯錯誤
2. olist_data_mart: 根據分析需求建構star schema架構
3. olist_analysis_mart: 根據分析需求建構對應的分析表




### 資料倉儲設計需求




### 從data_understanding 到資料倉儲的設計決策


問題 -> 處理方式Mapping 





### Grain設計







### Data Mart架構設計

    ### 1. olist_staging: 




    ### 2. olist_data_mart: 


### 7. order_event定義問題

#### 7.1 每個customer的order gap分佈檢查
    - 首先篩選delivered訂單，計算每一列訂單與前一筆訂單的gap，並且列用顧客識別鍵，計算出每個顧客每列order
        前一筆order的gap，然後排除首購訂單(因為沒有gap)
    - 並且檢查gap分別落在哪些區間內  


| 訂單時間間隔 | 訂單數 | 占比（%） | 累積占比（%） |
|---|---:|---:|---:|
| 0 秒 | 267 | 8.558 | 8.56 |
| 1～60 秒 | 456 | 14.615 | 23.17 |
| 61 秒～3 分鐘 | 19 | 0.609 | 23.78 |
| 3～10 分鐘 | 41 | 1.314 | 25.10 |
| 10～60 分鐘 | 68 | 2.179 | 27.28 |
| 1～24 小時 | 71 | 2.276 | 29.55 |
| 超過 1 天 | 2,198 | 70.449 | 100.00 |

可以看到資料集存在同一個顧客，在很短的order purchase timestamp 間隔下，下單多筆order_id。  
而這些訂單可能來自於同一個購買行為，例如：
    - 同一個顧客在短時間分別向不同賣家下單
    - 平台因為拆分機制產生多筆訂單  

又因為本專案主要分析的是留存問題，如果將每個order_id當成一次獨立購買事件，去計算retention指標會導致，高估留存率的問題，所以必須思考重新定義什麼是一個order_evnet。  
並且根據上述表格，在3120筆非首購的delivered訂單間隔中，有723筆(23.17%)發生於前一筆訂單後60秒內。因此本專案將order event定義為：每位顧客在0~60秒間下單多筆order_id的情況下合併成一筆order event。     
所以後續在資料倉儲內建構map_order_to_order_event做對照表。


#### 7.2 在資料倉儲利用rolling-gap邏輯建構map_order_to_event表

**如何判斷同一個顧客的一連串訂單是否屬於同一次購買行為？**  
Rolling gap: 目前訂單與上一筆訂單的時間差(非比較第一筆)  
當顧客的一連串訂單gap<=60秒時，就會將這些訂單識為同一筆event，並且gap>60秒時將那筆order識為下一筆order_event並且根據相同的邏輯計算是否屬於同一連串event  
  
**為何需要建構order_id到order_event的映射表？**  
因為兩張表的grain不同：  
- orders: order_id  
- fact_delivered_order_event: order_event_key 一次顧客購買事件一列  
  
同一個顧客在同一個order_event可能會產生多個order_id  
代表： order_event 與 order_id 關聯是 (一對多)  
所以需要一張明確的映射表，記錄每一個order_id屬於哪一個order_event
  
**map表案例(grain:order_id):**  
| customer_unique_id | order_id | order_purchase_ts | gap_seconds | event_id |
| --- | --- | --- | --- | --- |
| c001 | o001 | 2016-01-01 10:00:00 | NULL | E01 |
| c001 | o002 | 2016-01-01 10:00:20 | 20 | E01 |
| c001 | o003 | 2016-01-01 10:00:40 | 20 | E01 |
| c001 | o004 | 2016-01-01 10:12:00 | 680 | E02 |
| c001 | o005 | 2016-01-01 10:12:50 | 50 | E02 |
  
  
**SQL計算邏輯**
1. 篩選order表delivered訂單
2. 使用LAG函數，分區每個customer_uniqeu_id，利用puchase_ts和order_id升序排序(利用order_id排序的理由是確保每次執行的結果當是相同的)，計算每筆order的前一筆purchase_ts  
```sql 
LAG(order_purchase_timestamp,1) OVER(PARTITION BY customer_unique_id
                                     ORDER BY order_purchase_timestamp ASC, order_id ASC) as previous_purchase_ts
```
  
3. 計算gap_seconds
```sql 
    TIMESTAMPDIFF(second, previous_purchase_ts, order_purchase_timestamp) as gap_seconds
```

4. 計算new_event_flag  
```sql 
CASE WHEN 
    gap_seconds IS Null THEN 1 
    gap_seconds <= 60 THEN 0 
ELSE 1
END AS new_event_flag
```  
| customer_unique_id | order_id | order_purchase_ts | gap_seconds | new_event_falg|
| --- | --- | --- | --- | --- |
| c001 | o001 | 2016-01-01 10:00:00 | NULL | 1 |
| c001 | o002 | 2016-01-01 10:00:20 | 20 | 0 |
| c001 | o003 | 2016-01-01 10:00:40 | 20 | 0 |
| c001 | o004 | 2016-01-01 10:12:00 | 680 | 1 |
| c001 | o005 | 2016-01-01 10:12:50 | 50 | 0 |
**new_event_falg=1就代表新的一筆event開始了而0就代表屬於上面的event**
  
5. 計算每位顧客的local_event_key
```sql 
SUM(new_event_flag) OVER(PARTITION BY customer_unique_id 
                         ORDER BY order_purchase_timestamp ASC, order_id ASC
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) 
                         as local_event_id

```  
| customer_unique_id | order_id | order_purchase_ts | gap_seconds | new_event_falg | local_event_id |
| --- | --- | --- | --- | --- | --- |
| c001 | o001 | 2016-01-01 10:00:00 | NULL | 1 | 1 |
| c001 | o002 | 2016-01-01 10:00:20 | 20 | 0 | 1 |
| c001 | o003 | 2016-01-01 10:00:40 | 20 | 0 | 1 |
| c001 | o004 | 2016-01-01 10:12:00 | 680 | 1 | 2 |
| c001 | o005 | 2016-01-01 10:12:50 | 50 | 0 | 2 |
  
6. 利用local_event_id得出全域order_event_key  

```sql
DENSE_RANK() OVER(ORDER BY customer_unique_id ASC,
                  local_event_id ASC) as order_event_key
```  
| customer_unique_id | order_id | order_purchase_ts | order_previous_purchase_ts | gap_seconds | new_event_flag | local_event_id | order_event_key |
| --- | --- | --- | --- | --- | --- | --- | --- |
| c001 | o001 | 2016-01-01 10:00:00 | NULL | NULL | 1 | 1 | 1 |
| c001 | o002 | 2016-01-01 10:00:20 | 2016-01-01 10:00:00 | 20 | 0 | 1 | 1 |
| c001 | o003 | 2016-01-02 00:00:00 | 2016-01-01 10:00:20 | 50,380 | 1 | 2 | 2 |
| c001 | o004 | 2016-01-02 00:00:15 | 2016-01-02 00:00:00 | 15 | 0 | 2 | 2 |
| c001 | o005 | 2016-01-03 10:12:00 | 2016-01-02 00:00:15 | 123,105 | 1 | 3 | 3 |
| c001 | o006 | 2016-01-20 10:12:50 | 2016-01-03 10:12:00 | 1,468,850 | 1 | 4 | 4 |
| c002 | o007 | 2016-01-01 00:00:00 | NULL | NULL | 1 | 1 | 5 |
| c002 | o008 | 2016-01-01 00:00:11 | 2016-01-01 00:00:00 | 11 | 0 | 1 | 5 |
| c002 | o009 | 2016-01-01 00:00:57 | 2016-01-01 00:00:11 | 46 | 0 | 1 | 5 |
| c002 | o010 | 2016-03-01 14:50:00 | 2016-01-01 00:00:57 | 5,237,343 | 1 | 2 | 6 |  
  
7. 計算event_purchase_timestamp  
取每個event的最小值order_purchase_timestamp當event_purchase_timestamp. 
```sql
MIN(order_purchase_timestamp) OVER (PARTITION BY order_event_key) AS event_purchase_timestamp
```  
  
| customer_unique_id | order_id | purchase_ts | previous_purchase_ts | gap_seconds | new_event_flag | local_event_id | order_event_key | event_purchase_timestamp |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| c001 | o001 | 2016-01-01 10:00:00 | NULL | NULL | 1 | 1 | 1 | 2016-01-01 10:00:00 |
| c001 | o002 | 2016-01-01 10:00:20 | 2016-01-01 10:00:00 | 20 | 0 | 1 | 1 | 2016-01-01 10:00:00 |
| c001 | o003 | 2016-01-02 00:00:00 | 2016-01-01 10:00:20 | 50,380 | 1 | 2 | 2 | 2016-01-02 00:00:00 |
| c001 | o004 | 2016-01-02 00:00:15 | 2016-01-02 00:00:00 | 15 | 0 | 2 | 2 | 2016-01-02 00:00:00 |
| c001 | o005 | 2016-01-03 10:12:00 | 2016-01-02 00:00:15 | 123,105 | 1 | 3 | 3 | 2016-01-03 10:12:00 |
| c001 | o006 | 2016-01-20 10:12:50 | 2016-01-03 10:12:00 | 1,468,850 | 1 | 4 | 4 | 2016-01-20 10:12:50 |
| c002 | o007 | 2016-01-01 00:00:00 | NULL | NULL | 1 | 1 | 5 | 2016-01-01 00:00:00 |
| c002 | o008 | 2016-01-01 00:00:11 | 2016-01-01 00:00:00 | 11 | 0 | 1 | 5 | 2016-01-01 00:00:00 |
| c002 | o009 | 2016-01-01 00:00:57 | 2016-01-01 00:00:11 | 46 | 0 | 1 | 5 | 2016-01-01 00:00:00 |
| c002 | o010 | 2016-03-01 14:50:00 | 2016-01-01 00:00:57 | 5,237,343 | 1 | 2 | 6 | 2016-03-01 14:50:00 |  

---  


### 3. olist_analysis_mart: 









### ETL Transformation Pipline





### 關鍵Transformation Design 
