require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.VITE_SUPABASE_URL || process.env.SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

async function check() {
  const { data: states, error: stateErr } = await supabase
    .from('app_state')
    .select('phone, state')
    .like('phone', '%7855505865%');
    
  console.log("States matching 7855505865:", states.map(s => s.phone));
}

check();
