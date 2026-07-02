import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import type { AdminPermissions } from '../../admin-types';
import { DEFAULT_ADMIN_PERMISSIONS } from '../../admin-types';
import { loadMyAdminRole } from '../../admin-api';

const SESSION_KEY = 'alghaith-admin-session-v1';

interface AuthState {
  token: string | null;
  role: string | null;
  permissions: AdminPermissions | null;
  isLoading: boolean;
  setToken: (token: string | null) => void;
  refreshRole: () => Promise<void>;
  hasPermission: (key: keyof AdminPermissions) => boolean;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [token, setTokenState] = useState<string | null>(() => sessionStorage.getItem(SESSION_KEY));
  const [role, setRole] = useState<string | null>(null);
  const [permissions, setPermissions] = useState<AdminPermissions | null>(null);
  const [isLoading, setIsLoading] = useState(Boolean(token));

  const refreshRole = useCallback(async () => {
    if (!token) {
      setRole(null);
      setPermissions(null);
      setIsLoading(false);
      return;
    }
    setIsLoading(true);
    try {
      const data = await loadMyAdminRole(token);
      setRole(data.role || null);
      setPermissions(data.permissions || null);
    } catch {
      sessionStorage.removeItem(SESSION_KEY);
      setTokenState(null);
      setRole(null);
      setPermissions(null);
    } finally {
      setIsLoading(false);
    }
  }, [token]);

  useEffect(() => {
    refreshRole();
  }, [refreshRole]);

  const setToken = useCallback((next: string | null) => {
    if (next) sessionStorage.setItem(SESSION_KEY, next);
    else sessionStorage.removeItem(SESSION_KEY);
    setTokenState(next);
  }, []);

  const hasPermission = useCallback(
    (key: keyof AdminPermissions) => {
      if (role === 'super_admin') return true;
      if (permissions?.[key]) return true;
      if ((role === 'admin' || role === 'moderator') && !permissions) {
        return Boolean(DEFAULT_ADMIN_PERMISSIONS[key]);
      }
      return false;
    },
    [permissions, role],
  );

  const value = useMemo(
    () => ({ token, role, permissions, isLoading, setToken, refreshRole, hasPermission }),
    [token, role, permissions, isLoading, setToken, refreshRole, hasPermission],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth outside AuthProvider');
  return ctx;
}

export function useAdminToken() {
  const { token } = useAuth();
  if (!token) throw new Error('Not authenticated');
  return token;
}
