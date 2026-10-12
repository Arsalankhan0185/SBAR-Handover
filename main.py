"""SBAR handover API (demo build).

Uses an in-memory store so it runs with zero setup. For production, replace the
`DB` dict with Postgres access using ../schema.sql (RLS expects SET LOCAL app.user_id / app.role).
"""
import os, time, uuid, asyncio
from datetime import datetime, timezone, timedelta
from typing import Any, Optional

import jwt
from fastapi import Depends, FastAPI, Header, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

SECRET = os.getenv("JWT_SECRET", "dev-only-secret")
app = FastAPI(title="SBAR Handover API")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# ---- demo data -------------------------------------------------------------
USERS = {
    "nurse1": {"id": "u1", "password": "nurse123", "name": "Nurse Amina", "role": "nurse", "ward": "w1"},
    "charge1": {"id": "u2", "password": "charge123", "name": "Charge Nurse Raza", "role": "charge", "ward": "w1"},
}
ASSIGN = {"u1": {"p1", "p2", "p3"}}
PATIENTS: dict[str, dict] = {
    "p1": dict(id="p1", ward="w1", name="Ali Khan", age=67, room="101", bed="A", diagnosis="Pneumonia",
               physician="Dr. Sana", code_status="FULL", chief_complaint="Shortness of breath",
               fall_risk=True, isolation="Contact", allergies=["Penicillin"], acuity=2,
               vitals=dict(hr=102, sbp=118, dbp=72, rr=24, spo2=91, temp_c=38.4, pain=3),
               labs=[dict(name="K+", value=3.9, unit="mmol/L")]),
    "p2": dict(id="p2", ward="w1", name="Maria Gomez", age=54, room="102", bed="B", diagnosis="Post-op cholecystectomy",
               physician="Dr. Imran", code_status="FULL", chief_complaint="Incision pain",
               fall_risk=False, isolation=None, allergies=[], acuity=4,
               vitals=dict(hr=78, sbp=124, dbp=80, rr=16, spo2=98, temp_c=36.9, pain=4),
               labs=[dict(name="Hb", value=8.1, unit="g/dL")]),
    "p3": dict(id="p3", ward="w1", name="John Smith", age=81, room="103", bed="A", diagnosis="CHF exacerbation",
               physician="Dr. Sana", code_status="DNR", chief_complaint="Leg swelling",
               fall_risk=True, isolation=None, allergies=["Sulfa"], acuity=1,
               vitals=dict(hr=96, sbp=98, dbp=60, rr=20, spo2=93, temp_c=36.8, pain=1),
               labs=[dict(name="K+", value=6.2, unit="mmol/L")]),
}
HANDOVERS: dict[str, dict] = {}
AUDIT: list[dict] = []

# ---- critical value rules ----------------------------------------------------
LAB_LIMITS = {"K+": (3.0, 5.5), "Hb": (7.0, 20.0)}

def critical_flags(p: dict) -> list[str]:
    f, v = [], p.get("vitals", {})
    if v.get("spo2", 100) < 92: f.append(f"SpO2 {v['spo2']}%")
    if v.get("hr", 80) > 120 or v.get("hr", 80) < 40: f.append(f"HR {v['hr']}")
    if v.get("sbp", 120) < 90: f.append(f"SBP {v['sbp']}")
    if v.get("rr", 16) > 28: f.append(f"RR {v['rr']}")
    if v.get("temp_c", 37) >= 39: f.append(f"Temp {v['temp_c']}")
    for lab in p.get("labs", []):
        lo, hi = LAB_LIMITS.get(lab["name"], (-1e9, 1e9))
        if not lo <= lab["value"] <= hi: f.append(f"{lab['name']} {lab['value']}")
    return f

def view(p: dict) -> dict:
    return {**p, "critical_flags": critical_flags(p)}

# ---- auth -----------------------------------------------------------------
class Login(BaseModel):
    username: str
    password: str

def current_user(authorization: str = Header(...)) -> dict:
    try:
        data = jwt.decode(authorization.removeprefix("Bearer "), SECRET, algorithms=["HS256"])
    except jwt.PyJWTError:
        raise HTTPException(401, "Invalid token")
    return data

def audit(user: dict, action: str, entity: str, entity_id: str):
    AUDIT.append(dict(at=datetime.now(timezone.utc).isoformat(), user=user["sub"], action=action,
                      entity=entity, entity_id=entity_id))

@app.post("/login")
def login(body: Login):
    u = USERS.get(body.username)
    if not u or u["password"] != body.password:
        raise HTTPException(401, "Bad credentials")
    token = jwt.encode({"sub": u["id"], "name": u["name"], "role": u["role"], "ward": u["ward"],
                        "exp": datetime.now(timezone.utc) + timedelta(hours=8)}, SECRET)
    return {"token": token, "name": u["name"], "role": u["role"]}

def visible(user: dict) -> list[dict]:
    if user["role"] in ("charge", "admin"):
        return [p for p in PATIENTS.values() if p["ward"] == user["ward"]]
    return [PATIENTS[i] for i in ASSIGN.get(user["sub"], set()) if i in PATIENTS]

@app.get("/patients")
def patients(user=Depends(current_user)):
    out = sorted((view(p) for p in visible(user)), key=lambda p: p["acuity"])
    return out

@app.get("/ward/patients")
def ward_patients(user=Depends(current_user)):
    if user["role"] not in ("charge", "admin"):
        raise HTTPException(403, "Charge nurse only")
    return sorted((view(p) for p in visible(user)), key=lambda p: p["room"])

# ---- handovers ----------------------------------------------------------------
class Handover(BaseModel):
    id: str
    patient_id: str
    situation: dict[str, Any]
    background: dict[str, Any]
    assessment: dict[str, Any]
    recommendation: dict[str, Any]
    to_user: Optional[str] = None
    version: int = 1

@app.post("/handovers")
async def save_handover(h: Handover, user=Depends(current_user)):
    if h.patient_id not in {p["id"] for p in visible(user)}:
        raise HTTPException(403, "Not assigned to patient")
    existing = HANDOVERS.get(h.id)
    if existing and existing["version"] != h.version:
        raise HTTPException(409, "Version conflict")
    rec = {**h.model_dump(), "from_user": user["sub"], "version": (existing["version"] + 1) if existing else 1,
           "signed_off_at": existing.get("signed_off_at") if existing else None}
    HANDOVERS[h.id] = rec
    audit(user, "update" if existing else "create", "handover", h.id)
    await hub.broadcast(user["ward"], {"type": "handover", "id": h.id, "patient_id": h.patient_id, "version": rec["version"]})
    return rec

@app.get("/handovers/{patient_id}")
def latest_handover(patient_id: str, user=Depends(current_user)):
    if patient_id not in {p["id"] for p in visible(user)}:
        raise HTTPException(403, "Not assigned to patient")
    items = [h for h in HANDOVERS.values() if h["patient_id"] == patient_id]
    audit(user, "read", "handover", patient_id)
    return items[-1] if items else None

@app.post("/handovers/{hid}/signoff")
async def signoff(hid: str, user=Depends(current_user)):
    h = HANDOVERS.get(hid)
    if not h: raise HTTPException(404)
    h["signed_off_at"] = datetime.now(timezone.utc).isoformat()
    h["to_user"] = user["sub"]
    audit(user, "signoff", "handover", hid)
    await hub.broadcast(user["ward"], {"type": "signoff", "id": hid, "patient_id": h["patient_id"]})
    return h

@app.get("/audit")
def get_audit(user=Depends(current_user)):
    if user["role"] != "admin" and user["role"] != "charge":
        raise HTTPException(403)
    return AUDIT[-200:]

# ---- real-time hub -----------------------------------------------------------------
class Hub:
    def __init__(self): self.conns: dict[str, set[WebSocket]] = {}
    async def broadcast(self, ward: str, msg: dict):
        for ws in list(self.conns.get(ward, [])):
            try: await ws.send_json(msg)
            except Exception: self.conns[ward].discard(ws)

hub = Hub()

@app.websocket("/ws")
async def ws(socket: WebSocket, token: str):
    try:
        user = jwt.decode(token, SECRET, algorithms=["HS256"])
    except jwt.PyJWTError:
        await socket.close(code=4401); return
    await socket.accept()
    hub.conns.setdefault(user["ward"], set()).add(socket)
    try:
        while True: await socket.receive_text()
    except WebSocketDisconnect:
        hub.conns[user["ward"]].discard(socket)
