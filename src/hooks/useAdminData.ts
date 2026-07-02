import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import * as api from '../admin-api';

const API_KEYS = {
  accounts: 'admin-accounts',
  reports: 'admin-reports',
  merchants: 'admin-merchants',
};

// ── Accounts Hook ──
export function useAccounts(token: string) {
  return useQuery({
    queryKey: [API_KEYS.accounts],
    queryFn: () => api.loadAdminAccounts(token),
    enabled: !!token,
    staleTime: 1000 * 60 * 5, // Cache for 5 mins
  });
}

// ── Reports Hook ──
export function useReports(token: string) {
  return useQuery({
    queryKey: [API_KEYS.reports],
    queryFn: () => api.loadAdminReports(token),
    enabled: !!token,
    refetchInterval: 1000 * 60, // Refresh every minute
  });
}

// ── Merchants Hook ──
export function useMerchants(token: string) {
  return useQuery({
    queryKey: ['admin-merchants'],
    queryFn: () => api.loadMerchants(token),
    enabled: !!token,
  });
}

// ── Couriers Hook ──
export function useCouriers(token: string) {
  return useQuery({
    queryKey: ['admin-couriers'],
    queryFn: () => api.loadCouriers(token),
    enabled: !!token,
  });
}

// ── Mutations ──
export function useAdminMutations(token: string) {
  const queryClient = useQueryClient();

  const suspendAccount = useMutation({
    mutationFn: ({ phone, isSuspended }: { phone: string; isSuspended: boolean }) =>
      api.suspendAdminAccount(token, phone, isSuspended),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [API_KEYS.accounts] });
    },
  });

  const deleteAccount = useMutation({
    mutationFn: (phone: string) => api.deleteAdminAccount(token, phone),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [API_KEYS.accounts] });
    },
  });

  const updateRole = useMutation({
    mutationFn: ({ phone, role }: { phone: string; role: string }) =>
      api.updateAdminAccountRole(token, phone, role),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [API_KEYS.accounts] });
    },
  });

  return {
    suspendAccount,
    deleteAccount,
    updateRole,
  };
}
