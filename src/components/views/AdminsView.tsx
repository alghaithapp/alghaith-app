import React, { useState } from 'react';
import {
  Shield,
  ShieldCheck,
  ShieldAlert,
  LoaderCircle,
  Plus,
  Trash2,
  X,
} from 'lucide-react';
import type { AdminPermissions, AdminSummary } from '../../admin-types';

interface AdminsViewProps {
  admins: AdminSummary[];
  myPermissions: AdminPermissions;
  activeActionKey: string;
  onInviteAdmin: (phone: string, permissions: AdminPermissions) => Promise<void>;
  onUpdatePermissions: (phone: string, permissions: AdminPermissions) => Promise<void>;
  onRemoveAdmin: (phone: string) => Promise<void>;
}

const PERMISSION_LABELS: Record<keyof AdminPermissions, string> = {
  canRegister: 'تسجيل مندوبين وتجار',
  canApprove: 'موافقة على الطلبات',
  canDelete: 'حذف الحسابات',
  canSuspend: 'تعليق الحسابات',
  canManageAdmins: 'إدارة المشرفين',
};

function roleBadgeClass(role: string) {
  switch (role) {
    case 'super_admin': return 'role-super-admin';
    case 'admin': return 'role-admin';
    default: return 'role-other';
  }
}

function roleLabel(role: string) {
  switch (role) {
    case 'super_admin': return 'مشرف عام';
    case 'admin': return 'مشرف';
    case 'moderator': return 'مشرف متقدم';
    case 'finance_viewer': return 'مشرف مالي';
    case 'content_manager': return 'محتوى';
    case 'support': return 'دعم';
    default: return role;
  }
}

export default function AdminsView({
  admins,
  myPermissions,
  activeActionKey,
  onInviteAdmin,
  onUpdatePermissions,
  onRemoveAdmin,
}: AdminsViewProps) {
  const [showInviteForm, setShowInviteForm] = useState(false);
  const [invitePhone, setInvitePhone] = useState('');
  const [invitePermissions, setInvitePermissions] = useState<AdminPermissions>({
    canRegister: true,
    canApprove: true,
    canDelete: false,
    canSuspend: false,
    canManageAdmins: false,
  });
  const [isInviteBusy, setIsInviteBusy] = useState(false);
  const [editingPermissions, setEditingPermissions] = useState<string | null>(null);
  const [editPerms, setEditPerms] = useState<AdminPermissions | null>(null);

  function permissionToggle(perms: AdminPermissions, key: keyof AdminPermissions): AdminPermissions {
    return { ...perms, [key]: !perms[key] };
  }

  async function handleInvite() {
    if (!invitePhone.trim()) return;
    setIsInviteBusy(true);
    try {
      await onInviteAdmin(invitePhone.trim(), invitePermissions);
      setShowInviteForm(false);
      setInvitePhone('');
      setInvitePermissions({ canRegister: true, canApprove: true, canDelete: false, canSuspend: false, canManageAdmins: false });
    } catch {
      // error handled upstream
    } finally {
      setIsInviteBusy(false);
    }
  }

  function startEditPermissions(admin: AdminSummary) {
    setEditingPermissions(admin.phone);
    setEditPerms({ ...admin.permissions });
  }

  async function handleSavePermissions(phone: string) {
    if (!editPerms) return;
    try {
      await onUpdatePermissions(phone, editPerms);
    } catch {
      // error handled upstream
    }
    setEditingPermissions(null);
    setEditPerms(null);
  }

  return (
    <section className="main-grid couriers-only">
      <div className="panel wide">
        <div className="panel-header">
          <div>
            <h3>إدارة المشرفين</h3>
            <p>أضف مشرفين جدد وصلاحياتهم. المشرف العام لديه كافة الصلاحيات.</p>
          </div>
          <span className="panel-chip">{admins.length}</span>
        </div>

        <div style={{ padding: '0 20px 20px' }}>
          {myPermissions.canManageAdmins ? (
            <button
              type="button"
              className="button-primary"
              onClick={() => setShowInviteForm(!showInviteForm)}
              style={{ display: 'flex', alignItems: 'center', gap: 8 }}
            >
              <Plus size={16} />
              {showInviteForm ? 'إلغاء' : 'إضافة مشرف جديد'}
            </button>
          ) : null}

          {showInviteForm && (
            <div className="card" style={{ marginTop: 16, padding: 20 }}>
              <h4 style={{ margin: '0 0 16px', fontSize: 15, fontWeight: 700 }}>إضافة مشرف جديد</h4>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div>
                  <label style={{ display: 'block', fontSize: 13, fontWeight: 600, marginBottom: 4, color: '#374151' }}>
                    رقم الهاتف
                  </label>
                  <input
                    type="tel"
                    className="input"
                    placeholder="07xxxxxxxxx"
                    value={invitePhone}
                    onChange={(e) => setInvitePhone(e.target.value)}
                    dir="ltr"
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: 13, fontWeight: 600, marginBottom: 8, color: '#374151' }}>
                    الصلاحيات
                  </label>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                    {(Object.keys(PERMISSION_LABELS) as (keyof AdminPermissions)[]).map((key) => (
                      <label key={key} style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: 13 }}>
                        <input
                          type="checkbox"
                          checked={invitePermissions[key]}
                          onChange={() => setInvitePermissions(permissionToggle(invitePermissions, key))}
                        />
                        {PERMISSION_LABELS[key]}
                      </label>
                    ))}
                  </div>
                </div>
                <button
                  type="button"
                  className="button-primary"
                  onClick={handleInvite}
                  disabled={isInviteBusy || !invitePhone.trim()}
                  style={{ display: 'flex', alignItems: 'center', gap: 8, alignSelf: 'flex-start' }}
                >
                  {isInviteBusy ? <LoaderCircle className="spin" size={16} /> : <Plus size={16} />}
                  {isInviteBusy ? 'جار الإضافة...' : 'إضافة المشرف'}
                </button>
              </div>
            </div>
          )}
        </div>

        <div className="table-responsive-wrap">
          <table className="admin-table">
            <thead>
              <tr>
                <th>رقم الهاتف</th>
                <th>الاسم</th>
                <th>الدور</th>
                <th>الصلاحيات</th>
                <th style={{ textAlign: 'center' }}>إجراءات</th>
              </tr>
            </thead>
            <tbody>
              {admins.map((admin) => {
                const isEditing = editingPermissions === admin.phone;
                const isBusy = activeActionKey === `admin-remove:${admin.phone}` || activeActionKey === `admin-update:${admin.phone}`;
                return (
                  <tr key={admin.phone}>
                    <td style={{ padding: '12px 16px', borderBottom: '1px solid #F3F4F6', fontSize: 13, direction: 'ltr' }}>
                      {admin.phone}
                    </td>
                    <td style={{ padding: '12px 16px', borderBottom: '1px solid #F3F4F6', fontSize: 13 }}>
                      {admin.fullName || '—'}
                    </td>
                    <td style={{ padding: '12px 16px', borderBottom: '1px solid #F3F4F6', fontSize: 13 }}>
                      <span className={`role-badge ${roleBadgeClass(admin.role)}`}>
                        {roleLabel(admin.role)}
                        {admin.isProtected ? (
                          <ShieldCheck size={12} style={{ marginRight: 4 }} />
                        ) : null}
                      </span>
                    </td>
                    <td style={{ padding: '12px 16px', borderBottom: '1px solid #F3F4F6', fontSize: 13 }}>
                      {isEditing ? (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                          {(Object.keys(PERMISSION_LABELS) as (keyof AdminPermissions)[]).map((key) => (
                            <label key={key} style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', fontSize: 12 }}>
                              <input
                                type="checkbox"
                                checked={editPerms?.[key] ?? false}
                                onChange={() => {
                                  if (editPerms) setEditPerms(permissionToggle(editPerms, key));
                                }}
                              />
                              {PERMISSION_LABELS[key]}
                            </label>
                          ))}
                          <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
                            <button
                              type="button"
                              className="button-primary button-sm"
                              onClick={() => handleSavePermissions(admin.phone)}
                              disabled={isBusy}
                            >
                              {isBusy ? <LoaderCircle className="spin" size={14} /> : 'حفظ'}
                            </button>
                            <button
                              type="button"
                              className="button-secondary button-sm"
                              onClick={() => { setEditingPermissions(null); setEditPerms(null); }}
                            >
                              إلغاء
                            </button>
                          </div>
                        </div>
                      ) : (
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4 }}>
                          {(Object.keys(PERMISSION_LABELS) as (keyof AdminPermissions)[]).map((key) => (
                            <span
                              key={key}
                              className={`perm-tag ${admin.permissions[key] ? 'perm-tag-enabled' : 'perm-tag-disabled'}`}
                              style={{
                                fontSize: 11,
                                padding: '2px 8px',
                                borderRadius: 4,
                                background: admin.permissions[key] ? '#D1FAE5' : '#F3F4F6',
                                color: admin.permissions[key] ? '#065F46' : '#6B7280',
                              }}
                            >
                              {admin.permissions[key] ? '✓ ' : '✗ '}
                              {PERMISSION_LABELS[key]}
                            </span>
                          ))}
                        </div>
                      )}
                    </td>
                    <td style={{ padding: '12px 16px', borderBottom: '1px solid #F3F4F6', textAlign: 'center' }}>
                      {admin.isProtected ? (
                        <span style={{ fontSize: 11, color: '#9CA3AF' }}>محمي</span>
                      ) : (
                        <div style={{ display: 'flex', gap: 8, justifyContent: 'center' }}>
                          {myPermissions.canManageAdmins ? (
                            <>
                              <button
                                type="button"
                                className="button-secondary button-sm"
                                onClick={() => isEditing ? null : startEditPermissions(admin)}
                                disabled={isEditing}
                              >
                                صلاحيات
                              </button>
                              <button
                                type="button"
                                className="button-danger button-sm"
                                onClick={() => onRemoveAdmin(admin.phone)}
                                disabled={isBusy}
                              >
                                {isBusy ? <LoaderCircle className="spin" size={14} /> : <Trash2 size={14} />}
                              </button>
                            </>
                          ) : null}
                        </div>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
}
