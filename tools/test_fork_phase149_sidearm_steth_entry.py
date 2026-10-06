#!/usr/bin/env python3
"""RC3 regression: sidearms must fully holster before provider theatre and prone auscultation must roll, never teleport."""
from build_contract import assert_current_build as _assert_current_build
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ACME = ROOT / "addons" / "acm_extended" / "functions"

def read(path):
    return path.read_text(encoding="utf-8", errors="replace")

def code_only(text):
    return "\n".join(line.split("//", 1)[0] for line in text.splitlines())

prep = read(ACME / "fn_medicAnimationPrep.sqf")
pose = read(ACME / "fn_treatmentPoseStart.sqf")
scope = read(ACME / "fn_beginStethoscopeAction.sqf")
treatment = read(ROOT / "addons" / "core" / "overrides" / "fnc_treatment.sqf")
use = read(ROOT / "addons" / "breathing" / "functions" / "fnc_useStethoscope.sqf")
entry = read(ACME / "fn_stethoscopeEntryFlip.sqf")
entry_tick = read(ACME / "fn_stethoscopeEntryFlipTick.sqf")
roll = read(ACME / "fn_chestSealRoll.sqf")
cfg = read(ROOT / "addons" / "acm_extended" / "config.cpp")
startup = read(ACME / "fn_initForkStartupRuntime.sqf")

# Never clear a live weapon with selectWeapon "" in the generic or stethoscope preflight.
assert 'selectWeapon ""' not in code_only(prep)
assert 'selectWeapon ""' not in code_only(scope)
assert "ace_weaponselect_fnc_putWeaponAway" in prep
assert "handgunWeapon _medic" in prep
assert "_elapsed < 3.2" in prep

# Generic treatments serialize weapon-away before any crouch transition.
assert treatment.index("// Phase 1:") < treatment.index("// Phase 2:")
assert '(currentWeapon _m == "")' in treatment
assert '((_anim find "wnon") >= 0)' in treatment
assert '((_anim find "snon") >= 0)' in treatment

# Roll/stethoscope poses cannot bypass the sidearm holster with the old immediate path.
assert "_rollImmediate" not in pose
assert '(currentWeapon _medic == "") && {_visuallyEmpty}' in pose
assert "_now - _actionStarted >= 3.0" in pose

# UseStethoscope has no second callbackStart holster request.
use_block = cfg.split("class UseStethoscope {", 1)[1].split("\n    };", 1)[0]
assert 'callbackStart = "";' in use_block

# Re-entering on a prone patient routes through the authored roll before the activity log/dialog.
assert "ACME_fnc_stethoscopeEntryFlip" in use
assert use.index("ACME_fnc_stethoscopeEntryFlip") < use.index("STR_ACM_breathing_Stethoscope_ActionLog")
assert '[_medic, "stethoscopeEntry", _patient] call ACME_fnc_rollProviderStart' in entry
assert '[_patient, "front", false, _provider, _preserveHead] call ACME_fnc_chestSealRoll' in entry_tick
assert '[_provider, _patient, _bodyPart, true] call ACM_breathing_fnc_useStethoscope' in entry_tick
assert "class stethoscopeEntryFlip {};" in cfg
assert "class stethoscopeEntryFlipTick {};" in cfg

# The preserve-head flag survives owner dispatch for remote patients.
assert '[_patient, _target, _force, _provider, _preserveSuspendedHeadElevation]' in roll

_assert_current_build()
assert 'ACME_debugRevision = "rc3";' in startup

print("PASS rc3: serialized sidearm holster + animated prone auscultation entry")
