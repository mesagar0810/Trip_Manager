const url = 'https://sokmutpbprcdvfwvhlns.supabase.co/rest/v1';
const anonKey = 'sb_publishable_pQm1DMKy3dkxp5UQa2fwDg_iSfk9kMp';

async function run() {
  try {
    console.log('Fetching vehicles...');
    const res = await fetch(`${url}/vehicles?select=*`, {
      headers: {
        'apikey': anonKey,
        'Authorization': `Bearer ${anonKey}`
      }
    });
    console.log('Status:', res.status);
    const json = await res.json();
    console.log('Response:', json);
  } catch (err) {
    console.error('Error:', err);
  }
}

run();
