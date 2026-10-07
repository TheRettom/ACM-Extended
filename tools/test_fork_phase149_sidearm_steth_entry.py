#!/usr/bin/env python3
"""Current sidearm/stethoscope entry regression."""
from build_contract import assert_current_build
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; ACME=ROOT/"addons"/"acm_extended"/"functions"
def read(p): return p.read_text(encoding="utf-8",errors="replace")
def code_only(t): return "\n".join(line.split("//",1)[0] for line in t.splitlines())
def test_weapon_preflight_prefers_ace_holster_and_bounds_fallback():
    prep=read(ACME/"fn_medicAnimationPrep.sqf"); scope=read(ACME/"fn_beginStethoscopeAction.sqf")
    assert "ace_weaponselect_fnc_putWeaponAway" in prep
    assert "handgunWeapon _medic" in prep and "_elapsed < 3.2" in prep
    assert 'if (_weapon != "") then {_medic selectWeapon "";};' in code_only(prep)
    assert prep.index("ace_weaponselect_fnc_putWeaponAway") < prep.index('if (_weapon != "") then {_medic selectWeapon "";};')
    assert 'selectWeapon ""' not in code_only(scope)
def test_generic_treatments_serialize_weapon_away_before_crouch():
    treatment=read(ROOT/"addons"/"core"/"overrides"/"fnc_treatment.sqf")
    assert treatment.index("// Phase 1:") < treatment.index("// Phase 2:")
    for t in ('(currentWeapon _m == "")','((_anim find "wnon") >= 0)','((_anim find "snon") >= 0)'): assert t in treatment
def test_stethoscope_prone_entry_uses_authored_roll_and_preserves_head():
    pose=read(ACME/"fn_treatmentPoseStart.sqf"); use=read(ROOT/"addons"/"breathing"/"functions"/"fnc_useStethoscope.sqf")
    entry=read(ACME/"fn_stethoscopeEntryFlip.sqf"); tick=read(ACME/"fn_stethoscopeEntryFlipTick.sqf"); roll=read(ACME/"fn_chestSealRoll.sqf")
    cfg=read(ROOT/"addons"/"acm_extended"/"config.cpp")
    assert "_rollImmediate" not in pose and '(currentWeapon _medic == "") && {_visuallyEmpty}' in pose and "_now - _actionStarted >= 3.0" in pose
    block=cfg.split("class UseStethoscope {",1)[1].split("\n    };",1)[0]; assert 'callbackStart = "";' in block
    assert "ACME_fnc_stethoscopeEntryFlip" in use and use.index("ACME_fnc_stethoscopeEntryFlip") < use.index("STR_ACM_breathing_Stethoscope_ActionLog")
    assert '[_medic, "stethoscopeEntry", _patient] call ACME_fnc_rollProviderStart' in entry
    assert '[_patient, "front", false, _provider, _preserveHead] call ACME_fnc_chestSealRoll' in tick
    assert '[_provider, _patient, _bodyPart, true] call ACM_breathing_fnc_useStethoscope' in tick
    assert '[_patient, _target, _force, _provider, _preserveSuspendedHeadElevation]' in roll
    assert_current_build()
