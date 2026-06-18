import { LoaderCircle, Smartphone } from 'lucide-react';
import type { HomeCategoriesConfig } from '../../admin-types';
import { TOGGLEABLE_HOME_CATEGORIES, DEFAULT_HOME_CATEGORY_IDS } from '../../admin-types';

interface HomeCategoriesViewProps {
  config: HomeCategoriesConfig | null;
  isLoading: boolean;
  savingKey: string;
  onToggle: (categoryId: string, platform: 'android' | 'ios', enabled: boolean) => void;
}

function readPlatformBool(value: unknown): boolean | null {
  if (value === true || value === false) return value;
  if (value === 1 || value === '1' || value === 'true') return true;
  if (value === 0 || value === '0' || value === 'false') return false;
  return null;
}

function isCategoryEnabledOnPlatform(
  categoryId: string,
  platform: 'android' | 'ios',
  overrides: Record<string, { default?: boolean; android?: boolean; ios?: boolean }>,
) {
  const override = overrides[categoryId];
  if (override) {
    const platformValue = readPlatformBool(override[platform]);
    if (platformValue !== null) return platformValue;
    const defaultValue = readPlatformBool(override.default);
    if (defaultValue !== null) return defaultValue;
  }
  return DEFAULT_HOME_CATEGORY_IDS.has(categoryId);
}

export default function HomeCategoriesView({ config, isLoading, savingKey, onToggle }: HomeCategoriesViewProps) {
  return (
    <section className="panel home-categories-panel">
      <div className="panel-header">
        <div>
          <h3>أقسام الصفحة الرئيسية</h3>
          <p>
            مثال: فعّل «السيارات» على أندرويد وأطفئها على آيفون. الأقسام
            غير المحددة تستخدم الإعداد الافتراضي (المطاعم، التسوق، السيارات).
          </p>
        </div>
      </div>

      {isLoading ? (
        <div className="loading-state compact">
          <LoaderCircle className="spin" size={22} />
          <span>جار تحميل إعدادات الأقسام...</span>
        </div>
      ) : (
        <div className="home-category-list">
          {TOGGLEABLE_HOME_CATEGORIES.map((category) => {
            const overrides = config?.overrides || {};
            const androidEnabled = isCategoryEnabledOnPlatform(category.id, 'android', overrides);
            const iosEnabled = isCategoryEnabledOnPlatform(category.id, 'ios', overrides);
            const androidSaving = savingKey === `${category.id}:android`;
            const iosSaving = savingKey === `${category.id}:ios`;
            const togglesDisabled = isLoading || androidSaving || iosSaving;
            return (
              <article key={category.id} className="home-category-card">
                <h4>{category.titleAr}</h4>
                <div className="home-category-toggles">
                  <label className="platform-toggle">
                    <span>أندرويد</span>
                    <input
                      type="checkbox"
                      checked={androidEnabled}
                      disabled={togglesDisabled}
                      onChange={(event) => {
                        onToggle(category.id, 'android', event.target.checked);
                      }}
                    />
                    <em>{androidEnabled ? 'ظاهر' : 'مخفي'}</em>
                  </label>
                  <label className="platform-toggle">
                    <span>آيفون</span>
                    <input
                      type="checkbox"
                      checked={iosEnabled}
                      disabled={togglesDisabled}
                      onChange={(event) => {
                        onToggle(category.id, 'ios', event.target.checked);
                      }}
                    />
                    <em>{iosEnabled ? 'ظاهر' : 'مخفي'}</em>
                  </label>
                </div>
              </article>
            );
          })}
        </div>
      )}

      {config?.updatedAt ? (
        <p className="app-update-meta">
          آخر تحديث للإعدادات: {config.updatedAt}
        </p>
      ) : null}
    </section>
  );
}
