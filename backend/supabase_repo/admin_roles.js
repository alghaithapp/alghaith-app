const {
  assertSupabaseAdmin,
  getPhoneVariants,
  resolvePhoneKey,
  nowIso,
  hasColumn,
} = require('./common');
const { getAppUser, getUserState, saveUserState } = require('./users');

const ADMIN_ROLES = Object.freeze({
  SUPER_ADMIN: 'super_admin',
  ADMIN: 'admin',
  MODERATOR: 'moderator',
  FINANCE_VIEWER: 'finance_viewer',
  CONTENT_MANAGER: 'content_manager',
  SUPPORT: 'support',
});

const ROLE_HIERARCHY = Object.freeze({
  super_admin: 100,
  admin: 80,
  moderator: 60,
  finance_viewer: 40,
  content_manager: 40,
  support: 20,
});

function roleLevel(role) {
  return ROLE_HIERARCHY[String(role || '').trim()] || 0;
}

function hasMinRole(userRole, requiredRole) {
  return roleLevel(userRole) >= roleLevel(requiredRole);
}

async function getAdminRole(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const state = await getUserState(phoneKey);
  if (!state || typeof state !== 'object') return null;
  return String(state.adminRole || state.admin_role || '').trim() || null;
}

async function setAdminRole(adminPhone, targetPhone, newRole) {
  const adminRole = await getAdminRole(adminPhone);
  if (!adminRole || roleLevel(adminRole) < roleLevel('admin')) {
    throw new Error('Admin access required to manage roles.');
  }
  if (roleLevel(adminRole) < roleLevel('super_admin') && newRole === 'super_admin') {
    throw new Error('Only super admins can assign super admin role.');
  }

  const normalizedRole = String(newRole || '').trim();
  if (normalizedRole && !ADMIN_ROLES[Object.keys(ADMIN_ROLES).find(k => ADMIN_ROLES[k] === normalizedRole)]) {
    throw new Error(`Invalid role: ${normalizedRole}`);
  }

  const targetKey = await resolvePhoneKey(targetPhone);
  const existingState = (await getUserState(targetKey)) || {};
  await saveUserState(targetKey, {
    ...existingState,
    adminRole: normalizedRole || null,
    admin_role: normalizedRole || null,
    adminAccess: normalizedRole ? true : existingState.adminAccess,
  });

  const user = await getAppUser(targetKey);
  if (user && normalizedRole && String(user.role || '').trim() !== 'admin') {
    const supabase = assertSupabaseAdmin();
    await supabase.from('app_users').update({ role: 'admin', updated_at: nowIso() }).eq('phone', targetKey);
  }

  return { success: true, phone: targetKey, role: normalizedRole || null };
}

async function listAdminAccounts(adminPhone) {
  const adminRole = await getAdminRole(adminPhone);
  if (!adminRole || roleLevel(adminRole) < roleLevel('admin')) {
    throw new Error('Admin access required.');
  }

  const supabase = assertSupabaseAdmin();
  const [users, states] = await Promise.all([
    supabase.from('app_users').select().order('updated_at', { ascending: false }),
    supabase.from('app_state').select(),
  ]);

  if (users.error) throw new Error(users.error.message);
  if (states.error) throw new Error(states.error.message);

  const stateByPhone = {};
  for (const row of states.data || []) {
    stateByPhone[row.phone] = row.state || {};
  }

  const admins = [];
  for (const user of users.data || []) {
    const phone = String(user.phone || '').trim();
    if (!phone) continue;
    const state = stateByPhone[phone] || {};
    const role = String(state.adminRole || state.admin_role || '').trim();
    if (role || state.adminAccess === true || String(user.role || '').trim() === 'admin') {
      admins.push({
        phone,
        fullName: String(user.full_name || '').trim(),
        role: role || (state.adminAccess === true ? 'admin' : 'unknown'),
        adminAccess: state.adminAccess === true,
        updatedAt: user.updated_at || null,
      });
    }
  }

  return admins.sort((a, b) => {
    const levelDiff = roleLevel(b.role) - roleLevel(a.role);
    if (levelDiff !== 0) return levelDiff;
    return String(a.fullName || '').localeCompare(String(b.fullName || ''), 'ar');
  });
}

module.exports = {
  ADMIN_ROLES,
  ROLE_HIERARCHY,
  roleLevel,
  hasMinRole,
  getAdminRole,
  setAdminRole,
  listAdminAccounts,
};
