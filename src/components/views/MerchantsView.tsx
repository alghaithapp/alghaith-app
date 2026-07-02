import React, { useState, useMemo } from 'react';
import { LoaderCircle, Package2, Store, ArrowUpDown, ArrowUp, ArrowDown, Wrench, Stethoscope, Pill } from 'lucide-react';
import type {
  AdminAccountSummary,
  MerchantDetails,
  MerchantFilter,
  MerchantPreRegisterPayload,
  MerchantSummary,
  ProfessionalPreRegisterPayload,
  DoctorPharmacyPreRegisterPayload,
} from '../../admin-types';
import MerchantCard from '../MerchantCard';
import MerchantDetailPanel from './MerchantDetailPanel';
import PreRegisterMerchantModal from '../PreRegisterMerchantModal';
import PreRegisterProfessionalModal from '../PreRegisterProfessionalModal';
import PreRegisterDoctorPharmacyModal from '../PreRegisterDoctorPharmacyModal';

interface MerchantsViewProps {
  merchants: MerchantSummary[];
  search: string;
  merchantFilter: MerchantFilter;
  selectedMerchantPhone: string;
  merchantDetails: MerchantDetails | null;
  isLoadingDetails: boolean;
  activeActionKey: string;
  token: string;
  accounts: AdminAccountSummary[];
  formatMoney: (value: number) => string;
  formatDate: (value: string | null | undefined) => string;
  onSearchChange: (value: string) => void;
  onFilterChange: (filter: MerchantFilter) => void;
  onSelectMerchant: (phone: string) => void;
  onMerchantApproval: (merchant: MerchantSummary) => Promise<void>;
  onMerchantAction: (
    merchant: MerchantSummary,
    action: 'freeze' | 'bazaar',
  ) => Promise<void>;
  onBazaarSync: (merchant: MerchantSummary) => Promise<void>;
  onOpenReject: (target: {
    phone: string;
    displayName: string;
    kind: 'merchant';
  }) => void;
  onOpenDelete: (account: AdminAccountSummary) => void;
  onPreRegisterMerchant: (payload: MerchantPreRegisterPayload) => Promise<void>;
  onPreRegisterProfessional: (payload: ProfessionalPreRegisterPayload) => Promise<void>;
  onPreRegisterDoctorPharmacy?: (payload: DoctorPharmacyPreRegisterPayload) => Promise<void>;
  pendingMerchantQueue: MerchantSummary[];
  approvalQueue: MerchantSummary[];
}

type MerchantSortField = 'storeName' | 'totalRevenue' | 'totalOrders' | 'createdAt' | 'rating';
type SortDir = 'asc' | 'desc';

function serviceLabel(serviceId: string) {
  switch (serviceId) {
    case 'restaurant': return 'مطعم';
    case 'product': return 'متجر';
    case 'real_estate': return 'عقار';
    case 'professionals': return 'مهني';
    default: return serviceId || 'غير محدد';
  }
}

function canRequestBazaarApproval(merchant: MerchantSummary) {
  return (
    merchant.primaryServiceId === 'restaurant' ||
    merchant.primaryServiceId === 'product'
  );
}

function SortIcon({ field, activeField, dir }: { field: MerchantSortField; activeField: MerchantSortField | null; dir: SortDir }) {
  const active = field === activeField;
  if (!active) return <ArrowUpDown size={13} style={{ opacity: 0.4, marginInlineStart: 4 }} />;
  return dir === 'asc'
    ? <ArrowUp size={13} style={{ color: 'var(--brand-primary)', marginInlineStart: 4 }} />
    : <ArrowDown size={13} style={{ color: 'var(--brand-primary)', marginInlineStart: 4 }} />;
}

export default function MerchantsView({
  merchants,
  search,
  merchantFilter,
  selectedMerchantPhone,
  merchantDetails,
  isLoadingDetails,
  activeActionKey,
  token,
  accounts,
  formatMoney,
  formatDate,
  onSearchChange,
  onFilterChange,
  onSelectMerchant,
  onMerchantApproval,
  onMerchantAction,
  onBazaarSync,
  onOpenReject,
  onOpenDelete,
  onPreRegisterMerchant,
  onPreRegisterProfessional,
  onPreRegisterDoctorPharmacy,
  pendingMerchantQueue,
  approvalQueue,
}: MerchantsViewProps) {

  const [showPreRegister, setShowPreRegister] = useState(false);
  const [isPreRegisterBusy, setIsPreRegisterBusy] = useState(false);
  const [showProfessionalRegister, setShowProfessionalRegister] = useState(false);
  const [isProfessionalBusy, setIsProfessionalBusy] = useState(false);
  const [showDoctorPharmacyRegister, setShowDoctorPharmacyRegister] = useState(false);
  const [isDoctorPharmacyBusy, setIsDoctorPharmacyBusy] = useState(false);

  const [sortField, setSortField] = useState<MerchantSortField | null>(null);
  const [sortDir, setSortDir] = useState<SortDir>('desc');

  function toggleSort(field: MerchantSortField) {
    if (sortField === field) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'));
    } else {
      setSortField(field);
      setSortDir('desc');
    }
  }

  const sortedMerchants = useMemo(() => {
    if (!sortField) return merchants;
    return [...merchants].sort((a, b) => {
      const va = (a as any)[sortField] ?? 0;
      const vb = (b as any)[sortField] ?? 0;
      if (typeof va === 'string') {
        return sortDir === 'asc'
          ? va.localeCompare(vb, 'ar')
          : vb.localeCompare(va, 'ar');
      }
      return sortDir === 'asc' ? va - vb : vb - va;
    });
  }, [merchants, sortField, sortDir]);

  const FILTERS: Array<[MerchantFilter, string]> = [
    ['all', `الكل (${merchants.length})`],
    ['pending', `بانتظار الموافقة (${pendingMerchantQueue.length})`],
    ['rejected', 'المرفوضون'],
    ['professionals', 'المهنيون'],
    ['bazaar', `البازار (${approvalQueue.length})`],
  ];

  return (
    <>
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 12, gap: 8, flexWrap: 'wrap' }}>
        <button
          type="button"
          className="ui-btn ui-btn-primary"
          onClick={() => setShowProfessionalRegister(true)}
        >
          <Wrench size={16} />
          إضافة مهني
        </button>
        {onPreRegisterDoctorPharmacy && (
          <button
            type="button"
            className="ui-btn ui-btn-primary"
            onClick={() => setShowDoctorPharmacyRegister(true)}
          >
            <Stethoscope size={16} />
            إضافة طبيب / صيدلية
          </button>
        )}
        <button
          type="button"
          className="ui-btn ui-btn-primary"
          onClick={() => setShowPreRegister(true)}
        >
          + تسجيل تاجر برقم
        </button>
      </div>

      {showProfessionalRegister ? (
        <PreRegisterProfessionalModal
          token={token}
          isBusy={isProfessionalBusy}
          onPreRegister={async (payload) => {
            setIsProfessionalBusy(true);
            try {
              await onPreRegisterProfessional(payload);
              setShowProfessionalRegister(false);
            } finally {
              setIsProfessionalBusy(false);
            }
          }}
          onClose={() => {
            if (!isProfessionalBusy) setShowProfessionalRegister(false);
          }}
        />
      ) : null}

      <PreRegisterMerchantModal
        open={showPreRegister}
        isBusy={isPreRegisterBusy}
        onClose={() => {
          if (!isPreRegisterBusy) setShowPreRegister(false);
        }}
        onSubmit={async (payload) => {
          setIsPreRegisterBusy(true);
          try {
            await onPreRegisterMerchant(payload);
            setShowPreRegister(false);
          } finally {
            setIsPreRegisterBusy(false);
          }
        }}
      />

      {onPreRegisterDoctorPharmacy && (
        <PreRegisterDoctorPharmacyModal
          open={showDoctorPharmacyRegister}
          isBusy={isDoctorPharmacyBusy}
          onClose={() => { if (!isDoctorPharmacyBusy) setShowDoctorPharmacyRegister(false); }}
          onSubmit={async (payload) => {
            setIsDoctorPharmacyBusy(true);
            try {
              await onPreRegisterDoctorPharmacy(payload);
              setShowDoctorPharmacyRegister(false);
            } finally {
              setIsDoctorPharmacyBusy(false);
            }
          }}
        />
      )}

      {/* Filter chips */}
      <div style={{ display: 'flex', gap: '8px', overflowX: 'auto', paddingBottom: '8px', marginBottom: '16px' }}>
        {FILTERS.map(([filter, label]) => (
          <button
            key={filter}
            type="button"
            className={`ui-btn ${merchantFilter === filter ? 'ui-btn-primary' : 'ui-btn-secondary'}`}
            onClick={() => onFilterChange(filter)}
            style={{ borderRadius: '999px', padding: '6px 16px', fontSize: '0.85rem' }}
          >
            {label}
          </button>
        ))}
      </div>

      {/* Sort controls */}
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 24, flexWrap: 'wrap' }}>
        <span style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-muted)' }}>ترتيب حسب:</span>
        {(
          [
            ['storeName', 'الاسم'],
            ['totalRevenue', 'الأرباح'],
            ['totalOrders', 'الطلبات'],
            ['rating', 'التقييم'],
            ['createdAt', 'تاريخ التسجيل'],
          ] as Array<[MerchantSortField, string]>
        ).map(([f, label]) => (
          <button
            key={f}
            type="button"
            className="ui-btn ui-btn-secondary"
            style={{ borderRadius: '999px', padding: '4px 12px', fontSize: '0.8rem', ...(sortField === f ? { background: 'var(--brand-primary-glow)', color: 'var(--brand-primary)', borderColor: 'var(--brand-primary)' } : {}) }}
            onClick={() => toggleSort(f)}
          >
            {label}
            <SortIcon field={f} activeField={sortField} dir={sortDir} />
          </button>
        ))}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(360px, 1fr))', gap: '16px' }}>
        {(() => {
          const items = sortedMerchants;
          const pendingMerchantsList = items.filter(
            (m) => !m.isApproved && m.approvalStatus === 'pending',
          );
          const approvedMerchantsList = items.filter((m) => m.isApproved);
          const otherMerchantsList = items.filter(
            (m) => !m.isApproved && m.approvalStatus !== 'pending',
          );

          // If we're sorting, don't group — show flat list
          if (sortField) {
            return items.map((m) => {
              const freezeLoading = activeActionKey === `freeze:${m.phone}`;
              const bazaarLoading = activeActionKey === `bazaar:${m.phone}`;
              const syncLoading = activeActionKey === `sync:${m.phone}`;
              const approvalLoading = activeActionKey === `merchant-approval:${m.phone}`;
              const rejectLoading = activeActionKey === `reject-account:${m.phone}`;
              const isRejected = m.approvalStatus === 'rejected';
              const isPending = !m.isApproved && !isRejected;
              const selected = selectedMerchantPhone === m.phone;

              return (
                <MerchantCard
                  key={m.phone}
                  merchant={m}
                  isSelected={selected}
                  isPending={isPending}
                  isRejected={isRejected}
                  freezeLoading={freezeLoading}
                  bazaarLoading={bazaarLoading}
                  syncLoading={syncLoading}
                  approvalLoading={approvalLoading}
                  rejectLoading={rejectLoading}
                  onSelect={() => onSelectMerchant(m.phone)}
                  onApprove={() => onMerchantApproval(m)}
                  onReject={() =>
                    onOpenReject({
                      phone: m.phone,
                      displayName: m.storeName || m.fullName || m.phone,
                      kind: 'merchant',
                    })
                  }
                  onFreeze={() => onMerchantAction(m, 'freeze')}
                  onBazaar={() => onMerchantAction(m, 'bazaar')}
                  onSync={() => onBazaarSync(m)}
                  onDelete={() =>
                    onOpenDelete(
                      accounts.find((item) => item.phone === m.phone) ?? {
                        phone: m.phone,
                        displayName: m.storeName || m.fullName || m.phone,
                        fullName: m.fullName,
                        role: m.role,
                        accountType: '',
                        kind: 'merchant' as const,
                        isSuspended: m.isFrozen,
                        needsApproval: !m.isApproved,
                        merchantStoreName: m.storeName,
                        primaryServiceId: m.primaryServiceId,
                        approvalStatus: m.approvalStatus,
                        isApproved: m.isApproved,
                        rejectionMessageAr: m.rejectionMessageAr,
                        courierApproved: false,
                        updatedAt: null,
                        createdAt: m.createdAt,
                        hasMerchantProfile: true,
                        hasCourierProfile: false,
                        hasDriverProfile: false,
                      },
                    )
                  }
                  formatMoney={formatMoney}
                  serviceLabel={serviceLabel}
                  canRequestBazaar={canRequestBazaarApproval(m)}
                />
              );
            });
          }

          const grouped = [
            ...pendingMerchantsList.map((m) => ({ m, group: 'pending' as const })),
            ...approvedMerchantsList.map((m) => ({ m, group: 'approved' as const })),
            ...otherMerchantsList.map((m) => ({ m, group: 'other' as const })),
          ];
          let lastGroup = '';

          return grouped.map(({ m, group }) => {
            const showGroup = group !== lastGroup;
            lastGroup = group;
            const freezeLoading = activeActionKey === `freeze:${m.phone}`;
            const bazaarLoading = activeActionKey === `bazaar:${m.phone}`;
            const syncLoading = activeActionKey === `sync:${m.phone}`;
            const approvalLoading = activeActionKey === `merchant-approval:${m.phone}`;
            const rejectLoading = activeActionKey === `reject-account:${m.phone}`;
            const isRejected = m.approvalStatus === 'rejected';
            const isPending = !m.isApproved && !isRejected;
            const selected = selectedMerchantPhone === m.phone;

            return (
              <React.Fragment key={m.phone}>
                {showGroup && group === 'pending' ? (
                  <div style={{ gridColumn: '1 / -1', padding: '16px 0 8px', borderBottom: '1px solid var(--border)', fontWeight: 800, color: 'var(--brand-primary)' }}>
                    <span>📋 طلبات جديدة ({pendingMerchantsList.length})</span>
                  </div>
                ) : null}
                {showGroup && group === 'approved' ? (
                  <div style={{ gridColumn: '1 / -1', padding: '16px 0 8px', borderBottom: '1px solid var(--border)', fontWeight: 800, color: 'var(--success)' }}>
                    <span>✅ التجار المعتمدون ({approvedMerchantsList.length})</span>
                  </div>
                ) : null}
                {showGroup && group === 'other' ? (
                  <div style={{ gridColumn: '1 / -1', padding: '16px 0 8px', borderBottom: '1px solid var(--border)', fontWeight: 800, color: 'var(--error)' }}>
                    <span>❌ مرفوض ({otherMerchantsList.length})</span>
                  </div>
                ) : null}
                <MerchantCard
                  merchant={m}
                  isSelected={selected}
                  isPending={isPending}
                  isRejected={isRejected}
                  freezeLoading={freezeLoading}
                  bazaarLoading={bazaarLoading}
                  syncLoading={syncLoading}
                  approvalLoading={approvalLoading}
                  rejectLoading={rejectLoading}
                  onSelect={() => onSelectMerchant(m.phone)}
                  onApprove={() => onMerchantApproval(m)}
                  onReject={() =>
                    onOpenReject({
                      phone: m.phone,
                      displayName: m.storeName || m.fullName || m.phone,
                      kind: 'merchant',
                    })
                  }
                  onFreeze={() => onMerchantAction(m, 'freeze')}
                  onBazaar={() => onMerchantAction(m, 'bazaar')}
                  onSync={() => onBazaarSync(m)}
                  onDelete={() =>
                    onOpenDelete(
                      accounts.find((item) => item.phone === m.phone) ?? {
                        phone: m.phone,
                        displayName: m.storeName || m.fullName || m.phone,
                        fullName: m.fullName,
                        role: m.role,
                        accountType: '',
                        kind: 'merchant' as const,
                        isSuspended: m.isFrozen,
                        needsApproval: !m.isApproved,
                        merchantStoreName: m.storeName,
                        primaryServiceId: m.primaryServiceId,
                        approvalStatus: m.approvalStatus,
                        isApproved: m.isApproved,
                        rejectionMessageAr: m.rejectionMessageAr,
                        courierApproved: false,
                        updatedAt: null,
                        createdAt: m.createdAt,
                        hasMerchantProfile: true,
                        hasCourierProfile: false,
                        hasDriverProfile: false,
                      },
                    )
                  }
                  formatMoney={formatMoney}
                  serviceLabel={serviceLabel}
                  canRequestBazaar={canRequestBazaarApproval(m)}
                />
              </React.Fragment>
            );
          });
        })()}

        {merchants.length === 0 ? (
          <div className="empty-state">
            <Package2 size={28} />
            <p>لا يوجد تجار مطابقون للبحث الحالي.</p>
          </div>
        ) : null}
      </div>

      <MerchantDetailPanel
        merchantDetails={merchantDetails}
        isLoadingDetails={isLoadingDetails}
        selectedMerchantPhone={selectedMerchantPhone}
        formatMoney={formatMoney}
        formatDate={formatDate}
      />
    </>
  );
}
