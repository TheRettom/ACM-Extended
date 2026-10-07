"""B249: local respiration sound workers must retire at every locality edge."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "functions"

def test_owner_locality_retires_per_patient_breathing_audio_handle():
    owner = (ROOT / "fn_ownerInit.sqf").read_text(encoding="utf-8-sig")
    start = owner.index('["CAManBase", "Local", {')
    end = owner.index('["CAManBase", "init", {', start)
    block = owner[start:end]
    assert 'private _breathPFH = _unit getVariable ["ACME_bs_pfh", -1];' in block
    assert 'if (_breathPFH >= 0) then {[_breathPFH] call CBA_fnc_removePerFrameHandler;};' in block
    assert '_unit setVariable ["ACME_bs_pfh", -1, false];' in block
    assert block.index('CBA_fnc_removePerFrameHandler;};\n    _unit setVariable ["ACME_bs_pfh"') < block.index('if (_isLocal) then {')

def test_sound_worker_can_start_again_after_locality_transition():
    sound = (ROOT / "fn_breathSoundsStart.sqf").read_text(encoding="utf-8-sig")
    assert 'if (isNull _patient || {!alive _patient} || {!local _patient}) exitWith {};' in sound
    assert 'if ((_patient getVariable ["ACME_bs_pfh", -1]) != -1) exitWith {};' in sound
    assert '_patient setVariable ["ACME_bs_pfh", _pfh, false];' in sound
