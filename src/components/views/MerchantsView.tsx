import React, { useState, useMemo } from 'react';
import { LoaderCircle, Package2, Store, ArrowUpDown, ArrowUp, ArrowDown } from 'lucide-react';
import type {
  AdminAccountSummary,
  MerchantDetails,
  MerchantFilter,
  MerchantPreRegisterPayload,
  MerchantSummary,
} from '../../admin-types';
import MerchantCard from '../MerchantCard';
import MerchantDetailPanel from './MerchantDetailPanel';
import PreRegisterMerchantModal from '../PreRegisterMerchantModal';

interface MerchantsViewProps {
  merchants: MerchantSummary[];
  search: string;
  merchantFilter: MerchantFilter;
  selectedMerchantPhone: string;
  merchantDetails: MerchantDetails | null;
  isLoadingDetails: boolean;
  activeActionKey: string;
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
  pendingMerchantQueue,
  approvalQueue,
}: MerchantsViewProps) {

  const [showPreRegister, setShowPreRegister] = useState(false);
  const [isPreRegisterBusy, setIsPreRegisterBusy] = useState(false);

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
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 12 }}>
        <button
          type="button"
          className="primary-button"
          onClick={() => setShowPreRegister(true)}
        >
          + تسجيل تاجر برقم
        </button>
      </div>

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

      {/* Filter chips */}
      <div className="account-filter-row">
        {FILTERS.map(([filter, label]) => (
          <button
            key={filter}
            type="button"
            className={
              merchantFilter === filter
                ? 'filter-chip active'
                : 'filter-chip'
            }
            onClick={() => onFilterChange(filter)}
          >
            {label}
          </button>
        ))}
      </div>

      {/* Sort controls */}
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 16, flexWrap: 'wrap' }}>
        <span className="sort-label">ترتيب حسب:</span>
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
            className="filter-chip"
            style={sortField === f ? { background: 'var(--brand-primary-glow)', color: 'var(--brand-primary)', borderColor: 'var(--brand-primary)' } : undefined}
            onClick={() => toggleSort(f)}
          >
            {label}
            <SortIcon field={f} activeField={sortField} dir={sortDir} />
          </button>
        ))}
      </div>

      <div className="merchant-list">
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
                  <div className="section-divider">
                    <span>📋 طلبات جديدة ({pendingMerchantsList.length})</span>
                  </div>
                ) : null}
                {showGroup && group === 'approved' ? (
                  <div className="section-divider">
                    <span>✅ التجار المعتمدون ({approvedMerchantsList.length})</span>
                  </div>
                ) : null}
                {showGroup && group === 'other' ? (
                  <div className="section-divider">
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
