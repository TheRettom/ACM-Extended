"""B245 healthy-idle networking/backpressure contracts.

These checks target the report that desync can begin without an injury. They require
healthy owned units to produce no periodic ACME physiology publications and keep
full-owner discovery off the hot 4 Hz paths.
"""
from pathlib import Path
import re

from test_menu_death_lifecycle import adapt, execute

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
    assert '([0.005,0] select (abs (_reserve - 0.30) <= 0.000001)),0] call ACME_fnc_setVarNetApprox;' in s


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


def test_idle_physiology_uses_one_shared_slow_discovery():
    discovery = src("idlePhysDiscovery")
    runtime = src("expansionRegisterRuntime")
    assert discovery.count('ACME_clinical_ownedUnits') == 1
    assert 'ACME_preox_activePatients = _preox;' in discovery
    assert 'ACME_aspiration_activePatients = _aspiration;' in discovery
    assert 'ACME_shock_activePatients = _shock;' in discovery
    assert 'ACME_rhythmThreshold_activePatients = _rhythmThreshold;' in discovery
    assert '[{ call ACME_fnc_idlePhysDiscovery; }, 2, []] call CBA_fnc_addPerFrameHandler;' in runtime

    for name, registry in {
        "preoxygenationTick": "ACME_preox_activePatients",
        "aspirationTick": "ACME_aspiration_activePatients",
        "shockPhenotypeTick": "ACME_shock_activePatients",
        "rhythmThresholdTick": "ACME_rhythmThreshold_activePatients",
    }.items():
        s = src(name)
        assert registry in s
        assert 'ACME_clinical_ownedUnits' not in s
        assert '} forEach _patients;' in s
        assert f'{registry} = _patients select' in s


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




def test_locality_transfer_retires_idle_physiology_registries():
    s = src("ownerInit")
    owner_register = src("ownerRegister")
    for registry in ("ACME_preox_activePatients", "ACME_aspiration_activePatients", "ACME_shock_activePatients", "ACME_rhythmThreshold_activePatients"):
        assert s.count(f'"{registry}"') >= 2
    assert '[[_patient]] call ACME_fnc_idlePhysDiscovery;' in owner_register


def test_manual_carrier_recovery_does_not_dispatch_every_healthy_unit():
    s = src("registerManualPlateCarrierRuntime")
    start = s.index('if (_now >= (missionNamespace getVariable ["ACME_manualPlateCarrierRecoveryAt", -1])) then {')
    end = s.index('private _kept = [];', start)
    audit = s[start:end]
    assert 'forEach (allUnits select {' in audit
    assert 'local _x && {alive _x}' in audit
    assert 'getVariable ["ACME_manualPlateCarrierState", ""]) != ""' in audit
    assert 'forEach allUnits;' not in audit


def _healthy_vm(name):
    s = src(name)
    # Only adapt object/locality commands that occur before each function's healthy
    # early exit. Any unsupported command beyond that guard would fail the VM,
    # making accidental fall-through visible rather than silently mocked.
    s = re.sub(r'\bisNull _u\b', '(_u isEqualTo objNull)', s)
    s = re.sub(r'\blocal _u\b', 'true', s)
    s = re.sub(r'\balive _u\b', 'true', s)
    s = re.sub(r'alive \(_u getVariable \["ACM_breathing_BVM_Medic",\s*objNull\]\)', 'false', s)
    return adapt(s)


def test_actual_healthy_idle_models_issue_zero_publication_requests():
    definitions = "ACME_fnc_idlePhysDiscovery={" + _healthy_vm("idlePhysDiscovery") + "};" + "".join(
        f"ACME_fnc_{name}={{" + _healthy_vm(name) + "}};"
        for name in ("preoxygenationTick", "aspirationTick", "shockPhenotypeTick", "rhythmThresholdTick")
    )
    execute(definitions + r'''
        private _exactRequests=0;
        private _approxRequests=0;
        ACME_fnc_setVarNet={_exactRequests=_exactRequests+1;};
        ACME_fnc_setVarNetApprox={_approxRequests=_approxRequests+1;};
        ACME_clinical_ownedUnits=[_patient];

        // Explicit ordinary healthy defaults. No injury/treatment state exists.
        _patient setVariable ["ACM_breathing_RespirationRate",16];
        _patient setVariable ["ace_medical_spo2",97];
        _patient setVariable ["ACM_circulation_Blood_Volume",6];

        call ACME_fnc_idlePhysDiscovery;
        [ACME_preox_activePatients isEqualTo [] && {ACME_aspiration_activePatients isEqualTo []}
            && {ACME_shock_activePatients isEqualTo []}
            && {ACME_rhythmThreshold_activePatients isEqualTo []},"healthy discovery enrolled idle physiology"] call _check;
        call ACME_fnc_preoxygenationTick;
        call ACME_fnc_aspirationTick;
        call ACME_fnc_shockPhenotypeTick;
        call ACME_fnc_rhythmThresholdTick;

        [_exactRequests==0,"healthy idle path issued exact network publication"] call _check;
        [_approxRequests==0,"healthy idle path issued approximate network publication"] call _check;
        [isNil {_patient getVariable "ACME_preox_lastTick"},"healthy preoxygenation path did not exit before scheduler state"] call _check;
        [isNil {_patient getVariable "ACME_aspiration_tickAt"},"healthy aspiration path did not exit before scheduler state"] call _check;
    ''')
