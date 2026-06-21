import React, { useState } from 'react';
import { Bike, BadgeCheck, XCircle, UserX, Trash2, LoaderCircle, ExternalLink, Images } from 'lucide-react';
import type { CourierSummary, AdminAccountSummary } from '../../admin-types';
import DocumentsModal from '../DocumentsModal';

interface CouriersViewProps {
  couriers: CourierSummary[];
  filteredCouriers: CourierSummary[];
  search: string;
  activeActionKey: string;
  accounts: AdminAccountSummary[];
  onSearchChange: (value: string) => void;
  onCourierApproval: (courier: CourierSummary) => Promise<void>;
  onOpenReject: (target: {
    phone: string;
    displayName: string;
    kind: 'courier';
  }) => void;
  onSuspend: (account: AdminAccountSummary) => Promise<void>;
  onOpenDelete: (account: AdminAccountSummary) => void;
}

export default function CouriersView({
  couriers: _couriers,
  filteredCouriers,
  search: _search,
  activeActionKey,
  accounts,
  onSearchChange: _onSearchChange,
  onCourierApproval,
  onOpenReject,
  onSuspend,
  onOpenDelete,
}: CouriersViewProps) {
  const [selectedDocumentsTarget, setSelectedDocumentsTarget] = useState<{
    displayName: string;
    documents: Record<string, string>;
  } | null>(null);

  return (
    <div className="merchant-list">
      {(() => {
        const pendingCouriersList = filteredCouriers.filter(
          (c) => !c.isApproved && c.approvalStatus === 'pending',
        );
        const approvedCouriersList = filteredCouriers.filter((c) => c.isApproved);
        const rejectedCouriersList = filteredCouriers.filter(
          (c) => !c.isApproved && c.approvalStatus === 'rejected',
        );
        const grouped = [
          ...pendingCouriersList.map((c) => ({
            c,
            group: 'pending' as const,
          })),
          ...approvedCouriersList.map((c) => ({
            c,
            group: 'approved' as const,
          })),
          ...rejectedCouriersList.map((c) => ({
            c,
            group: 'rejected' as const,
          })),
        ];
        let lastGroup = '';
        return grouped.map(({ c, group }) => {
          const showGroup = group !== lastGroup;
          lastGroup = group;
          const approvalLoading =
            activeActionKey === `courier:${c.phone}`;
          const rejectLoading =
            activeActionKey === `reject-account:${c.phone}`;
          const isRejected = c.approvalStatus === 'rejected';
          const isPending = !c.isApproved && !isRejected;
          return (
            <React.Fragment key={c.phone}>
              {showGroup && group === 'pending' ? (
                <div className="section-divider">
                  <span>
                    📋 مندوبون بانتظار التفعيل ({pendingCouriersList.length})
                  </span>
                </div>
              ) : null}
              {showGroup && group === 'approved' ? (
                <div className="section-divider">
                  <span>
                    ✅ المندوبون النشطون ({approvedCouriersList.length})
                  </span>
                </div>
              ) : null}
              {showGroup && group === 'rejected' ? (
                <div className="section-divider">
                  <span>
                    ❌ مرفوض ({rejectedCouriersList.length})
                  </span>
                </div>
              ) : null}
              <article className="merchant-card courier-card">
                <div className="merchant-main">
                  <div className="courier-card-leading">
                    <div className="courier-avatar">
                      <Bike size={28} />
                    </div>
                    <div>
                      <div className="merchant-title-row">
                        <h4>{c.name || 'مندوب بدون اسم'}</h4>
                        {c.isApproved ? (
                          <span className="status-badge success">مفعّل</span>
                        ) : isRejected ? (
                          <span className="status-badge danger">مرفوض</span>
                        ) : (
                          <span className="status-badge danger">
                            بانتظار الموافقة
                          </span>
                        )}
                        {c.isSuspended ? (
                          <span className="status-badge danger">معلّق</span>
                        ) : null}
                        {c.isApproved ? (
                          c.available ? (
                            <span className="status-badge success">
                              متاح للتوصيل
                            </span>
                          ) : (
                            <span className="status-badge muted">
                              غير متاح
                            </span>
                          )
                        ) : null}
                      </div>
                      <p className="merchant-meta">
                        هاتف التواصل:{' '}
                        <span dir="ltr">{c.contactPhone || c.phone}</span>
                      </p>
                      <p className="merchant-description">
                        {c.homeAddress || 'لا يوجد عنوان محفوظ.'}
                      </p>
                      {isRejected && c.rejectionMessageAr ? (
                        <p className="courier-rejection-note">
                          سبب الرفض: {c.rejectionMessageAr}
                        </p>
                      ) : null}
                    </div>
                  </div>
                  <div className="courier-media-panel">
                    <div className="courier-media-head">
                      <strong>صورة الدراجة</strong>
                      {c.vehicleImage ? (
                        <a
                          className="courier-media-link"
                          href={c.vehicleImage}
                          target="_blank"
                          rel="noreferrer"
                        >
                          <ExternalLink size={14} />
                          <span>عرض بالحجم الكامل</span>
                        </a>
                      ) : null}
                    </div>
                    {c.vehicleImage ? (
                      <a
                        href={c.vehicleImage}
                        target="_blank"
                        rel="noreferrer"
                        className="courier-media-frame"
                      >
                        <img
                          className="courier-media-image"
                          src={c.vehicleImage}
                          alt={c.name || 'صورة الدراجة'}
                          loading="lazy"
                          referrerPolicy="no-referrer"
                        />
                      </a>
                    ) : (
                      <div className="courier-media-empty">
                        <Bike size={28} />
                        <span>لم يتم رفع صورة للدراجة</span>
                      </div>
                    )}
                  </div>
                </div>
                <div className="merchant-actions">
                  {/* View Documents */}
                  {c.documents && Object.values(c.documents).some(url => url && url.trim() !== '') ? (
                    <button
                      className="soft-button secondary"
                      onClick={() => setSelectedDocumentsTarget({
                        displayName: c.name || c.phone || 'مندوب بدون اسم',
                        documents: c.documents!
                      })}
                    >
                      <Images size={16} />
                      <span>عرض المستندات</span>
                    </button>
                  ) : null}

                  <button
                    className={
                      c.isApproved
                        ? 'soft-button danger'
                        : 'soft-button success'
                    }
                    disabled={approvalLoading || rejectLoading}
                    onClick={() => {
                      onCourierApproval(c).catch(() => undefined);
                    }}
                  >
                    {approvalLoading ? (
                      <LoaderCircle className="spin" size={16} />
                    ) : (
                      <BadgeCheck size={16} />
                    )}
                    <span>
                      {c.isApproved ? 'إلغاء التفعيل' : 'موافقة وتفعيل'}
                    </span>
                  </button>
                  {isPending || isRejected ? (
                    <button
                      className="soft-button danger"
                      disabled={approvalLoading || rejectLoading}
                      onClick={() => {
                        onOpenReject({
                          phone: c.phone,
                          displayName: c.name || c.phone,
                          kind: 'courier',
                        });
                      }}
                    >
                      {rejectLoading ? (
                        <LoaderCircle className="spin" size={16} />
                      ) : (
                        <XCircle size={16} />
                      )}
                      <span>رفض الطلب</span>
                    </button>
                  ) : null}
                  <button
                    className={
                      c.isSuspended
                        ? 'soft-button success'
                        : 'soft-button danger'
                    }
                    disabled={
                      approvalLoading ||
                      rejectLoading ||
                      activeActionKey === `suspend-account:${c.phone}`
                    }
                    onClick={() => {
                      const account =
                        accounts.find((item) => item.phone === c.phone) ??
                        ({
                          phone: c.phone,
                          displayName: c.name || c.phone,
                          fullName: c.name,
                          role: c.role,
                          accountType: c.accountType,
                          kind: 'courier' as const,
                          isSuspended: c.isSuspended === true,
                          merchantStoreName: '',
                          primaryServiceId: '',
                          courierApproved: c.isApproved,
                          updatedAt: c.updatedAt,
                          createdAt: null,
                          hasMerchantProfile: false,
                          hasCourierProfile: true,
                          hasDriverProfile: false,
                        } as AdminAccountSummary);
                      onSuspend(account).catch(() => undefined);
                    }}
                  >
                    {activeActionKey === `suspend-account:${c.phone}` ? (
                      <LoaderCircle className="spin" size={16} />
                    ) : (
                      <UserX size={16} />
                    )}
                    <span>
                      {c.isSuspended ? 'فك التعليق' : 'تعليق الحساب'}
                    </span>
                  </button>
                  <button
                    className="soft-button danger"
                    disabled={approvalLoading || rejectLoading}
                    onClick={() => {
                      onOpenDelete(
                        accounts.find((item) => item.phone === c.phone) ??
                          ({
                            phone: c.phone,
                            displayName: c.name || c.phone,
                            fullName: c.name,
                            role: c.role,
                            accountType: c.accountType,
                            kind: 'courier',
                            isSuspended: c.isSuspended === true,
                            merchantStoreName: '',
                            primaryServiceId: '',
                            courierApproved: c.isApproved,
                            updatedAt: c.updatedAt,
                            createdAt: null,
                            hasMerchantProfile: false,
                            hasCourierProfile: true,
                            hasDriverProfile: false,
                          } as AdminAccountSummary),
                      );
                    }}
                  >
                    <Trash2 size={16} />
                    <span>حذف الحساب</span>
                  </button>
                </div>
              </article>
            </React.Fragment>
          );
        });
      })()}
      {filteredCouriers.length === 0 ? (
        <div className="empty-state">
          <Bike size={22} />
          <p>لا يوجد مندوبو توصيل مطابقون للبحث الحالي.</p>
        </div>
      ) : null}

      {selectedDocumentsTarget && (
        <DocumentsModal
          displayName={selectedDocumentsTarget.displayName}
          documents={selectedDocumentsTarget.documents}
          onClose={() => setSelectedDocumentsTarget(null)}
        />
      )}
    </div>
  );
}
