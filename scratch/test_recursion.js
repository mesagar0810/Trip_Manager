const url = 'https://sokmutpbprcdvfwvhlns.supabase.co';
const anonKey = 'sb_publishable_pQm1DMKy3dkxp5UQa2fwDg_iSfk9kMp';

async function run() {
  const username = 'testuser_' + Math.random().toString(36).substring(7);
  const email = `${username}@tripmanager.app`;
  const password = 'password123';

  try {
    // 1. Sign Up
    console.log(`Signing up ${email}...`);
    const signupRes = await fetch(`${url}/auth/v1/signup`, {
      method: 'POST',
      headers: {
        'apikey': anonKey,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ email, password })
    });
    console.log('Signup Status:', signupRes.status);
    const signupJson = await signupRes.json();
    if (signupRes.status >= 400) {
      console.error('Signup Failed:', signupJson);
      return;
    }

    const token = signupJson.access_token;
    console.log('Got JWT Token:', token ? 'YES' : 'NO');

    // 2. Query vehicles table
    console.log('Querying /rest/v1/vehicles...');
    const vehiclesRes = await fetch(`${url}/rest/v1/vehicles?select=*`, {
      headers: {
        'apikey': anonKey,
        'Authorization': `Bearer ${token}`
      }
    });
    console.log('Vehicles Status:', vehiclesRes.status);
    const vehiclesJson = await vehiclesRes.json();
    console.log('Vehicles:', vehiclesJson);

    // 3. Query users table (this should trigger users_select policy)
    console.log('Querying /rest/v1/users...');
    const usersRes = await fetch(`${url}/rest/v1/users?select=*`, {
      headers: {
        'apikey': anonKey,
        'Authorization': `Bearer ${token}`
      }
    });
    console.log('Users Status:', usersRes.status);
    const usersJson = await usersRes.json();
    console.log('Users:', usersJson);

  } catch (err) {
    console.error('Error:', err);
  }
}

run();
