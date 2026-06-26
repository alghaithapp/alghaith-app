import { BadgeCheck, LoaderCircle } from 'lucide-react';
import type { MaintenancePolicy } from '../../admin-types';

interface MaintenanceViewProps {
  policy: MaintenancePolicy | null;
  draft: {
    enabled: boolean;
    messageAr: string;
    messageEn: string;
    allowAdminBypass: boolean;
  } | null;
  isSaving: boolean;
  onDraftChange: (draft: Partial<MaintenanceViewProps['draft']>) => void;
  onSave: () => void;
  formatDate: (value: string | null | undefined) => string;
}

export default function MaintenanceView({
  policy,
  draft,
  isSaving,
  onDraftChange,
  onSave,
  formatDate,
}: MaintenanceViewProps) {
  return (
    <section className="panel app-update-panel">
      <div className="panel-header">
        <div>
          <h3>وضع الصيانة</h3>
          <p>
            عند التفعيل تظهر للمستخدمين شاشة صيانة ولا يمكنهم استخدام التطبيق حتى
            إيقاف الوضع. لا حاجة لرفع تحديث جديد.
          </p>
        </div>
        {draft?.enabled ? (
          <p className="app-update-meta" style={{ color: 'var(--warning-text, #b45309)', fontWeight: 700 }}>
            الصيانة مفعّلة حالياً — المستخدمون محجوبون
          </p>
        ) : null}
      </div>

      {!draft ? (
        <div className="loading-state compact">
          <LoaderCircle className="spin" size={22} />
          <span>جار تحميل الإعدادات...</span>
        </div>
      ) : (
        <div className="app-update-form">
          <label className="app-update-field">
            <span>تفعيل وضع الصيانة</span>
            <label className="platform-toggle">
              <span>مفعّل</span>
              <input
                type="checkbox"
                checked={draft.enabled}
                onChange={(event) =>
                  onDraftChange({ enabled: event.target.checked })
                }
              />
              <em>
                عند التفعيل يُحجب التطبيق فوراً لجميع المستخدمين (ما عدا المشرفين إن
                سمحت بذلك أدناه).
              </em>
            </label>
          </label>

          <label className="app-update-field">
            <span>الرسالة للمستخدم (عربي)</span>
            <textarea
              rows={4}
              value={draft.messageAr}
              onChange={(event) =>
                onDraftChange({ messageAr: event.target.value })
              }
            />
          </label>

          <label className="app-update-field">
            <span>الرسالة للمستخدم (إنجليزي — اختياري)</span>
            <textarea
              rows={3}
              value={draft.messageEn}
              onChange={(event) =>
                onDraftChange({ messageEn: event.target.value })
              }
            />
          </label>

          <label className="app-update-field">
            <span>السماح للمشرفين بتجاوز الصيانة</span>
            <label className="platform-toggle">
              <span>مسموح</span>
              <input
                type="checkbox"
                checked={draft.allowAdminBypass}
                onChange={(event) =>
                  onDraftChange({ allowAdminBypass: event.target.checked })
                }
              />
              <em>
                يفيدك أثناء الصيانة لاختبار التطبيق بحساب مشرف دون إيقاف الوضع
                للجميع.
              </em>
            </label>
          </label>

          {policy?.updatedAt ? (
            <p className="app-update-meta">
              آخر تحديث للإعدادات: {formatDate(policy.updatedAt)}
            </p>
          ) : null}

          <button
            className={draft.enabled ? 'soft-button warning' : 'soft-button success'}
            type="button"
            disabled={isSaving}
            onClick={onSave}
          >
            {isSaving ? (
              <LoaderCircle className="spin" size={16} />
            ) : (
              <BadgeCheck size={16} />
            )}
            <span>{draft.enabled ? 'تفعيل الصيانة وحفظ' : 'حفظ الإعدادات'}</span>
          </button>
        </div>
      )}
    </section>
  );
}
