# 貼圖大亨 Sticker Tycoon V.801 - Rebuilt in Meta AI

完整重建自 296KB 規格書 (00-README + 04-business-logic 3/3 + 02-database-schema 3/3 + 03-frontend 3/3 + 01-functions-api 3/3)

## 快速開始
1. `supabase/migrations/001_initial_schema.sql` 貼到 Supabase SQL Editor 執行
2. 建 4 buckets Public: sticker-images, user-photos, coupons, morning-greetings
3. `.env.example` -> `.env` 填入
4. `npm i && netlify dev`

## 重建進度
- Phase1 地基 supabase-client + sticker-styles + ai-api-client + utils ✅ 本次已建
- Phase2 生成心臟 ai-generator + grid-generator + image-processor
- Phase3 LINE webhook 4247行狀態機
- Phase4 前後端閉環 90檔 + 32頁

## 關鍵實作
- Token FIFO ORDER BY expires_at ASC, 30天有效, reference_id冪等
- Partial unique generation_tasks(user_id) WHERE pending/processing
- Beacon globalDailyKey ${userId}:${taipei-today}
- LINE Pay 現行銀行轉帳 824 111000196474 梁勝喜
