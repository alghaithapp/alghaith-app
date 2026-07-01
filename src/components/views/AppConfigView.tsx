import { useEffect, useState } from 'react';
import { Save, Settings2, Map, ListOrdered, Layers, MapPin, Bell, Palette } from 'lucide-react';
import * as api from '../../admin-api';

interface Props {
  token: string;
}

const SECTIONS: { id: string; label: string; Icon: React.ComponentType<{ size: number }> }[] = [
  { id: 'taxiPricing', label: 'أسعار التكسي', Icon: Settings2 },
  { id: 'taxiConfig', label: 'إعدادات التكسي', Icon: Map },
  { id: 'mapDefaults', label: 'إعدادات الخريطة', Icon: Map },
  { id: 'homeCategories', label: 'ترتيب الأقسام', Icon: ListOrdered },
  { id: 'subCategories', label: 'الفئات الفرعية', Icon: Layers },
  { id: 'neighborhoods', label: 'الأماكن المحفوظة', Icon: MapPin },
  { id: 'notificationTexts', label: 'نصوص الإشعارات', Icon: Bell },
  { id: 'appTheme', label: 'الألوان والثيم', Icon: Palette },
];

function RawJsonInput({ label, value, onChange }: { label: string; value: string; onChange: (v: string) => void }) {
  return (
    <div style={{ marginBottom: 16 }}>
      <label style={{ display: 'block', marginBottom: 6, fontSize: 13 }}>{label}</label>
      <textarea
        rows={6}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        style={{ width: '100%', padding: 10, borderRadius: 10, border: '1px solid var(--border)', background: 'var(--surface)', fontFamily: 'monospace', fontSize: 12, resize: 'vertical' }}
      />
    </div>
  );
}

function NumField({ label, value, onChange }: { label: string; value: number; onChange: (v: number) => void }) {
  return (
    <div style={{ marginBottom: 12 }}>
      <label style={{ display: 'block', marginBottom: 4, fontSize: 12 }}>{label}</label>
      <input
        type="number"
        value={value}
        onChange={(event) => onChange(Number(event.target.value) || 0)}
        style={{ width: 140, padding: '6px 10px', borderRadius: 8, border: '1px solid var(--border)', background: 'var(--surface)', fontSize: 13 }}
      />
    </div>
  );
}

export default function AppConfigView({ token }: Props) {
  const [busy, setBusy] = useState<string | null>(null);
  const [msg, setMsg] = useState('');
  const [section, setSection] = useState('taxiPricing');
  const [data, setData] = useState<Record<string, any>>({});

  useEffect(() => {
    api.loadTaxiPricing(token).then((r) => setData((d) => ({ ...d, taxiPricing: r }))).catch(() => {});
    api.loadTaxiConfig(token).then((r) => setData((d) => ({ ...d, taxiConfig: r }))).catch(() => {});
    api.loadMapDefaults(token).then((r) => setData((d) => ({ ...d, mapDefaults: r }))).catch(() => {});
    api.loadHomeCategories(token).then((r) => setData((d) => ({ ...d, homeCategories: JSON.stringify(r, null, 2) }))).catch(() => {});
    api.loadSubCategories(token).then((r) => setData((d) => ({ ...d, subCategories: JSON.stringify(r, null, 2) }))).catch(() => {});
    api.loadNeighborhoods(token).then((r) => setData((d) => ({ ...d, neighborhoods: JSON.stringify(r, null, 2) }))).catch(() => {});
    api.loadNotificationTexts(token).then((r) => setData((d) => ({ ...d, notificationTexts: JSON.stringify(r, null, 2) }))).catch(() => {});
    api.loadAppTheme(token).then((r) => setData((d) => ({ ...d, appTheme: JSON.stringify(r, null, 2) }))).catch(() => {});
  }, [token]);

  function handleSave(key: string, value: unknown) {
    setBusy(key);
    setMsg('');
    api.saveAppConfig(token, key, value).then(() => {
      setMsg('✓ تم الحفظ');
      setTimeout(() => setMsg(''), 3000);
    }).catch((error) => {
      setMsg('✗ ' + (error instanceof Error ? error.message : 'خطأ'));
    }).finally(() => setBusy(null));
  }

  function set(key: string, partial: Record<string, any>) {
    setData((d) => ({ ...d, [key]: { ...(d[key] || {}), ...partial } }));
  }

  function safeParse(j: string) { try { return JSON.parse(j); } catch { return {}; } }

  const p = data.taxiPricing || {};
  const tc = data.taxiConfig || {};
  const md = data.mapDefaults || {};

  return (
    <div>
      <div style={{ marginBottom: 20 }}>
        <h2 style={{ marginBottom: 4 }}>إعدادات التطبيق الديناميكية</h2>
        <p style={{ color: 'var(--text-secondary)', fontSize: 13 }}>التعديل ينعكس فوراً على التطبيق بدون تحديث.</p>
      </div>

      {msg && <div style={{ padding: '8px 14px', borderRadius: 8, marginBottom: 16, background: msg.includes('✓') ? '#d1fae5' : '#fee2e2' }}>{msg}</div>}

      <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap', marginBottom: 20 }}>
        {SECTIONS.map((s) => (
          <button key={s.id} onClick={() => setSection(s.id)} style={{
            display: 'inline-flex', alignItems: 'center', gap: 4, padding: '6px 12px', borderRadius: 8, fontSize: 12, border: 'none', cursor: 'pointer',
            background: section === s.id ? 'var(--primary)' : 'var(--surface)', color: section === s.id ? '#fff' : 'var(--text)', fontWeight: 600,
          }}>
            <s.Icon size={14} /> {s.label}
          </button>
        ))}
      </div>

      {section === 'taxiPricing' && (
        <div>
          <h3 style={{ marginBottom: 16 }}>أسعار التكسي</h3>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: 12 }}>
            <NumField label="🛺 تكتك - أساسي" value={p.tuktuk?.base ?? 1000} onChange={(v) => set('taxiPricing', { tuktuk: { ...(p.tuktuk || {}), base: v } })} />
            <NumField label="🛺 تكتك - كل كم" value={p.tuktuk?.extraKm ?? 250} onChange={(v) => set('taxiPricing', { tuktuk: { ...(p.tuktuk || {}), extraKm: v } })} />
            <NumField label="🛺 تكتك - حد أدنى" value={p.tuktuk?.min ?? 1000} onChange={(v) => set('taxiPricing', { tuktuk: { ...(p.tuktuk || {}), min: v } })} />
            <NumField label="🚙 واز - أساسي" value={p.wazz?.base ?? 1500} onChange={(v) => set('taxiPricing', { wazz: { ...(p.wazz || {}), base: v } })} />
            <NumField label="🚙 واز - كل كم" value={p.wazz?.extraKm ?? 300} onChange={(v) => set('taxiPricing', { wazz: { ...(p.wazz || {}), extraKm: v } })} />
            <NumField label="🚙 واز - حد أدنى" value={p.wazz?.min ?? 1500} onChange={(v) => set('taxiPricing', { wazz: { ...(p.wazz || {}), min: v } })} />
            <NumField label="🚗 اقتصادي - أساسي" value={p.economic?.base ?? 1500} onChange={(v) => set('taxiPricing', { economic: { ...(p.economic || {}), base: v } })} />
            <NumField label="🚗 اقتصادي - كل كم" value={p.economic?.extraKm ?? 500} onChange={(v) => set('taxiPricing', { economic: { ...(p.economic || {}), extraKm: v } })} />
            <NumField label="🚗 اقتصادي - حد أدنى" value={p.economic?.min ?? 1500} onChange={(v) => set('taxiPricing', { economic: { ...(p.economic || {}), min: v } })} />
            <NumField label="الحد الأقصى" value={p.maxFare ?? 50000} onChange={(v) => set('taxiPricing', { maxFare: v })} />
            <NumField label="الكيلومترات المجانية" value={p.includedKm ?? 2} onChange={(v) => set('taxiPricing', { includedKm: v })} />
            <NumField label="التقريب" value={p.roundingStep ?? 250} onChange={(v) => set('taxiPricing', { roundingStep: v })} />
          </div>
          <button className="button primary" disabled={busy === 'taxi_pricing'} onClick={() => handleSave('taxi_pricing', data.taxiPricing)}>
            {busy === 'taxi_pricing' ? 'جاري الحفظ...' : <><Save size={16} /> حفظ</>}
          </button>
        </div>
      )}

      {section === 'taxiConfig' && (
        <div>
          <h3 style={{ marginBottom: 16 }}>إعدادات التكسي</h3>
          <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
            <NumField label="مهلة البحث (ثانية)" value={tc.searchTimeoutSeconds ?? 300} onChange={(v) => set('taxiConfig', { searchTimeoutSeconds: v })} />
            <NumField label="حد التوقف" value={tc.maxStops ?? 3} onChange={(v) => set('taxiConfig', { maxStops: v })} />
            <NumField label="نصف قطر المطابقة (كم)" value={tc.matchingRadiusKm ?? 10} onChange={(v) => set('taxiConfig', { matchingRadiusKm: v })} />
            <NumField label="نصف قطر التوسع (كم)" value={tc.matchingRadiusExpandKm ?? 25} onChange={(v) => set('taxiConfig', { matchingRadiusExpandKm: v })} />
            <NumField label="أقصى سائقين للإشعار" value={tc.maxDriversPerNotify ?? 40} onChange={(v) => set('taxiConfig', { maxDriversPerNotify: v })} />
          </div>
          <button className="button primary" disabled={busy === 'taxi_config'} onClick={() => handleSave('taxi_config', data.taxiConfig)}>
            {busy === 'taxi_config' ? 'جاري الحفظ...' : <><Save size={16} /> حفظ</>}
          </button>
        </div>
      )}

      {section === 'mapDefaults' && (
        <div>
          <h3 style={{ marginBottom: 16 }}>إعدادات الخريطة</h3>
          <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
            <NumField label="خط العرض" value={md.centerLat ?? 32.9256} onChange={(v) => set('mapDefaults', { centerLat: v })} />
            <NumField label="خط الطول" value={md.centerLng ?? 44.7766} onChange={(v) => set('mapDefaults', { centerLng: v })} />
            <NumField label="التكبير" value={md.defaultZoom ?? 12} onChange={(v) => set('mapDefaults', { defaultZoom: v })} />
          </div>
          <button className="button primary" disabled={busy === 'map_defaults'} onClick={() => handleSave('map_defaults', data.mapDefaults)}>
            {busy === 'map_defaults' ? 'جاري الحفظ...' : <><Save size={16} /> حفظ</>}
          </button>
        </div>
      )}

      {['homeCategories', 'subCategories', 'neighborhoods', 'notificationTexts', 'appTheme'].includes(section) && (
        <div>
          <h3 style={{ marginBottom: 16 }}>{SECTIONS.find((s) => s.id === section)?.label}</h3>
          <RawJsonInput label="البيانات (JSON)" value={data[section] || '{}'} onChange={(v) => setData((d) => ({ ...d, [section]: v }))} />
          <button className="button primary" disabled={busy === section} onClick={() => handleSave(section, safeParse(data[section] || '{}'))}>
            {busy === section ? 'جاري الحفظ...' : <><Save size={16} /> حفظ</>}
          </button>
        </div>
      )}
    </div>
  );
}
