const { Client } = require('pg');

const client = new Client({
  host: 'db.sokmutpbprcdvfwvhlns.supabase.co',
  port: 6543, // Transaction pooler port
  database: 'postgres',
  user: 'postgres',
  password: 'S@g@r08102304',
  ssl: {
    rejectUnauthorized: false
  }
});

async function migrate() {
  try {
    console.log('Connecting to database...');
    await client.connect();
    console.log('Connected. Running migration query...');
    await client.query('ALTER TABLE trip_info ADD COLUMN IF NOT EXISTS co_passengers TEXT;');
    console.log('Migration successful: co_passengers column added.');
  } catch (err) {
    console.error('Migration failed:', err);
  } finally {
    await client.end();
  }
}

migrate();
