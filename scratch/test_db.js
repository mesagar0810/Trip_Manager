const { Client } = require('pg');

const client = new Client({
  host: 'aws-0-ap-south-1.pooler.supabase.com',
  port: 6543,
  database: 'postgres',
  user: 'postgres.sokmutpbprcdvfwvhlns',
  password: 'S@g@r08102304',
  ssl: {
    rejectUnauthorized: false
  }
});

async function run() {
  try {
    await client.connect();
    console.log('Connected to DB!');
    
    console.log('--- Users ---');
    const users = await client.query('SELECT * FROM users;');
    console.log(users.rows);

    console.log('--- Drivers ---');
    const drivers = await client.query('SELECT * FROM drivers;');
    console.log(drivers.rows);

    console.log('--- Vehicles ---');
    const vehicles = await client.query('SELECT * FROM vehicles;');
    console.log(vehicles.rows);

    console.log('--- RLS Policies ---');
    const policies = await client.query(`
      SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check 
      FROM pg_policies 
      WHERE schemaname = 'public';
    `);
    console.log(policies.rows);

  } catch (err) {
    console.error('Failed:', err);
  } finally {
    await client.end();
  }
}

run();
