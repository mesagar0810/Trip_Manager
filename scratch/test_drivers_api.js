const url = 'https://sokmutpbprcdvfwvhlns.supabase.co';
const anonKey = 'sb_publishable_pQm1DMKy3dkxp5UQa2fwDg_iSfk9kMp';

async function run() {
  const username = 'testuser_' + Math.random().toString(36).substring(7);
  const email = `${username}@tripmanager.app`;
  const password = 'password123';

  try {
    console.log(`Signing up ${email}...`);
    const signupRes = await fetch(`${url}/auth/v1/signup`, {
      method: 'POST',
      headers: {
        'apikey': anonKey,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ email, password })
    });
    const signupJson = await signupRes.json();
    const token = signupJson.access_token;
    console.log('Got JWT Token:', token ? 'YES' : 'NO');

    console.log('Querying /rest/v1/drivers...');
    const driversRes = await fetch(`${url}/rest/v1/drivers?select=*,users(user_name)`, {
      headers: {
        'apikey': anonKey,
        'Authorization': `Bearer ${token}`
      }
    });
    console.log('Drivers Status:', driversRes.status);
    const driversJson = await driversRes.json();
    console.log('Drivers:', driversJson);

  } catch (err) {
    console.error('Error:', err);
  }
}

run();
