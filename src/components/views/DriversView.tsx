import React, { useState } from 'react';
import { Car, BadgeCheck, XCircle, UserX, Trash2, LoaderCircle, Images } from 'lucide-react';
import type { AdminAccountSummary, DriverPreRegisterPayload } from '../../admin-types';
import { driverApprovalFor } from '../../admin-account-utils';
import DocumentsModal from '../DocumentsModal';
import PreRegisterDriverModal from '../PreRegisterDriverModal';

interface DriversViewProps {
  drivers: AdminAccountSummary[];
  filteredDrivers: AdminAccountSummary[];
  search: string;
  activeActionKey: string;
  accounts: AdminAccountSummary[];
  onSearchChange: (value: string) => void;
  onApproveAccount: (account: AdminAccountSummary) => Promise<void>;
  onOpenReject: (target: { phone: string; displayName: string; kind: string }) => void;
  onSuspend: (account: AdminAccountSummary) => Promise<void>;
  onOpenDelete: (account: AdminAccountSummary) => void;
  onPreRegisterDriver: (payload: DriverPreRegisterPayload) => Promise<void>;
}

function formatDate(value: string | null | undefined) {
  if (!value) return '—';
  try {
    return new Intl.DateTimeFormat('ar-IQ', { dateStyle: 'medium' }).format(new Date(value));
  } catch {
    return value;
  }
}

export default function DriversView({
  drivers: _drivers,
  filteredDrivers,
  search: _search,
  activeActionKey,
  accounts: _accounts,
  onSearchChange: _onSearchChange,
  onApproveAccount,
  onOpenReject,
  onSuspend,
  onOpenDelete,
  onPreRegisterDriver,
}: DriversViewProps) {
  const [showPreRegister, setShowPreRegister] = useState(false);
  const [isPreRegisterBusy, setIsPreRegisterBusy] = useState(false);
  const [selectedDocumentsTarget, setSelectedDocumentsTarget] = useState<{
    displayName: string;
    documents: Record<string, string>;
  } | null>(null);

  const pendingList   = filteredDrivers.filter((d) => {
    const a = driverApprovalFor(d);
    return !a.isApproved && a.approvalStatus === 'pending';
  });
  const approvedList  = filteredDrivers.filter((d) => driverApprovalFor(d).isApproved);
  const rejectedList  = filteredDrivers.filter((d) => {
    const a = driverApprovalFor(d);
    return !a.isApproved && a.approvalStatus === 'rejected';
  });

  const grouped = [
    ...pendingList.map((d)  => ({ d, group: 'pending'  as const })),
    ...approvedList.map((d) => ({ d, group: 'approved' as const })),
    ...rejectedList.map((d) => ({ d, group: 'rejected' as const })),
  ];

  if (filteredDrivers.length === 0) {
    return (
      <>
        <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 12 }}>
          <button
            type="button"
            className="primary-button"
            onClick={() => setShowPreRegister(true)}
          >
            + تسجيل سائق برقم
          </button>
        </div>
        <PreRegisterDriverModal
          open={showPreRegister}
          isBusy={isPreRegisterBusy}
          onClose={() => {
            if (!isPreRegisterBusy) setShowPreRegister(false);
          }}
          onSubmit={async (payload) => {
            setIsPreRegisterBusy(true);
            try {
              await onPreRegisterDriver(payload);
              setShowPreRegister(false);
            } finally {
              setIsPreRegisterBusy(false);
            }
          }}
        />
        <div className="empty-state">
          <Car size={32} />
          <p>لا يوجد سائقو تكسي مطابقون للبحث الحالي.</p>
        </div>
      </>
    );
  }

  let lastGroup = '';

  return (
  <>
    <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 12 }}>
      <button
        type="button"
        className="primary-button"
        onClick={() => setShowPreRegister(true)}
      >
        + تسجيل سائق برقم
      </button>
    </div>

    <PreRegisterDriverModal
      open={showPreRegister}
      isBusy={isPreRegisterBusy}
      onClose={() => {
        if (!isPreRegisterBusy) setShowPreRegister(false);
      }}
      onSubmit={async (payload) => {
        setIsPreRegisterBusy(true);
        try {
          await onPreRegisterDriver(payload);
          setShowPreRegister(false);
        } finally {
          setIsPreRegisterBusy(false);
        }
      }}
    />

    <div className="merchant-list">
      {grouped.map(({ d, group }) => {
        const showGroup = group !== lastGroup;
        lastGroup = group;
        const approvalLoading = activeActionKey === `approve-account:${d.phone}`;
        const rejectLoading   = activeActionKey === `reject-account:${d.phone}`;
        const suspendLoading  = activeActionKey === `suspend-account:${d.phone}`;
        const deleteLoading   = activeActionKey === `delete-account:${d.phone}`;
        const approval = driverApprovalFor(d);
        const isRejected = approval.approvalStatus === 'rejected';
        const isPending  = !approval.isApproved && !isRejected;

        return (
          <React.Fragment key={d.phone}>
            {showGroup && group === 'pending' ? (
              <div className="section-divider">
                <span>📋 سائقون بانتظار التفعيل ({pendingList.length})</span>
              </div>
            ) : null}
            {showGroup && group === 'approved' ? (
              <div className="section-divider">
                <span>✅ السائقون النشطون ({approvedList.length})</span>
              </div>
            ) : null}
            {showGroup && group === 'rejected' ? (
              <div className="section-divider">
                <span>❌ مرفوض ({rejectedList.length})</span>
              </div>
            ) : null}

            <article className="merchant-card courier-card">
              <div className="merchant-main">
                <div className="courier-card-leading">
                  {/* Avatar placeholder */}
                  <div className="courier-avatar placeholder">
                    <Car size={26} style={{ color: 'var(--color-driver)' }} />
                  </div>
                  <div style={{ flex: 1 }}>
                    <div className="merchant-title-row">
                      <h4>{d.displayName || d.fullName || 'سائق بدون اسم'}</h4>
                      {/* Approval status */}
                      {approval.isApproved ? (
                        <span className="status-badge success">مفعّل</span>
                      ) : isRejected ? (
                        <span className="status-badge danger">مرفوض</span>
                      ) : (
                        <span className="status-badge warning">بانتظار الموافقة</span>
                      )}
                      {/* Suspension */}
                      {d.isSuspended ? (
                        <span className="status-badge danger">معلّق</span>
                      ) : null}
                      {/* Type badge */}
                      <span className="status-badge" style={{ background: 'rgba(167,139,250,0.12)', color: 'var(--color-driver)', border: '1px solid rgba(167,139,250,0.25)' }}>
                        سائق تكسي
                      </span>
                    </div>
                    <p className="merchant-meta">
                      هاتف التواصل: <span dir="ltr">{d.phone}</span>
                    </p>
                    <p className="merchant-description">
                      تاريخ التسجيل: {formatDate(d.createdAt)}
                    </p>
                    {approval.isApproved && d.driverProfileComplete === false ? (
                      <p className="merchant-description" style={{ color: 'var(--color-driver)' }}>
                        مُسجَّل مسبقاً — بانتظار إكمال بيانات السائق في التطبيق
                      </p>
                    ) : null}
                    {isRejected && d.rejectionMessageAr ? (
                      <p className="courier-rejection-note">
                        سبب الرفض: {d.rejectionMessageAr}
                      </p>
                    ) : null}
                  </div>
                </div>
              </div>

              {/* Actions */}
              <div className="merchant-actions">
                {/* View Documents */}
                {d.documents && Object.values(d.documents).some(url => url && url.trim() !== '') ? (
                  <button
                    className="soft-button secondary"
                    onClick={() => setSelectedDocumentsTarget({
                      displayName: d.displayName || d.fullName || 'سائق بدون اسم',
                      documents: d.documents!
                    })}
                  >
                    <Images size={15} />
                    <span>عرض المستندات</span>
                  </button>
                ) : null}

                {/* Approve / deactivate */}
                <button
                  className={approval.isApproved ? 'soft-button danger' : 'soft-button success'}
                  disabled={approvalLoading || rejectLoading || suspendLoading}
                  onClick={() => onApproveAccount(d).catch(() => undefined)}
                >
                  {approvalLoading ? (
                    <LoaderCircle className="spin" size={15} />
                  ) : (
                    <BadgeCheck size={15} />
                  )}
                  <span>{approval.isApproved ? 'إلغاء التفعيل' : 'موافقة وتفعيل'}</span>
                </button>

                {/* Reject */}
                {(isPending || isRejected) ? (
                  <button
                    className="soft-button danger"
                    disabled={approvalLoading || rejectLoading}
                    onClick={() =>
                      onOpenReject({
                        phone: d.phone,
                        displayName: d.displayName || d.phone,
                        kind: d.kind,
                      })
                    }
                  >
                    {rejectLoading ? (
                      <LoaderCircle className="spin" size={15} />
                    ) : (
                      <XCircle size={15} />
                    )}
                    <span>رفض</span>
                  </button>
                ) : null}

                {/* Suspend / Unsuspend */}
                <button
                  className="soft-button secondary"
                  disabled={suspendLoading || deleteLoading}
                  onClick={() => onSuspend(d).catch(() => undefined)}
                >
                  {suspendLoading ? (
                    <LoaderCircle className="spin" size={15} />
                  ) : (
                    <UserX size={15} />
                  )}
                  <span>{d.isSuspended ? 'إلغاء التعليق' : 'تجميد الحساب'}</span>
                </button>

                {/* Delete */}
                <button
                  className="soft-button danger"
                  disabled={deleteLoading || suspendLoading}
                  onClick={() => onOpenDelete(d)}
                >
                  {deleteLoading ? (
                    <LoaderCircle className="spin" size={15} />
                  ) : (
                    <Trash2 size={15} />
                  )}
                  <span>حذف الحساب</span>
                </button>
              </div>
            </article>
          </React.Fragment>
        );
      })}

      {selectedDocumentsTarget && (
        <DocumentsModal
          displayName={selectedDocumentsTarget.displayName}
          documents={selectedDocumentsTarget.documents}
          onClose={() => setSelectedDocumentsTarget(null)}
        />
      )}
    </div>
  </>
  );
}
