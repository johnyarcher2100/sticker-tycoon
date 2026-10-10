-- ============================================
-- 貼圖大亨 Sticker Tycoon V.801 完整重建 SQL
-- 來源: 02-database-schema.md Part1+2+3 (2026-10-10)
-- 順序: Extension -> Users/Tokens -> Generation -> Style -> Expression -> Beacon -> Promotion/Coupon/Admin/CMS -> Indexes -> Functions -> Triggers -> RLS -> Seed -> Storage Note
-- ============================================

-- 0. EXTENSION
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================
-- 1.1 核心用戶與張數
-- ============================================
CREATE TABLE IF NOT EXISTS users (
  id BIGSERIAL PRIMARY KEY,
  line_user_id TEXT,
  display_name TEXT,
  picture_url TEXT,
  sticker_credits INTEGER DEFAULT 40,
  is_premium BOOLEAN DEFAULT FALSE,
  admin_nickname TEXT,
  transfer_code TEXT,
  referral_code TEXT UNIQUE,
  referred_by TEXT,
  referral_count INTEGER DEFAULT 0,
  last_tutorial_shown_at TIMESTAMPTZ,
  auth_user_id UUID UNIQUE,
  email VARCHAR(255) UNIQUE,
  user_type VARCHAR(10) DEFAULT 'line',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_line_user_id ON users(line_user_id);
CREATE INDEX IF NOT EXISTS idx_users_referral_code ON users(referral_code) WHERE referral_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON users(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_user_type ON users(user_type);

CREATE TABLE IF NOT EXISTS referrals (
  id BIGSERIAL PRIMARY KEY,
  referrer_id TEXT NOT NULL,
  referee_id TEXT NOT NULL UNIQUE,
  referrer_tokens INTEGER DEFAULT 10,
  referee_tokens INTEGER DEFAULT 10,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referee ON referrals(referee_id);

CREATE TABLE IF NOT EXISTS token_transactions (
  id BIGSERIAL PRIMARY KEY,
  user_id TEXT NOT NULL,
  amount INTEGER NOT NULL,
  balance_after INTEGER NOT NULL,
  transaction_type TEXT NOT NULL,
  description TEXT,
  reference_id TEXT,
  admin_note TEXT,
  expires_at TIMESTAMPTZ,
  order_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_token_transactions_user_id ON token_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_token_transactions_type ON token_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_token_transactions_created_at ON token_transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_token_transactions_order_id ON token_transactions(order_id);
CREATE INDEX IF NOT EXISTS idx_token_transactions_expires_at ON token_transactions(expires_at);

CREATE TABLE IF NOT EXISTS token_ledger (
  id BIGSERIAL PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(line_user_id) ON DELETE CASCADE,
  tokens INTEGER NOT NULL,
  remaining_tokens INTEGER NOT NULL CHECK (remaining_tokens >=0 AND remaining_tokens <= tokens),
  source_type TEXT NOT NULL,
  source_order_id TEXT,
  source_description TEXT,
  acquired_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  is_expired BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_token_ledger_user_id ON token_ledger(user_id);
CREATE INDEX IF NOT EXISTS idx_token_ledger_expires_at ON token_ledger(expires_at);
CREATE INDEX IF NOT EXISTS idx_token_ledger_source_order ON token_ledger(source_order_id);
CREATE INDEX IF NOT EXISTS idx_token_ledger_fifo ON token_ledger(user_id, expires_at) WHERE remaining_tokens > 0 AND is_expired = FALSE;

CREATE TABLE IF NOT EXISTS orders (
  id BIGSERIAL PRIMARY KEY,
  order_id TEXT NOT NULL UNIQUE,
  user_id TEXT NOT NULL REFERENCES users(line_user_id) ON DELETE CASCADE,
  package_id TEXT NOT NULL,
  package_name TEXT NOT NULL,
  token_amount INTEGER NOT NULL,
  bonus_tokens INTEGER DEFAULT 0,
  total_tokens INTEGER NOT NULL,
  amount INTEGER NOT NULL,
  currency TEXT DEFAULT 'TWD',
  transaction_id TEXT,
  payment_url TEXT,
  status TEXT DEFAULT 'pending',
  paid_at TIMESTAMPTZ,
  tokens_issued BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_transaction_id ON orders(transaction_id);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_expires_at ON orders(expires_at) WHERE status='pending';

-- ============================================
-- 1.2 貼圖生成
-- ============================================
CREATE TABLE IF NOT EXISTS line_pack_tasks (
  id BIGSERIAL PRIMARY KEY,
  task_id TEXT NOT NULL UNIQUE,
  user_id TEXT NOT NULL,
  main_index INTEGER DEFAULT 0,
  status TEXT DEFAULT 'pending',
  progress INTEGER DEFAULT 0,
  download_url TEXT,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS listing_applications (
  id BIGSERIAL PRIMARY KEY,
  application_id TEXT NOT NULL UNIQUE,
  user_id TEXT NOT NULL,
  name_en TEXT NOT NULL,
  name_zh TEXT,
  price INTEGER DEFAULT 30,
  cover_index INTEGER DEFAULT 0,
  cover_url TEXT,
  sticker_count INTEGER DEFAULT 40,
  sticker_urls JSONB,
  status TEXT DEFAULT 'pending',
  line_sticker_id TEXT,
  admin_notes TEXT,
  zip_cache_url TEXT,
  zip_generating BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  submitted_at TIMESTAMPTZ,
  approved_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS line_events (
  id BIGSERIAL PRIMARY KEY,
  reply_token TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sticker_sets (
  id BIGSERIAL PRIMARY KEY,
  set_id TEXT NOT NULL UNIQUE,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  style TEXT NOT NULL,
  character_prompt TEXT,
  photo_url TEXT,
  photo_base64 TEXT,
  sticker_count INTEGER DEFAULT 8 CHECK (sticker_count IN (0,4,8,16,18,24,40,54)),
  framing TEXT DEFAULT 'halfbody',
  scene TEXT DEFAULT 'none',
  scene_config JSONB,
  expressions JSONB,
  character_id TEXT,
  expression_template TEXT,
  status TEXT DEFAULT 'draft',
  main_image_url TEXT,
  tab_image_url TEXT,
  zip_url TEXT,
  tokens_used INTEGER DEFAULT 0,
  source VARCHAR(10) DEFAULT 'line',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_sticker_sets_user_id ON sticker_sets(user_id);
CREATE INDEX IF NOT EXISTS idx_sticker_sets_status ON sticker_sets(status);
CREATE INDEX IF NOT EXISTS idx_sticker_sets_source ON sticker_sets(source);
CREATE INDEX IF NOT EXISTS idx_sticker_sets_user_status_created ON sticker_sets(user_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS stickers (
  id BIGSERIAL PRIMARY KEY,
  sticker_id TEXT NOT NULL UNIQUE,
  set_id TEXT NOT NULL REFERENCES sticker_sets(set_id) ON DELETE CASCADE,
  index_number INTEGER NOT NULL,
  expression TEXT NOT NULL,
  image_url TEXT,
  status TEXT DEFAULT 'pending',
  generation_prompt TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_stickers_set_id ON stickers(set_id);
CREATE INDEX IF NOT EXISTS idx_stickers_set_id_index ON stickers(set_id, index_number);

CREATE TABLE IF NOT EXISTS generation_tasks (
  id BIGSERIAL PRIMARY KEY,
  task_id TEXT NOT NULL UNIQUE,
  user_id TEXT NOT NULL,
  set_id TEXT REFERENCES sticker_sets(set_id) ON DELETE CASCADE,
  task_type TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  progress INTEGER DEFAULT 0,
  result_json JSONB,
  error_message TEXT,
  source VARCHAR(10) DEFAULT 'line',
  photo_data TEXT,
  scene_config TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_generation_tasks_user_id ON generation_tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_generation_tasks_status ON generation_tasks(status);
CREATE INDEX IF NOT EXISTS idx_generation_tasks_user_created ON generation_tasks(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS conversation_states (
  id BIGSERIAL PRIMARY KEY,
  user_id TEXT NOT NULL UNIQUE,
  current_stage TEXT DEFAULT 'idle',
  current_set_id TEXT,
  temp_data JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS upload_queue (
  id BIGSERIAL PRIMARY KEY,
  user_id TEXT NOT NULL,
  sticker_id TEXT NOT NULL REFERENCES stickers(sticker_id) ON DELETE CASCADE,
  source_set_id TEXT NOT NULL,
  image_url TEXT NOT NULL,
  expression TEXT,
  queue_order INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, sticker_id)
);
CREATE INDEX IF NOT EXISTS idx_upload_queue_user_id ON upload_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_upload_queue_user_order ON upload_queue(user_id, queue_order);

-- ============================================
-- 1.3 風格設定
-- ============================================
CREATE TABLE IF NOT EXISTS style_settings (
  id SERIAL PRIMARY KEY,
  style_id VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  emoji VARCHAR(10),
  description TEXT,
  core_style TEXT,
  lighting TEXT,
  composition TEXT,
  brushwork TEXT,
  mood TEXT,
  color_palette TEXT,
  forbidden TEXT,
  reference TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS framing_settings (
  id SERIAL PRIMARY KEY,
  framing_id VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  emoji VARCHAR(10),
  description TEXT,
  head_size_percentage INTEGER,
  prompt_addition TEXT,
  character_focus TEXT,
  compact_prompt TEXT,
  use_compact BOOLEAN DEFAULT true,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS scene_settings (
  id SERIAL PRIMARY KEY,
  scene_id VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  emoji VARCHAR(10),
  description TEXT,
  decoration_style TEXT,
  decoration_elements JSONB,
  pop_text_style TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 1.4 表情模板
-- ============================================
CREATE TABLE IF NOT EXISTS expression_templates (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  expressions JSONB NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS expression_template_settings (
  id SERIAL PRIMARY KEY,
  template_id VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  emoji VARCHAR(10),
  description TEXT,
  expressions JSONB NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 1.5 Beacon
-- ============================================
CREATE TABLE IF NOT EXISTS beacon_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_name VARCHAR(100) NOT NULL UNIQUE,
  message_type VARCHAR(20) NOT NULL,
  message_content TEXT NOT NULL,
  target_audience VARCHAR(20) DEFAULT 'all',
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS beacon_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hwid VARCHAR(10) NOT NULL UNIQUE,
  vendor_key VARCHAR(8),
  lot_key VARCHAR(16),
  device_name VARCHAR(100),
  location VARCHAR(200),
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS beacon_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hwid VARCHAR(10) NOT NULL,
  event_type VARCHAR(20) NOT NULL,
  trigger_type VARCHAR(20),
  action_type VARCHAR(50) NOT NULL,
  action_name VARCHAR(100),
  action_data JSONB NOT NULL,
  message_id UUID REFERENCES beacon_messages(id),
  description TEXT,
  daily_limit INTEGER,
  cooldown_minutes INTEGER,
  priority INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS beacon_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id VARCHAR(100) NOT NULL,
  hwid VARCHAR(10) NOT NULL,
  event_type VARCHAR(20) NOT NULL,
  device_message TEXT,
  is_friend BOOLEAN DEFAULT false,
  global_daily_key TEXT,
  message_sent BOOLEAN DEFAULT false,
  error_message TEXT,
  timestamp BIGINT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_beacon_events_user_id ON beacon_events(user_id);
CREATE INDEX IF NOT EXISTS idx_beacon_events_hwid ON beacon_events(hwid);
CREATE INDEX IF NOT EXISTS idx_beacon_events_global_daily_key_message_sent ON beacon_events(global_daily_key, message_sent);
CREATE INDEX IF NOT EXISTS idx_beacon_events_user_timestamp_message_sent ON beacon_events(user_id, timestamp, message_sent);

CREATE TABLE IF NOT EXISTS beacon_statistics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hwid VARCHAR(10) NOT NULL,
  date DATE NOT NULL,
  enter_count INTEGER DEFAULT 0,
  leave_count INTEGER DEFAULT 0,
  unique_users INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(hwid, date)
);

-- ============================================
-- 1.6 推廣 + 1.7 優惠券 + 1.8 Admin + 1.9 CMS
-- ============================================
CREATE TABLE IF NOT EXISTS youtuber_promotions (
  id BIGSERIAL PRIMARY KEY,
  application_id TEXT NOT NULL UNIQUE,
  channel_name TEXT NOT NULL,
  channel_url TEXT NOT NULL,
  subscriber_count INTEGER NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  line_id TEXT NOT NULL,
  channel_type TEXT NOT NULL,
  channel_description TEXT NOT NULL,
  filming_plan TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  approval_reason TEXT,
  tokens_awarded INTEGER DEFAULT 0,
  video_url TEXT,
  video_title TEXT,
  video_approval_status TEXT DEFAULT 'pending',
  video_approval_reason TEXT,
  admin_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  approved_at TIMESTAMPTZ,
  video_approved_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS coupon_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slogan TEXT,
  token_amount INTEGER NOT NULL CHECK (token_amount >0),
  redeem_code TEXT NOT NULL UNIQUE,
  claim_start_at TIMESTAMPTZ NOT NULL,
  claim_end_at TIMESTAMPTZ NOT NULL CHECK (claim_end_at >= claim_start_at),
  activate_start_at TIMESTAMPTZ NOT NULL,
  activate_end_at TIMESTAMPTZ NOT NULL CHECK (activate_end_at >= activate_start_at),
  is_active BOOLEAN DEFAULT TRUE,
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS coupon_redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES coupon_campaigns(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL,
  redeem_code TEXT NOT NULL,
  token_amount INTEGER NOT NULL CHECK (token_amount >0),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(campaign_id, user_id)
);

CREATE TABLE IF NOT EXISTS admin_credentials (
  id BIGSERIAL PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS demo_gallery (
  id BIGSERIAL PRIMARY KEY,
  url TEXT NOT NULL,
  style VARCHAR(50),
  style_name VARCHAR(100),
  character TEXT,
  scene TEXT,
  expression TEXT,
  set_id VARCHAR(100),
  sticker_index INTEGER,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS style_analysis_tasks (
  id BIGSERIAL PRIMARY KEY,
  task_id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  status TEXT DEFAULT 'pending',
  progress INTEGER DEFAULT 0,
  result JSONB,
  error_message TEXT,
  usage JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

-- ============================================
-- 2. FUNCTIONS
-- ============================================
CREATE OR REPLACE FUNCTION cleanup_old_data() RETURNS void AS $$
BEGIN
  DELETE FROM line_events WHERE created_at < NOW() - INTERVAL '7 days';
  DELETE FROM generation_tasks WHERE status='failed' AND created_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cleanup_old_style_analysis_tasks() RETURNS void AS $$
BEGIN
  DELETE FROM style_analysis_tasks WHERE created_at < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mark_expired_tokens() RETURNS INTEGER AS $$
DECLARE cnt INTEGER;
BEGIN
  UPDATE token_ledger SET is_expired=TRUE WHERE expires_at < NOW() AND is_expired=FALSE;
  GET DIAGNOSTICS cnt = ROW_COUNT;
  RETURN cnt;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION recalculate_user_balance(p_user_id TEXT) RETURNS INTEGER AS $$
DECLARE new_bal INTEGER;
BEGIN
  SELECT COALESCE(SUM(remaining_tokens),0) INTO new_bal FROM token_ledger WHERE user_id=p_user_id AND is_expired=FALSE;
  UPDATE users SET sticker_credits=new_bal WHERE line_user_id=p_user_id;
  RETURN new_bal;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cleanup_expired_orders() RETURNS INTEGER AS $$
DECLARE cnt INTEGER;
BEGIN
  UPDATE orders SET status='expired' WHERE status='pending' AND expires_at < NOW();
  GET DIAGNOSTICS cnt = ROW_COUNT;
  RETURN cnt;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION verify_admin_password(p_username TEXT, p_password TEXT) RETURNS BOOLEAN AS $$
DECLARE hash TEXT;
BEGIN
  SELECT password_hash INTO hash FROM admin_credentials WHERE username=p_username;
  IF hash IS NULL THEN RETURN FALSE; END IF;
  RETURN hash = crypt(p_password, hash);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_admin_password(p_username TEXT, p_new_password TEXT) RETURNS BOOLEAN AS $$
BEGIN
  UPDATE admin_credentials SET password_hash=crypt(p_new_password, gen_salt('bf')), updated_at=NOW() WHERE username=p_username;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_admin_usernames() RETURNS TABLE(username TEXT) AS $$
BEGIN RETURN QUERY SELECT ac.username FROM admin_credentials ac; END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_beacon_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at=NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_beacon_messages_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at=NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_demo_gallery_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at=NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at=NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 3. TRIGGERS
-- ============================================
DROP TRIGGER IF EXISTS update_beacon_devices_updated_at ON beacon_devices;
CREATE TRIGGER update_beacon_devices_updated_at BEFORE UPDATE ON beacon_devices FOR EACH ROW EXECUTE FUNCTION update_beacon_updated_at();

DROP TRIGGER IF EXISTS update_beacon_actions_updated_at ON beacon_actions;
CREATE TRIGGER update_beacon_actions_updated_at BEFORE UPDATE ON beacon_actions FOR EACH ROW EXECUTE FUNCTION update_beacon_updated_at();

DROP TRIGGER IF EXISTS trigger_update_beacon_messages_updated_at ON beacon_messages;
CREATE TRIGGER trigger_update_beacon_messages_updated_at BEFORE UPDATE ON beacon_messages FOR EACH ROW EXECUTE FUNCTION update_beacon_messages_updated_at();

DROP TRIGGER IF EXISTS update_demo_gallery_timestamp ON demo_gallery;
CREATE TRIGGER update_demo_gallery_timestamp BEFORE UPDATE ON demo_gallery FOR EACH ROW EXECUTE FUNCTION update_demo_gallery_updated_at();

DROP TRIGGER IF EXISTS trg_coupon_campaigns_set_updated_at ON coupon_campaigns;
CREATE TRIGGER trg_coupon_campaigns_set_updated_at BEFORE UPDATE ON coupon_campaigns FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Partial unique index for防並發: 同 user 同時只能 1 pending/processing task
CREATE UNIQUE INDEX IF NOT EXISTS generation_tasks_unique_pending_user ON generation_tasks(user_id) WHERE status IN ('pending','processing');

-- ============================================
-- 6. RLS
-- ============================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE sticker_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE stickers ENABLE ROW LEVEL SECURITY;
ALTER TABLE generation_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE token_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE style_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE framing_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE scene_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE expression_template_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE beacon_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE beacon_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE beacon_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE beacon_statistics ENABLE ROW LEVEL SECURITY;
ALTER TABLE beacon_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_redemptions ENABLE ROW LEVEL SECURITY;

-- Service role full access (依你規格)
DROP POLICY IF EXISTS "Service role full access" ON orders;
CREATE POLICY "Service role full access" ON orders FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Service role full access token_ledger" ON token_ledger;
CREATE POLICY "Service role full access token_ledger" ON token_ledger FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow public read style_settings" ON style_settings;
CREATE POLICY "Allow public read style_settings" ON style_settings FOR SELECT USING (true);
CREATE POLICY "Allow public write style_settings" ON style_settings FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow public read framing_settings" ON framing_settings;
CREATE POLICY "Allow public read framing_settings" ON framing_settings FOR SELECT USING (true);
CREATE POLICY "Allow public write framing_settings" ON framing_settings FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow public read scene_settings" ON scene_settings;
CREATE POLICY "Allow public read scene_settings" ON scene_settings FOR SELECT USING (true);
CREATE POLICY "Allow public write scene_settings" ON scene_settings FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "public read expression_template_settings" ON expression_template_settings;
CREATE POLICY "public read expression_template_settings" ON expression_template_settings FOR SELECT USING (true);
CREATE POLICY "public write expression_template_settings" ON expression_template_settings FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "service beacon_devices" ON beacon_devices;
CREATE POLICY "service beacon_devices" ON beacon_devices FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "service beacon_events" ON beacon_events;
CREATE POLICY "service beacon_events" ON beacon_events FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "service beacon_actions" ON beacon_actions;
CREATE POLICY "service beacon_actions" ON beacon_actions FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "service beacon_statistics" ON beacon_statistics;
CREATE POLICY "service beacon_statistics" ON beacon_statistics FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all beacon_messages" ON beacon_messages;
CREATE POLICY "Allow all beacon_messages" ON beacon_messages FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow anonymous verify" ON admin_credentials;
CREATE POLICY "Allow anonymous verify" ON admin_credentials FOR SELECT USING (true);
DROP POLICY IF EXISTS "coupon_campaigns_select_public" ON coupon_campaigns;
CREATE POLICY "coupon_campaigns_select_public" ON coupon_campaigns FOR SELECT USING (is_active = TRUE);

-- ============================================
-- 7. SEED
-- ============================================
INSERT INTO admin_credentials (username, password_hash) VALUES ('admin', crypt('sticker2024!', gen_salt('bf'))) ON CONFLICT (username) DO NOTHING;

INSERT INTO framing_settings (framing_id, name, emoji, compact_prompt, use_compact, is_active) VALUES
('fullbody','全身','🧍','Full body head-to-toe, 15% head, 90% vertical fill, feet visible',true,true),
('halfbody','半身','🙋','Waist up, 25% head, hands visible, 85% vertical fill',true,true),
('portrait','大頭','🙂','Head & shoulders, 60% head, face focus, 85% vertical fill',true,true),
('closeup','特寫','😳','Face only, 85% face fill, eyes center, nearly touching edges',true,true)
ON CONFLICT (framing_id) DO UPDATE SET compact_prompt=EXCLUDED.compact_prompt;

INSERT INTO expression_template_settings (template_id, name, emoji, expressions, is_active) VALUES
('basic','基本日常','😊','["早安","晚安","謝謝","對不起","OK","加油","恭喜","再見","哈哈","生氣","哭哭","愛你","睡覺","吃飯","讚","辛苦了","等等","沒問題","好的","驚訝","害羞","委屈","興奮","期待"]'::jsonb,true),
('cute','可愛撒嬌','🥺','["賣萌","害羞","撒嬌","委屈","興奮","期待","小計","謝謝","啾咪","抱抱","親親","愛心","開心","難過","生氣氣","嚇到","累累","餓餓","睏睏","加油鴨","好棒","好喜歡","嗚嗚","嘻嘻"]'::jsonb,true),
('office','辦公室','💼','["OK","讚","加班中","累了","開會","截止日","薪水","下班","收到","處理中","完成了","請假","遲到","報告","簡報","客戶","主管","同事","加油","辛苦了","沒問題","好的","謝謝","抱歉"]'::jsonb,true),
('social','社交常用','💬','["謝謝","抱歉","沒問題","好的","等等","再見","晚安","早安","嗨","你好","好久不見","恭喜","加油","辛苦了","請多指教","不好意思","借過","謝謝你","愛你","想你","抱抱","親親","晚安安","早安安"]'::jsonb,true),
('emotion','情緒表達','🎭','["開心","難過","生氣","驚訝","害羞","尷尬","興奮","緊張","害怕","委屈","感動","憤怒","平靜","焦慮","期待","失望","無聊","疲倦","放鬆","驕傲","嫉妒","感激","孤單","幸福"]'::jsonb,true),
('special','特殊場合','🎉','["生日快樂","新年快樂","聖誕快樂","中秋快樂","情人節快樂","母親節快樂","父親節快樂","畢業快樂","新婚快樂","恭喜發財","萬聖節快樂","端午快樂","兒童節快樂","七夕快樂","感恩節快樂","祝你好運","早日康復","一路順風","歡迎光臨","謝謝光臨","開工大吉","考試順利","面試順利","演出成功"]'::jsonb,true)
ON CONFLICT (template_id) DO NOTHING;

INSERT INTO beacon_devices (hwid, vendor_key, lot_key, device_name, location, description) VALUES
('0000000019','00000019','0011223344556603','Minew E2 測試設備','辦公室入口','用於測試 LINE Beacon 功能的 Minew E2 設備')
ON CONFLICT (hwid) DO NOTHING;

INSERT INTO beacon_messages (template_name, message_type, message_content, target_audience) VALUES
('入口歡迎訊息','text','歡迎光臨貼圖大亨！','all'),
('好友專屬歡迎','text','好友回來了！今天要來做新貼圖嗎？','friends'),
('邀請加入好友','text','嗨！加入好友送40張免費生成額度！','non_friends'),
('離開感謝訊息','text','謝謝光臨，期待再見！','all')
ON CONFLICT (template_name) DO NOTHING;

INSERT INTO scene_settings (scene_id, name, emoji, description, decoration_style, decoration_elements, pop_text_style, is_active) VALUES
('christmas','聖誕節慶','🎄','聖誕樹、金紅裝飾、雪花禮物','festive Christmas theme, warm holiday atmosphere with gold and red decorations, cozy winter celebration',ARRAY['christmas tree','santa hat','gift boxes with ribbons','snowflakes','holly leaves with berries','golden bells','red and gold ornaments','twinkling lights','candy canes','stars on top'],'festive bold text with Christmas colors (red, gold, green), holiday celebration typography, warm and joyful font',true)
ON CONFLICT (scene_id) DO NOTHING;

-- Storage buckets需在Dashboard手動建立Public: sticker-images, user-photos, coupons, morning-greetings
-- 若要SQL化補上:
-- INSERT INTO storage.buckets (id, name, public) VALUES ('sticker-images','sticker-images',true),('user-photos','user-photos',true),('coupons','coupons',true),('morning-greetings','morning-greetings',true) ON CONFLICT (id) DO NOTHING;
