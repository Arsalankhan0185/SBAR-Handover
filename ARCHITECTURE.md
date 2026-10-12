# Architecture

## 1. SBAR data capture and digital value-add
| SBAR | Inputs | Digital value |
|---|---|---|
| S | Name, age, room/bed, diagnosis, physician, code status, chief complaint | Banner with colour-coded badges (code status, fall risk, isolation) |
| B | PMH, surgical history, allergies, admission date, baseline vitals, isolation | EHR auto-populate via FHIR (Patient, AllergyIntolerance, Condition) |
| A | System review (Neuro/Cardiac/Resp/GI-GU/Skin), vitals, pain, lines/drips/drains, lab trends | Trend graphs, checklist to prevent missed systems, critical-value flags |
| R | Pending orders, discharge plan, watch-outs, med times | Priority checklist; mandatory sign-off before completing |

## 2. System diagram
```
Flutter app (mobile/tablet/desktop)  <--HTTPS REST + WSS-->  FastAPI  <-->  PostgreSQL (RLS)
        |  offline cache (drift/sqlite, planned)                |  \--> audit_log (append-only)
        |                                                       \--> FHIR adapter (planned) -> EHR
```

## 3. Sync strategy
- Writes: REST `POST /handovers` (idempotent via client-generated UUID).
- Reads/live: WebSocket `/ws?token=...`. Server broadcasts `{type, ward_id, entity, id, version}` events after commit.
- Conflict handling: optimistic concurrency with integer `version` column; stale write returns 409 and the client shows a merge prompt.
- Offline: queue writes locally, replay on reconnect (planned: `drift` outbox table).
- Ward monitor subscribes to its ward only; server filters events by the user's ward.

## 4. UI layouts
- Mobile (<600 px): bottom nav (My Patients, Ward, Alerts); patient cards -> SBAR stepper.
- Tablet/Desktop (>=900 px): left rail nav, patient grid with detail pane, ward monitor with bed map and alerts.

## 5. Security and compliance checklist
- TLS everywhere; encrypt DB volumes and backups; field-level encryption for free-text notes (planned).
- JWT with short expiry + refresh; roles (nurse, charge, admin); assignment-based access enforced in DB via RLS.
- Append-only audit log for create/update/sign-off events.
- Minimum necessary data on devices; secure token storage; remote wipe via MDM.
- HIPAA / GDPR / NDHM: BAA, data residency, consent, retention, breach procedure. Needs formal review.

## 6. Roadmap
1. Interviews with bedside nurses, charge nurses, managers.
2. MVP (this repo).
3. FHIR R4 integration (Patient, Observation, AllergyIntolerance, MedicationRequest).
4. Medical speech-to-text dictation.
5. QR shift sync: QR on bed board encodes patient_id; scanning loads the active handover.
6. Hospital and ward requirements: inventory, beds, staff roster, Emergency SOS / Code Blue.
