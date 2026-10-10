
import { getSupabaseClient } from './supabase-client.js';
import { globalCache } from './utils/cache-manager.js';
export async function loadStyleSettings(){
  const cached=globalCache.get('style_settings'); if(cached) return cached;
  const {data}=await getSupabaseClient().from('style_settings').select('*').eq('is_active',true);
  globalCache.set('style_settings', data||[]);
  return data||[];
}
export async function loadFramingSettings(){
  const cached=globalCache.get('framing_settings'); if(cached) return cached;
  const {data}=await getSupabaseClient().from('framing_settings').select('*').eq('is_active',true);
  globalCache.set('framing_settings', data||[]);
  return data||[];
}
export async function loadSceneSettings(){
  const cached=globalCache.get('scene_settings'); if(cached) return cached;
  const {data}=await getSupabaseClient().from('scene_settings').select('*').eq('is_active',true);
  globalCache.set('scene_settings', data||[]);
  return data||[];
}
export function clearStyleSettingsCache(){ globalCache.map.clear(); }
