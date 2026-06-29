-- ============================================================
-- TRIP MANAGER - SUPABASE POSTGRESQL SCHEMA
-- Run this entire file in your Supabase SQL editor
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- USERS
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  user_name   TEXT NOT NULL UNIQUE,
  password    TEXT,
  role        TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DRIVERS  (one row per user with role='user')
-- ============================================================
CREATE TABLE IF NOT EXISTS drivers (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  license_number   TEXT,
  license_expiry   DATE,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE
);

-- ============================================================
-- VEHICLES
-- ============================================================
CREATE TABLE IF NOT EXISTS vehicles (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_number   TEXT NOT NULL UNIQUE,
  model            TEXT NOT NULL,
  last_service_on  DATE,
  technical_notes  TEXT,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE
);

-- ============================================================
-- TRIP INFO
-- ============================================================
CREATE TABLE IF NOT EXISTS trip_info (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  requested_by     UUID NOT NULL REFERENCES users(id),
  from_location    TEXT NOT NULL,
  to_location      TEXT NOT NULL,
  trip_date        DATE NOT NULL,
  tentative_time   TEXT NOT NULL,
  description      TEXT,
  co_travelers     TEXT,
  status           TEXT NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','approved','rejected','ongoing','completed')),
  approved_by      UUID REFERENCES users(id),
  rejection_reason TEXT,
  requested_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at      TIMESTAMPTZ
);

-- ============================================================
-- TRIP CONDITIONS  (weather + road, one per trip)
-- ============================================================
CREATE TABLE IF NOT EXISTS trip_conditions (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_request_id  UUID NOT NULL UNIQUE REFERENCES trip_info(id) ON DELETE CASCADE,
  weather_condition TEXT NOT NULL DEFAULT 'clear'
                      CHECK (weather_condition IN ('clear','rainy','foggy','stormy')),
  temperature      INTEGER NOT NULL DEFAULT 25,
  visibility       TEXT NOT NULL DEFAULT 'good'
                     CHECK (visibility IN ('good','moderate','poor')),
  road_condition   TEXT NOT NULL DEFAULT 'good'
                     CHECK (road_condition IN ('good','underConstruction','damaged')),
  road_hazards     TEXT,
  is_safe_to_travel BOOLEAN NOT NULL DEFAULT TRUE,
  fetched_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TRIP ASSIGNMENTS  (driver self-assigns vehicle after approval)
-- ============================================================
CREATE TABLE IF NOT EXISTS trip_assignments (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id     UUID NOT NULL UNIQUE REFERENCES trip_info(id) ON DELETE CASCADE,
  driver_id   UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  vehicle_id  UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DRIVER DECLARATIONS  (pre-journey checklist)
-- ============================================================
CREATE TABLE IF NOT EXISTS driver_declarations (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_assignment_id  UUID NOT NULL UNIQUE REFERENCES trip_assignments(id) ON DELETE CASCADE,
  has_valid_licence   BOOLEAN NOT NULL DEFAULT FALSE,
  is_physically_fit   BOOLEAN NOT NULL DEFAULT FALSE,
  vehicle_roadworthy  BOOLEAN NOT NULL DEFAULT FALSE,
  is_substance_free   BOOLEAN NOT NULL DEFAULT FALSE,
  docs_available      BOOLEAN NOT NULL DEFAULT FALSE,
  submitted           BOOLEAN NOT NULL DEFAULT FALSE,
  submitted_at        TIMESTAMPTZ
);

-- ============================================================
-- TRIP LOGS  (live tracking)
-- ============================================================
CREATE TABLE IF NOT EXISTS trip_logs (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id           UUID NOT NULL REFERENCES trip_info(id) ON DELETE CASCADE,
  journey_started_at TIMESTAMPTZ,
  journey_ended_at  TIMESTAMPTZ,
  current_status    TEXT NOT NULL DEFAULT 'notStarted'
                      CHECK (current_status IN ('notStarted','ongoing','completed')),
  current_lat       DOUBLE PRECISION,
  current_lng       DOUBLE PRECISION
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE users              ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers            ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_info          ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_conditions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_assignments   ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_declarations ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_logs          ENABLE ROW LEVEL SECURITY;

-- Users can read their own profile; admins can read all
CREATE POLICY "users_select" ON users FOR SELECT
  USING (auth.uid() = id OR EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'admin'));

CREATE POLICY "users_insert" ON users FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "users_update_own" ON users FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "users_admin_update" ON users FOR UPDATE
  USING (EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'admin'));

CREATE POLICY "users_admin_delete" ON users FOR DELETE
  USING (EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'admin'));

-- Drivers: own record + admin
CREATE POLICY "drivers_select" ON drivers FOR SELECT
  USING (user_id = auth.uid() OR EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'admin'));

CREATE POLICY "drivers_insert" ON drivers FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "drivers_admin_insert" ON drivers FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'admin'));

CREATE POLICY "drivers_admin_update" ON drivers FOR UPDATE
  USING (EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'admin'));

CREATE POLICY "drivers_admin_delete" ON drivers FOR DELETE
  USING (EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'admin'));

-- Vehicles: all authenticated users can read (to pick a vehicle)
CREATE POLICY "vehicles_select" ON vehicles FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "vehicles_admin_all" ON vehicles FOR ALL
  USING (EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'admin'));

-- Trips: own trips or admin sees all
CREATE POLICY "trip_info_select_own" ON trip_info FOR SELECT
  USING (requested_by = auth.uid() OR EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'admin'));

CREATE POLICY "trip_info_insert" ON trip_info FOR INSERT WITH CHECK (requested_by = auth.uid());

CREATE POLICY "trip_info_update_admin" ON trip_info FOR UPDATE
  USING (EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'admin') OR requested_by = auth.uid());

-- Trip conditions: readable by trip requester or admin
CREATE POLICY "trip_conditions_select" ON trip_conditions FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM trip_info t WHERE t.id = trip_request_id
    AND (t.requested_by = auth.uid() OR EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'admin'))
  ));

CREATE POLICY "trip_conditions_insert" ON trip_conditions FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "trip_conditions_update" ON trip_conditions FOR UPDATE USING (auth.uid() IS NOT NULL);

-- Assignments: driver who owns it or admin
CREATE POLICY "assignments_select" ON trip_assignments FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM drivers d WHERE d.id = driver_id AND d.user_id = auth.uid()
  ) OR EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'admin'));

CREATE POLICY "assignments_insert" ON trip_assignments FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM drivers d WHERE d.id = driver_id AND d.user_id = auth.uid()));

-- Declarations: same as assignment
CREATE POLICY "declarations_select" ON driver_declarations FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM trip_assignments ta JOIN drivers d ON d.id = ta.driver_id
    WHERE ta.id = trip_assignment_id AND d.user_id = auth.uid()
  ) OR EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'admin'));

CREATE POLICY "declarations_insert" ON driver_declarations FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "declarations_update" ON driver_declarations FOR UPDATE USING (auth.uid() IS NOT NULL);

-- Trip logs: driver or admin
CREATE POLICY "trip_logs_select" ON trip_logs FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM trip_info t WHERE t.id = trip_id
    AND (t.requested_by = auth.uid() OR EXISTS (SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role = 'admin'))
  ));

CREATE POLICY "trip_logs_insert" ON trip_logs FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "trip_logs_update" ON trip_logs FOR UPDATE USING (auth.uid() IS NOT NULL);

-- ============================================================
-- REALTIME  (for live tracking)
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE trip_logs;

-- ============================================================
-- SEED: Sample vehicles (optional — remove if not needed)
-- ============================================================
INSERT INTO vehicles (vehicle_number, model, last_service_on, is_active) VALUES
  ('RJ-14-CA-1234', 'Tata Sumo Gold', '2024-11-15', TRUE),
  ('RJ-14-CB-5678', 'Mahindra Bolero', '2025-01-10', TRUE),
  ('RJ-14-CC-9012', 'Force Trax', '2025-03-22', TRUE)
ON CONFLICT (vehicle_number) DO NOTHING;
