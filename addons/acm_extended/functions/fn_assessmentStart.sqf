/* B217: native progress includes provider entry. The observed animation still owns completion safety. */
params ["_medic", "_patient", "_bodyPart", "_classname"];
private _class = toLowerANSI _classname;
if !(_class in ["checkairway", "checkbreathing"]) exitWith {false};
if (isNull _medic || {isNull _patient} || {!local _medic} || {!alive _medic}
    || {_medic getVariable ["ACE_isUnconscious", false]}) exitWith {false};
if ((_medic getVariable ["ACME_assessment", []]) isNotEqualTo []) exitWith {false};
if !(_this call ace_medical_treatment_fnc_canTreatCached) exitWith {false};
if (([_classname] call ACME_fnc_assessmentTime) <= 0) exitWith {false};
// Seated care has no on-foot animation. Keep the same clinical duration without posing inside vehicles.
if (!isNull objectParent _medic) exitWith {_this call ACM_core_fnc_treatmentNative};
if !([_medic, _patient, ["isNotInside", "isNotSwimming", "isNotInZeus"]] call ace_common_fnc_canInteractWith) exitWith {false};
if (([_medic, _patient] call ACME_fnc_patientInteractionDistance) > ace_medical_gui_maxDistance) exitWith {false};
private _mode = ["assessmentAirway", "assessmentBreathing"] select (_class == "checkbreathing");
private _epoch = [_medic, _mode, -1, _patient] call ACME_fnc_treatmentPoseStart;
if (_epoch < 0) exitWith {false};
private _token = format ["assessment:%1:%2:%3", clientOwner, netId _medic, _epoch];
private _record = [_epoch, +_this, 0, -1, CBA_missionTime, _token, []];
_medic setVariable ["ACME_assessment", _record, false];
private _pfh = [ACME_fnc_assessmentTick, 0, [_medic, _epoch]] call CBA_fnc_addPerFrameHandler;
_record set [3, _pfh];
// Mark launch before calling native code: synchronous failure/callbacks must see a launched episode.
_record set [10, true];
private _started = _this call ACM_core_fnc_treatmentNative;
if (!_started) then {
    _record set [10, false];
    [_medic, _epoch, true] call ACME_fnc_assessmentStop;
};
_started
