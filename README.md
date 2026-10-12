# SBAR Nursing Handover App

Cross-platform nursing shift-handover app built around the SBAR framework
(Situation, Background, Assessment, Recommendation).

- `app/`      Flutter client (Android, iOS, Windows/Linux/macOS desktop, tablet, web). One codebase, responsive layouts.
- `backend/`  FastAPI + PostgreSQL (Row Level Security) + WebSocket real-time sync + audit trail.
- `docs/`     Architecture, DB schema notes, UI layouts, sync strategy, compliance checklist.

## Quick start

```bash
# 1. Backend + database
docker compose -f backend/docker-compose.yml up --build
#    API docs: http://localhost:8000/docs   (demo API uses in-memory data; Postgres is started for when you wire it in)

# 2. Flutter app
cd app
flutter create .          # generates android/ ios/ windows/ etc. (keeps lib/ and pubspec.yaml)
flutter pub get
flutter run               # pick device; add --dart-define=API_BASE=http://<host>:8000
```

The app runs in **demo mode** with sample patients if the backend is unreachable.

Demo login (backend): `nurse1` / `nurse123`, `charge1` / `charge123` (change before any real use).

## MVP scope (as per strategy)
1. SBAR form builder + instant sharing between nurses (done here)
2. My Patients dashboard with acuity sorting and critical-value flags (done)
3. Ward monitor (desktop/tablet) with live sync (done)
4. Audit trail, sign-off before handover completes (done)
5. Next: FHIR/EHR integration, audio dictation, QR shift sync (stubs in docs/ARCHITECTURE.md)

> This is a starter scaffold, not a certified medical system. Complete a security review and
> regulatory/compliance assessment (HIPAA / GDPR / NDHM as applicable) before any clinical use.
