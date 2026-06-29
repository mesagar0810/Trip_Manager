const { Client } = require('pg');

const regions = [
  'ap-south-1',
  'us-east-1',
  'us-east-2',
  'us-west-1',
  'us-west-2',
  'eu-west-1',
  'eu-west-2',
  'eu-west-3',
  'eu-central-1',
  'ap-southeast-1',
  'ap-southeast-2',
  'ap-northeast-1',
  'ap-northeast-2',
  'sa-east-1',
  'ca-central-1'
];

async function checkRegion(region) {
  const host = `aws-0-${region}.pooler.supabase.com`;
  const client = new Client({
    host: host,
    port: 6543,
    database: 'postgres',
    user: 'postgres.sokmutpbprcdvfwvhlns',
    password: 'S@g@r08102304',
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 3000
  });

  try {
    await client.connect();
    console.log(`[SUCCESS] Connected successfully to region: ${region}`);
    return true;
  } catch (err) {
    const msg = err.message;
    if (msg.includes('tenant/user') && msg.includes('not found')) {
      // Wrong region pooler
      return false;
    } else {
      // Correct region, but maybe another error like auth fail, timeout, etc.
      console.log(`[PROBABLE MATCH] Region ${region} returned error: ${msg}`);
      return true;
    }
  } finally {
    try {
      await client.end();
    } catch (e) {}
  }
}

async function run() {
  console.log('Testing regions...');
  for (const region of regions) {
    const found = await checkRegion(region);
    if (found) {
      console.log(`Found region: ${region}`);
      break;
    }
  }
}

run();
