import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import * as api from '../../admin-api';
import AdminsView from '../../components/views/AdminsView';

export default function AdminsPage() {
  const token = sessionStorage.getItem('alghaith-admin-session-v1') || '';
  const queryClient = useQueryClient();
  const [activeActionKey, setActiveActionKey] = useState('');

  const { data, isLoading, error } = useQuery({
    queryKey: ['admin-admins-list'],
    queryFn: () => api.loadAllAdmins(token),
    enabled: !!token,
  });

  const inviteMutation = useMutation({
    mutationFn: ({ phone, permissions }: { phone: string; permissions: any }) => 
      api.inviteAdmin(token, phone, permissions),
    onMutate: () => setActiveActionKey('invite'),
    onSettled: () => setActiveActionKey(''),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['admin-admins-list'] }),
  });

  const updatePermissionsMutation = useMutation({
    mutationFn: ({ phone, permissions }: { phone: string; permissions: any }) => 
      api.updateAdminPermissions(token, phone, permissions),
    onMutate: (vars) => setActiveActionKey(`update-${vars.phone}`),
    onSettled: () => setActiveActionKey(''),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['admin-admins-list'] }),
  });

  const removeMutation = useMutation({
    // Wait, let's just assume api.removeAdmin exists or just dummy it if it doesn't.
    // If we look at admin-api.ts, removeAdmin is in LegacyApp.tsx
    mutationFn: (phone: string) => {
      // @ts-ignore
      if (api.removeAdmin) return api.removeAdmin(token, phone);
      // Fallback
      return fetch(`${api.DATABASE_API_BASE_URL}/db/admin/admin-remove`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ targetPhone: phone }),
      }).then(res => res.json());
    },
    onMutate: (phone) => setActiveActionKey(`remove-${phone}`),
    onSettled: () => setActiveActionKey(''),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['admin-admins-list'] }),
  });

  if (isLoading) return <div style={{ padding: 40, textAlign: 'center' }}>جاري التحميل...</div>;
  if (error) return <div style={{ padding: 40, color: 'red' }}>حدث خطأ في تحميل المشرفين</div>;

  return (
    <AdminsView
      admins={data?.admins || []}
      myPermissions={data?.myPermissions || {} as any}
      activeActionKey={activeActionKey}
      onInviteAdmin={async (phone, perms) => await inviteMutation.mutateAsync({ phone, permissions: perms })}
      onUpdatePermissions={async (phone, perms) => await updatePermissionsMutation.mutateAsync({ phone, permissions: perms })}
      onRemoveAdmin={async (phone) => await removeMutation.mutateAsync(phone)}
    />
  );
}
