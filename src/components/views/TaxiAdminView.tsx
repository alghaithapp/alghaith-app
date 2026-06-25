import React, { useMemo, useState } from 'react';
import { AlertTriangle, Car, LoaderCircle, MapPin, Star } from 'lucide-react';
import type { AdminTaxiTrip } from '../../admin-types';

interface TaxiAdminViewProps {
  trips: AdminTaxiTrip[];
  complaints: AdminTaxiTrip[];
  loading: boolean;
  statusFilter: string;
  onStatusFilterChange: (value: string) => void;
  onRefresh: () => Promise<void>;
}

const STATUS_OPTIONS = [
  { value: '', label: 'كل الحالات' },
  { value: 'pending', label: 'بانتظار سائق' },
  { value: 'accepted', label: 'مقبولة' },
  { value: 'arrived', label: 'وصل السائق' },
  { value: 'picked_up', label: 'في الرحلة' },
  { value: 'completed', label: 'مكتملة' },
  { value: 'cancelled', label: 'ملغاة' },
  { value: 'cancel_requested', label: 'طلب إلغاء' },
];

function formatDate(value: string | null | undefined) {
  if (!value) return '—';
  try {
    return new Intl.DateTimeFormat('ar-IQ', {
      dateStyle: 'short',
      timeStyle: 'short',
    }).format(new Date(value));
  } catch {
    return value;
  }
}

function statusLabel(statusKey: string) {
  return STATUS_OPTIONS.find((item) => item.value === statusKey)?.label ?? statusKey;
}

function TripRow({ trip }: { trip: AdminTaxiTrip }) {
  return (
    <article className="merchant-card taxi-trip-card">
      <div className="merchant-card-header">
        <div>
          <h4>{trip.requestNumber || trip.id.slice(0, 8)}</h4>
          <p className="merchant-card-subtitle">
            {statusLabel(trip.statusKey)} · {trip.taxiType}
          </p>
        </div>
        <span className="panel-chip">{trip.fare?.toLocaleString('ar-IQ')} د.ع</span>
      </div>
      <div className="taxi-trip-meta">
        <p>
          <MapPin size={14} /> {trip.pickupAddress}
        </p>
        <p>
          <MapPin size={14} /> {trip.dropoffAddress}
        </p>
      </div>
      <div className="merchant-card-footer">
        <span>الزبون: {trip.customerPhone || '—'}</span>
        <span>السائق: {trip.driverName || trip.driverPhone || '—'}</span>
        <span>قبول: {formatDate(trip.acceptedAt)}</span>
        <span>إنهاء: {formatDate(trip.completedAt)}</span>
      </div>
    </article>
  );
}

export default function TaxiAdminView({
  trips,
  complaints,
  loading,
  statusFilter,
  onStatusFilterChange,
  onRefresh,
}: TaxiAdminViewProps) {
  const [tab, setTab] = useState<'trips' | 'complaints'>('trips');

  const activeTrips = useMemo(
    () =>
      trips.filter((trip) =>
        !['completed', 'cancelled'].includes(String(trip.statusKey || '').trim()),
      ),
    [trips],
  );

  return (
    <div className="taxi-admin-view">
      <div className="taxi-admin-toolbar">
        <div className="taxi-admin-tabs">
          <button
            type="button"
            className={tab === 'trips' ? 'tab-btn active' : 'tab-btn'}
            onClick={() => setTab('trips')}
          >
            <Car size={16} />
            الرحلات ({trips.length})
          </button>
          <button
            type="button"
            className={tab === 'complaints' ? 'tab-btn active' : 'tab-btn'}
            onClick={() => setTab('complaints')}
          >
            <AlertTriangle size={16} />
            شكاوى التقييم ({complaints.length})
          </button>
        </div>

        <div className="taxi-admin-actions">
          {tab === 'trips' ? (
            <select
              className="search-input"
              value={statusFilter}
              onChange={(event) => onStatusFilterChange(event.target.value)}
            >
              {STATUS_OPTIONS.map((option) => (
                <option key={option.value || 'all'} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          ) : null}
          <button type="button" className="ghost-btn" onClick={() => void onRefresh()}>
            تحديث
          </button>
        </div>
      </div>

      {loading ? (
        <div className="empty-state">
          <LoaderCircle className="spin" size={28} />
          <p>جاري تحميل بيانات التكسي...</p>
        </div>
      ) : null}

      {!loading && tab === 'trips' ? (
        <>
          <div className="taxi-admin-summary">
            <span>نشطة الآن: {activeTrips.length}</span>
            <span>إجمالي المعروض: {trips.length}</span>
          </div>
          {trips.length === 0 ? (
            <div className="empty-state">
              <Car size={32} />
              <p>لا توجد رحلات مطابقة للفلتر الحالي.</p>
            </div>
          ) : (
            <div className="merchant-list">
              {trips.map((trip) => (
                <TripRow key={trip.id} trip={trip} />
              ))}
            </div>
          )}
        </>
      ) : null}

      {!loading && tab === 'complaints' ? (
        complaints.length === 0 ? (
          <div className="empty-state">
            <Star size={32} />
            <p>لا توجد تقييمات منخفضة أو شكاوى بانتظار المراجعة.</p>
          </div>
        ) : (
          <div className="merchant-list">
            {complaints.map((trip) => (
              <article key={trip.id} className="merchant-card taxi-complaint-card">
                <div className="merchant-card-header">
                  <div>
                    <h4>{trip.requestNumber}</h4>
                    <p className="merchant-card-subtitle">
                      تقييم: {trip.driverRating}/5 · {trip.driverName || 'سائق'}
                    </p>
                  </div>
                  <span className="panel-chip warning">مراجعة مطلوبة</span>
                </div>
                <p>{trip.ratingComment || trip.cancellationReason || 'بدون تعليق'}</p>
                <div className="merchant-card-footer">
                  <span>الزبون: {trip.customerPhone || '—'}</span>
                  <span>السائق: {trip.driverPhone || '—'}</span>
                  <span>{formatDate(trip.completedAt)}</span>
                </div>
              </article>
            ))}
          </div>
        )
      ) : null}
    </div>
  );
}
