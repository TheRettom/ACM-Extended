#!/usr/bin/env python3
"""DEV 1.3.0 PHYS1-PC1: persistent manual plate-carrier toggle contract."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8", errors="replace")


def test_dev_actions_are_mutually_exclusive_body_equipment_toggles():
    cfg = read("addons/acm_extended/config.cpp")
    remove = cfg.split("class ACME_ManualRemovePlateCarrier:", 1)[1].split("class ACME_ManualReplacePlateCarrier:", 1)[0]
    replace = cfg.split("class ACME_ManualReplacePlateCarrier:", 1)[1].split("// Keep the existing assessment action", 1)[0]

    assert 'displayName = "Remove Plate Carrier";' in remove
    assert 'category = "advanced";' in remove
    assert 'allowedSelections[] = {"Body"};' in remove
    assert 'allowSelfTreatment = 1;' in remove
    assert '[_medic, _patient, false] call ACME_fnc_manualPlateCarrierCanToggle' in remove
    assert 'animationMedic = "";' in remove
    assert 'animationMedicProne = "";' in remove
    assert 'ACM_rollToBack = 0;' in remove

    assert 'displayName = "Replace Plate Carrier";' in replace
    assert '[_medic, _patient, true] call ACME_fnc_manualPlateCarrierCanToggle' in replace


def test_toggle_functions_are_registered_and_owner_routed():
    cfg = read("addons/acm_extended/config.cpp")
    dispatch = read("addons/acm_extended/functions/fn_ownerDispatch.sqf")
    startup = read("addons/acm_extended/functions/fn_initForkStartupRuntime.sqf")

    for name in (
        "manualPlateCarrierCanToggle",
        "manualPlateCarrierCommit",
        "registerManualPlateCarrierRuntime",
    ):
        assert f"class {name} {{}};" in cfg

    assert 'case "manualPlateCarrier": {_args call ACME_fnc_manualPlateCarrierCommit;};' in dispatch
    assert "call ACME_fnc_registerManualPlateCarrierRuntime;" in startup


def test_manual_custody_is_separate_from_temporary_chest_access_custody():
    can = read("addons/acm_extended/functions/fn_manualPlateCarrierCanToggle.sqf")
    commit = read("addons/acm_extended/functions/fn_manualPlateCarrierCommit.sqf")
    restore = read("addons/acm_extended/functions/fn_chestAccessVestRestore.sqf")

    assert 'ACME_manualPlateCarrierLoadout' in can
    assert 'ACME_manualPlateCarrierLoadout' in commit
    assert 'ACME_manualPlateCarrierRemoved' in commit

    # Manual custody must never reuse the automatic chest-access variables or it would be auto-restored on close.
    manual_write_block = commit.split('if (_restore) then {', 1)[1]
    assert 'setVariable ["ACME_chestAccess_vestLoadout"' not in manual_write_block
    assert 'setVariable ["ACME_CS_vestLoadout"' not in manual_write_block
    assert "ACME_manualPlateCarrierLoadout" not in restore


def test_manual_toggle_refuses_to_race_live_chest_procedure_ownership():
    s = read("addons/acm_extended/functions/fn_manualPlateCarrierCanToggle.sqf")
    for token in (
        "ACME_chestAccess_vestLoadout",
        "ACME_CS_vestLoadout",
        "ACME_chestAccess_vestBusy",
        "ACME_CS_vestBusy",
        "ACME_chestAccess_leases",
        "ACME_CS_ProcedureActive",
        "ACME_Thora_ChestAccessActive",
        "ACME_fnc_chestAccessManeuverActive",
    ):
        assert token in s


def test_remove_stores_exact_vest_loadout_and_replace_restores_only_vest_slot():
    s = read("addons/acm_extended/functions/fn_manualPlateCarrierCommit.sqf")
    assert 'private _entry = (getUnitLoadout _patient) param [4, [], [[]]];' in s
    assert "removeVest _patient;" in s
    assert '_patient setVariable ["ACME_manualPlateCarrierLoadout", +_entry, true];' in s
    assert 'private _loadout = getUnitLoadout _patient;' in s
    assert '_loadout set [4, +_saved];' in s
    assert '_patient setUnitLoadout [_loadout, false];' in s
    assert '_patient setVariable ["ACME_manualPlateCarrierLoadout", [], true];' in s
    assert '_patient setVariable ["ACME_acmSpawnerPlateCarrierDone", true, true];' in s


def test_automatic_chest_access_skips_carrier_choreography_when_manual_toggle_left_it_off():
    acquire = read("addons/acm_extended/functions/fn_chestAccessVestAcquire.sqf")

    # The no-vest fast path exits before the automatic _commitRemoval / lift sequence is declared.
    no_vest = acquire.index('if (_vestClass == "" || {(count _vestEntry) != 2}) exitWith {')
    commit = acquire.index("private _commitRemoval = {")
    lift = acquire.index("private _liftTime =")
    assert no_vest < commit < lift

    # Manual state itself is not consulted by automatic custody: vest absence is enough to skip removal animation.
    before_commit = acquire[:commit]
    assert "ACME_manualPlateCarrierLoadout" not in before_commit


def test_treatment_bridge_executes_toggle_without_progress_or_animation_preflight():
    treatment = read("addons/core/overrides/fnc_treatment.sqf")
    block = treatment.split('if (_classname in ["ACME_ManualRemovePlateCarrier", "ACME_ManualReplacePlateCarrier"]) exitWith {', 1)[1]
    block = block.split("// Opening a shared workspace", 1)[0]

    assert "ace_medical_treatment_fnc_canTreatCached" in block
    assert '[_patient, "manualPlateCarrier"' in block
    assert "ACM_core_fnc_treatmentNative" not in block
    assert "medicAnimationPrep" not in block
    assert "treatmentPoseStart" not in block


def test_ack_refreshes_existing_medical_menu_in_place():
    s = read("addons/acm_extended/functions/fn_registerManualPlateCarrierRuntime.sqf")
    assert '"ACME_manualPlateCarrierAck"' in s
    assert "ace_medical_gui_fnc_updateActions" in s
    assert "CBA_fnc_execNextFrame" in s


def test_dev_debug_identity_marks_experiment():
    startup = read("addons/acm_extended/functions/fn_initForkStartupRuntime.sqf")
    cfg = read("addons/acm_extended/config.cpp")
    assert 'version = "1.3.0";' in cfg
    assert 'ACME_buildBatch = "DEV-130-PHYS1-PC1";' in startup
    assert 'ACME_debugRevision = "PHYS1-PC1";' in startup


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
    print("DEV manual plate carrier toggle regression: PASS")
