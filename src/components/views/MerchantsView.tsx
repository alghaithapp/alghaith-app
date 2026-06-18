import React from 'react';
import { LoaderCircle, Package2, Store } from 'lucide-react';
import type {
  AdminAccountSummary,
  MerchantDetails,
  MerchantFilter,
  MerchantSummary,
} from '../../admin-types';
import MerchantCard from '../MerchantCard';
import MerchantDetailPanel from './MerchantDetailPanel';

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
  pendingMerchantQueue: MerchantSummary[];
  approvalQueue: MerchantSummary[];
}

function serviceLabel(serviceId: string) {
  switch (serviceId) {
    case 'restaurant':
      return 'مطعم';
    case 'product':
      return 'متجر';
    case 'real_estate':
      return 'عقار';
    case 'professionals':
      return 'مهني';
    default:
      return serviceId || 'غير محدد';
  }
}

function canRequestBazaarApproval(merchant: MerchantSummary) {
  return (
    merchant.primaryServiceId === 'restaurant' ||
    merchant.primaryServiceId === 'product'
  );
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
  pendingMerchantQueue,
  approvalQueue,
}: MerchantsViewProps) {
  return (
    <>
      <div className="account-filter-row">
        {(
          [
            ['all', `الكل (${merchants.length})`],
            [
              'pending',
              `بانتظار الموافقة (${pendingMerchantQueue.length})`,
            ],
            ['rejected', `المرفوضون`],
            ['professionals', 'المهنيون'],
            ['bazaar', `البازار (${approvalQueue.length})`],
          ] as Array<[MerchantFilter, string]>
        ).map(([filter, label]) => (
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
      <div className="merchant-list">
        {(() => {
          const items = merchants;
          const pendingMerchantsList = items.filter(
            (m) => !m.isApproved && m.approvalStatus === 'pending',
          );
          const approvedMerchantsList = items.filter((m) => m.isApproved);
          const otherMerchantsList = items.filter(
            (m) => !m.isApproved && m.approvalStatus !== 'pending',
          );
          const grouped = [
            ...pendingMerchantsList.map((m) => ({
              m,
              group: 'pending' as const,
            })),
            ...approvedMerchantsList.map((m) => ({
              m,
              group: 'approved' as const,
            })),
            ...otherMerchantsList.map((m) => ({
              m,
              group: 'other' as const,
            })),
          ];
          let lastGroup = '';
          return grouped.map(({ m, group }) => {
            const showGroup = group !== lastGroup;
            lastGroup = group;
            const freezeLoading =
              activeActionKey === `freeze:${m.phone}`;
            const bazaarLoading =
              activeActionKey === `bazaar:${m.phone}`;
            const syncLoading =
              activeActionKey === `sync:${m.phone}`;
            const approvalLoading =
              activeActionKey === `merchant-approval:${m.phone}`;
            const rejectLoading =
              activeActionKey === `reject-account:${m.phone}`;
            const isRejected = m.approvalStatus === 'rejected';
            const isPending = !m.isApproved && !isRejected;
            const selected = selectedMerchantPhone === m.phone;
            return (
              <React.Fragment key={m.phone}>
                {showGroup && group === 'pending' ? (
                  <div className="section-divider">
                    <span>
                      📋 طلبات جديدة ({pendingMerchantsList.length})
                    </span>
                  </div>
                ) : null}
                {showGroup && group === 'approved' ? (
                  <div className="section-divider">
                    <span>
                      ✅ التجار المعتمدون ({approvedMerchantsList.length})
                    </span>
                  </div>
                ) : null}
                {showGroup && group === 'other' ? (
                  <div className="section-divider">
                    <span>
                      ❌ مرفوض ({otherMerchantsList.length})
                    </span>
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
                      displayName:
                        m.storeName || m.fullName || m.phone,
                      kind: 'merchant',
                    })
                  }
                  onFreeze={() => onMerchantAction(m, 'freeze')}
                  onBazaar={() => onMerchantAction(m, 'bazaar')}
                  onSync={() => onBazaarSync(m)}
                  onDelete={() =>
                    onOpenDelete(
                      accounts.find(
                        (item) => item.phone === m.phone,
                      ) ?? {
                        phone: m.phone,
                        displayName:
                          m.storeName || m.fullName || m.phone,
                        fullName: m.fullName,
                        role: m.role,
                        accountType: '',
                        kind: 'merchant' as const,
                        isSuspended: m.isFrozen,
                        merchantStoreName: m.storeName,
                        primaryServiceId: m.primaryServiceId,
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
            <Package2 size={22} />
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
