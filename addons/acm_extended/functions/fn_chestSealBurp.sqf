/* Patient-owner burp transaction. Cooldown precedes physiology, animation and logging. */
params ["_medic","_patient",["_bodyPart","body"], ["_epoch", -1], ["_request", []]];
if (isNull _patient || {isNull _medic}) exitWith {};
if (_epoch < 0) then {
    _epoch = [_patient] call ACME_fnc_clinicalEpoch;
    private _sequence = (missionNamespace getVariable ["ACME_pleuralDrainSequence", 0]) + 1;
    missionNamespace setVariable ["ACME_pleuralDrainSequence", _sequence];
    _request = [clientOwner, _sequence, serverTime];
};
if (!local _patient) exitWith {["ACME_ownerCommand",[_patient,"burp",[_medic,_patient,_bodyPart,_epoch,_request]],_patient] call CBA_fnc_targetEvent;};
if (!alive _medic || {_medic getVariable ["ACE_isUnconscious",false]}
    || {(_medic distance _patient) > 5}) exitWith {};
if !([_patient,true] call ACME_fnc_chestSealBurpReady) exitWith {};
if (_epoch != ([_patient] call ACME_fnc_clinicalEpoch)) exitWith {};
private _hasSeal = _patient getVariable ["ACM_breathing_ChestSeal_State", false];
_hasSeal = _hasSeal || {((_patient getVariable ["ACME_CS_holeData", []]) findIf {_x param [4, false]}) >= 0};
if (!_hasSeal) exitWith {};
private _drained = [_patient, _medic, "seal", _epoch, _request] call ACME_fnc_thoraDrainBloodLocal;
if (_drained < 0) exitWith {};
// A corpse can still be handled, but no physiological worker should restart.
if (alive _patient) then {[_patient,"burp"] call ACME_fnc_ptxTreat; [_patient] call ACM_breathing_fnc_updateLungState;};
_patient setVariable ["ACME_CS_lastBurp",CBA_missionTime,true];
[_patient, "burp", "Burped chest seal", [], _medic, 0] call ACME_fnc_chestSealLogOnce;
// Provider remains in the persistent workspace hold. medic3 is seal-placement-only.
