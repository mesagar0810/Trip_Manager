const url = 'https://sokmutpbprcdvfwvhlns.supabase.co';
const anonKey = 'sb_publishable_pQm1DMKy3dkxp5UQa2fwDg_iSfk9kMp';

async function run() {
  const email = 'Admin@tripmanager.app';
  const password = 'Admin@12345';

  try {
    console.log(`Signing in as ${email}...`);
    const signinRes = await fetch(`${url}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: {
        'apikey': anonKey,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ email, password })
    });
    
    const signinJson = await signinRes.json();
    if (signinRes.status >= 400) {
      console.error('Sign In Failed:', signinJson);
      return;
    }

    const token = signinJson.access_token;
    console.log('Signed in. Got JWT Token:', token ? 'YES' : 'NO');

    console.log('Querying /rest/v1/drivers?select=*,users(user_name) as Admin...');
    const driversRes = await fetch(`${url}/rest/v1/drivers?select=*,users(user_name)`, {
      headers: {
        'apikey': anonKey,
        'Authorization': `Bearer ${token}`
      }
    });
    console.log('Drivers Status:', driversRes.status);
    const driversJson = await driversRes.json();
    console.log('Drivers Response:', driversJson);

    console.log('Querying /rest/v1/vehicles as Admin...');
    const vehiclesRes = await fetch(`${url}/rest/v1/vehicles?select=*`, {
      headers: {
        'apikey': anonKey,
        'Authorization': `Bearer ${token}`
      }
    });
    console.log('Vehicles Status:', vehiclesRes.status);
    const vehiclesJson = await vehiclesRes.json();
    console.log('Vehicles Response:', vehiclesJson);

  } catch (err) {
    console.error('Error:', err);
  }
}

run();
