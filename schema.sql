CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE wards (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT NOT NULL);

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('nurse','charge','admin')),
  ward_id UUID REFERENCES wards(id)
);

CREATE TABLE patients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ward_id UUID NOT NULL REFERENCES wards(id),
  name TEXT NOT NULL, age INT NOT NULL, room TEXT NOT NULL, bed TEXT NOT NULL,
  diagnosis TEXT, physician TEXT,
  code_status TEXT NOT NULL DEFAULT 'FULL' CHECK (code_status IN ('FULL','DNR')),
  chief_complaint TEXT, fall_risk BOOLEAN DEFAULT FALSE, isolation TEXT,
  allergies TEXT[] DEFAULT '{}', pmh TEXT, surgical_history TEXT, admitted_on DATE,
  acuity INT DEFAULT 3 CHECK (acuity BETWEEN 1 AND 5)
);

CREATE TABLE patient_assignments (
  user_id UUID REFERENCES users(id),
  patient_id UUID REFERENCES patients(id),
  PRIMARY KEY (user_id, patient_id)
);

CREATE TABLE vitals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES patients(id),
  taken_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  hr INT, sbp INT, dbp INT, rr INT, spo2 INT, temp_c NUMERIC(4,1), pain INT
);

CREATE TABLE labs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID NOT NULL REFERENCES patients(id),
  taken_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  name TEXT NOT NULL, value NUMERIC NOT NULL, unit TEXT, critical BOOLEAN DEFAULT FALSE
);

CREATE TABLE handovers (
  id UUID PRIMARY KEY,
  patient_id UUID NOT NULL REFERENCES patients(id),
  from_user UUID NOT NULL REFERENCES users(id),
  to_user UUID REFERENCES users(id),
  situation JSONB NOT NULL, background JSONB NOT NULL,
  assessment JSONB NOT NULL, recommendation JSONB NOT NULL,
  version INT NOT NULL DEFAULT 1,
  signed_off_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE audit_log (
  id BIGSERIAL PRIMARY KEY, at TIMESTAMPTZ NOT NULL DEFAULT now(),
  user_id UUID, action TEXT NOT NULL, entity TEXT, entity_id TEXT, detail JSONB
);

-- Row Level Security: nurses see assigned patients; charge/admin see the whole ward.
-- App sets per transaction: SET LOCAL app.user_id = '<uuid>'; SET LOCAL app.role = '<role>';
-- Connect as a non-superuser role so RLS is enforced.
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE handovers ENABLE ROW LEVEL SECURITY;
CREATE POLICY patients_access ON patients USING (
  EXISTS (SELECT 1 FROM patient_assignments a WHERE a.patient_id = patients.id
          AND a.user_id = current_setting('app.user_id', true)::uuid)
  OR current_setting('app.role', true) IN ('charge','admin'));
CREATE POLICY handovers_access ON handovers USING (
  EXISTS (SELECT 1 FROM patient_assignments a WHERE a.patient_id = handovers.patient_id
          AND a.user_id = current_setting('app.user_id', true)::uuid)
  OR current_setting('app.role', true) IN ('charge','admin'));

CREATE INDEX ON vitals (patient_id, taken_at DESC);
CREATE INDEX ON labs (patient_id, taken_at DESC);
CREATE INDEX ON handovers (patient_id, created_at DESC);
