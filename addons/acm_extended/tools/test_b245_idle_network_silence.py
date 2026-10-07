"""B245 healthy-idle networking/backpressure contracts.

These checks target the report that desync can begin without an injury. They require
healthy owned units to produce no periodic ACME physiology publications and keep
full-owner discovery off the hot 4 Hz paths.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def src(name):
    return (ROOT / "functions" / f"fn_{name}.sqf").read_text(encoding="utf-8-sig")


def test_preoxygenation_healthy_room_air_is_silent_and_neutral():
    s = src("preoxygenationTick")
    guard = 'if (abs (_reserveProbe - 0.30) <= 0.001 && {!_supportProbe} && {!_physProbe}) then {continue};'
    assert guard in s
    assert s.index(guard) < s.index('call ACME_fnc_setVarNetApprox')
    assert 'ACM_breathing_RespirationRate", 16' in s
    assert 'private _supplemental = _fio2Frac > 0.22;' in s
    assert 'if (_effectiveVent && {_supplemental} && {_spo2 >= 92}) then {' in s
    assert 'if (_reserve > 0.30) then {_reserve = (_reserve - _baselineStep) max 0.30;};' in s
    assert '[_u,"ACME_preox_reserve",_reserve,0.005,0] call ACME_fnc_setVarNetApprox;' in s


def test_aspiration_neutral_state_has_no_heartbeat():
    s = src("aspirationTick")
    guard = 'if (!_freshEvent && {_load <= 0.0005} && {_edema <= 0.0005} && {!_hadEffect}) then {continue};'
    assert guard in s
    assert s.index(guard) < s.index('call ACME_fnc_setVarNetApprox')
    for field in (
        "ACME_aspiration_load", "ACME_aspiration_edema", "ACME_aspiration_injury",
        "ACME_aspiration_SpO2Penalty", "ACME_aspiration_RRDrive", "ACME_aspiration_shunt",
    ):
        rows = [line for line in s.splitlines() if f'"{field}"' in line and "setVarNetApprox" in line]
        assert rows, field
        assert all(",0] call ACME_fnc_setVarNetApprox" in line for line in rows), (field, rows)


def test_shock_neutral_state_has_no_heartbeat():
    s = src("shockPhenotypeTick")
    guard = 'if (!_forcedActive && {!_tension} && {_htx < 0.75} && {!_circShock} && {_blood >= 5.1} && {!_hadShock}) then {continue};'
    assert guard in s
    assert s.index(guard) < s.index('call ACME_fnc_setVarNetApprox')
    for field in ("ACME_shock_resistDelta", "ACME_shock_hrAdj", "ACME_shock_severity"):
        row = next(line for line in s.splitlines() if f'"{field}"' in line and "setVarNetApprox" in line)
        assert ",0] call ACME_fnc_setVarNetApprox" in row


def test_circulation_full_owner_discovery_is_not_four_hz():
    s = src("circHandle")
    assert 'ACME_circDiscoveryNextAt' in s
    assert 'CBA_missionTime + 1' in s
    owned = 'forEach (missionNamespace getVariable ["ACME_clinical_ownedUnits", []]);'
    assert owned in s
    discovery = s.index('private _discoveryNext')
    loop = s.index(owned, discovery)
    close = s.index('};\n\n_patients = _patients arrayIntersect _patients;', discovery)
    assert discovery < loop < close


def test_saline_and_infusion_hot_workers_do_not_scan_every_healthy_owner():
    saline = src("salineAcidosisTrack")
    fluid = src("fluidCommit")
    infusion = src("handleInfusions")
    assert 'ACME_clinical_ownedUnits' not in saline
    assert 'ACME_circ_activePatients' in saline
    assert 'ACME_circ_activePatients pushBackUnique _patient' in fluid
    assert 'ACME_infusionDiscoveryNextAt' in infusion
    assert 'CBA_missionTime + 2' in infusion


def test_b201_idle_broadcaster_shapes_cannot_return():
    # This deliberately scans only the three historically problematic full-owner
    # models. Stable replicated state may be refreshed for active patients, but a
    # neutral full-owner loop may not pair a heartbeat maxAge with setVarNetApprox.
    for name in ("preoxygenationTick", "aspirationTick", "shockPhenotypeTick"):
        s = src(name)
        assert "setVarNetApprox" in s
        # All approximate rows in these three paths use change/owner publication only.
        rows = [line for line in s.splitlines() if "setVarNetApprox" in line and not line.lstrip().startswith("//")]
        assert rows
        assert all(",0] call ACME_fnc_setVarNetApprox" in line for line in rows), (name, rows)
