const {
  assertSupabaseAdmin,
  getPhoneVariants,
  resolvePhoneKey,
  nowIso,
} = require('./common');
const { getAppUser } = require('./users');

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

async function readAdminRoleRow(phoneKey) {
  const supabase = assertSupabaseAdmin();
  const { data, error } = await supabase
    .from('admin_roles')
    .select('phone, role, updated_at')
    .eq('phone', phoneKey)
    .maybeSingle();
  if (error && !/does not exist/i.test(error.message || '')) {
    throw new Error(error.message);
  }
  return data || null;
}

async function getAdminRole(phone) {
  const phoneKey = await resolvePhoneKey(phone);
  const row = await readAdminRoleRow(phoneKey);
  if (row?.role) return String(row.role).trim();

  const user = await getAppUser(phoneKey);
  if (String(user?.role ?? '').trim() === 'admin') {
    return 'admin';
  }
  return null;
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
  if (
    normalizedRole &&
    !ADMIN_ROLES[Object.keys(ADMIN_ROLES).find((k) => ADMIN_ROLES[k] === normalizedRole)]
  ) {
    throw new Error(`Invalid role: ${normalizedRole}`);
  }

  const targetKey = await resolvePhoneKey(targetPhone);
  const supabase = assertSupabaseAdmin();

  if (normalizedRole) {
    await supabase.from('admin_roles').upsert({
      phone: targetKey,
      role: normalizedRole,
      updated_at: nowIso(),
    });
  } else {
    await supabase.from('admin_roles').delete().eq('phone', targetKey);
  }

  const user = await getAppUser(targetKey);
  if (user && normalizedRole && String(user.role || '').trim() !== 'admin') {
    await supabase
      .from('app_users')
      .update({ role: 'admin', updated_at: nowIso() })
      .eq('phone', targetKey);
  }

  return { success: true, phone: targetKey, role: normalizedRole || null };
}

async function listAdminAccounts(adminPhone) {
  const adminRole = await getAdminRole(adminPhone);
  if (!adminRole || roleLevel(adminRole) < roleLevel('admin')) {
    throw new Error('Admin access required.');
  }

  const supabase = assertSupabaseAdmin();
  const [users, adminRows] = await Promise.all([
    supabase.from('app_users').select().order('updated_at', { ascending: false }),
    supabase.from('admin_roles').select(),
  ]);

  if (users.error) throw new Error(users.error.message);
  if (adminRows.error && !/does not exist/i.test(adminRows.error.message || '')) {
    throw new Error(adminRows.error.message);
  }

  const roleByPhone = {};
  for (const row of adminRows.data || []) {
    roleByPhone[row.phone] = row;
  }

  const admins = [];
  for (const user of users.data || []) {
    const phone = String(user.phone || '').trim();
    if (!phone) continue;
    const roleRow = roleByPhone[phone];
    const role = String(roleRow?.role || '').trim();
    if (role || String(user.role || '').trim() === 'admin') {
      admins.push({
        phone,
        fullName: String(user.full_name || '').trim(),
        role: role || 'admin',
        adminAccess: true,
        updatedAt: roleRow?.updated_at || user.updated_at || null,
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
