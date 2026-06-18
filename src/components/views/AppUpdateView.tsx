import { BadgeCheck, LoaderCircle, Smartphone } from 'lucide-react';
import type { AppUpdatePolicy } from '../../admin-types';

interface AppUpdateViewProps {
  policy: AppUpdatePolicy | null;
  draft: {
    minBuildNumber: string;
    minVersionName: string;
    latestBuildNumber: string;
    latestVersionName: string;
    messageAr: string;
    androidStoreUrl: string;
    iosStoreUrl: string;
  } | null;
  isSaving: boolean;
  onDraftChange: (draft: Partial<AppUpdateViewProps['draft']>) => void;
  onSave: () => void;
  formatDate: (value: string | null | undefined) => string;
}

export default function AppUpdateView({ policy, draft, isSaving, onDraftChange, onSave, formatDate }: AppUpdateViewProps) {
  return (
    <section className="panel app-update-panel">
      <div className="panel-header">
        <div>
          <h3>إعدادات التحديث الإجباري</h3>
          <p>
            «أقل رقم بناء» يُجبر المستخدمين القدامى على التحديث.
            «أحدث رقم بناء» يُستخدم عند الضغط على «التحقق من تحديث التطبيق».
          </p>
        </div>
      </div>

      {!draft ? (
        <div className="loading-state compact">
          <LoaderCircle className="spin" size={22} />
          <span>جار تحميل الإعدادات...</span>
        </div>
      ) : (
      <div className="app-update-form">
        <label className="app-update-field">
          <span>أقل رقم بناء مسموح (تحديث إجباري)</span>
          <input
            dir="ltr"
            type="number"
            min={1}
            value={draft.minBuildNumber}
            onChange={(event) =>
              onDraftChange({ minBuildNumber: event.target.value })
            }
          />
          <small>من دون هذا الرقم تظهر شاشة تحديث بدون تخطي.</small>
        </label>

        <label className="app-update-field">
          <span>أحدث رقم بناء في المتجر (للتحقق اليدوي)</span>
          <input
            dir="ltr"
            type="number"
            min={0}
            value={draft.latestBuildNumber}
            onChange={(event) =>
              onDraftChange({ latestBuildNumber: event.target.value })
            }
          />
          <small>مثال: 53 من pubspec.yaml → version: 1.2.22+53</small>
        </label>

        <label className="app-update-field">
          <span>أحدث اسم إصدار في المتجر</span>
          <input
            dir="ltr"
            value={draft.latestVersionName}
            onChange={(event) =>
              onDraftChange({ latestVersionName: event.target.value })
            }
          />
          <small>مثال: 1.2.22 — يُستخدم مع رقم البناء أو كبديل.</small>
        </label>

        <label className="app-update-field">
          <span>اسم الإصدار للحد الأدنى (اختياري للعرض)</span>
          <input
            dir="ltr"
            value={draft.minVersionName}
            onChange={(event) =>
              onDraftChange({ minVersionName: event.target.value })
            }
          />
        </label>

        <label className="app-update-field">
          <span>الرسالة للمستخدم</span>
          <textarea
            rows={4}
            value={draft.messageAr}
            onChange={(event) =>
              onDraftChange({ messageAr: event.target.value })
            }
          />
        </label>

        <label className="app-update-field">
          <span>رابط Google Play</span>
          <input
            dir="ltr"
            value={draft.androidStoreUrl}
            onChange={(event) =>
              onDraftChange({ androidStoreUrl: event.target.value })
            }
          />
        </label>

        <label className="app-update-field">
          <span>رابط App Store</span>
          <input
            dir="ltr"
            value={draft.iosStoreUrl}
            onChange={(event) =>
              onDraftChange({ iosStoreUrl: event.target.value })
            }
          />
        </label>

        {policy?.updatedAt ? (
          <p className="app-update-meta">
            آخر تحديث للإعدادات: {formatDate(policy.updatedAt)}
          </p>
        ) : null}

        <button
          className="soft-button success"
          type="button"
          disabled={isSaving}
          onClick={onSave}
        >
          {isSaving ? (
            <LoaderCircle className="spin" size={16} />
          ) : (
            <BadgeCheck size={16} />
          )}
          <span>حفظ الإعدادات</span>
        </button>
      </div>
      )}
    </section>
  );
}
