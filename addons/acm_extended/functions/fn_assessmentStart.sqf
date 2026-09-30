/* Assessment-only animation preflight. Native ACE still owns clinical progress/results/cancellation.
 * Start its timer after the requested work state enters, so holstering cannot consume the two-second check.
 */
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
private _keys = [];
if (hasInterface && {[_medic] call ace_common_fnc_isPlayer}) then {
    ace_medical_gui_pendingReopen = false;
    if (dialog) then {closeDialog 0;};
    [true, _medic, _patient, _token] call ACME_fnc_chestAccessPreparing;
    // Local input must not resolve a netId: single-player object identities need not be network-addressable.
    missionNamespace setVariable ["ACME_assessmentInputProvider", _medic];
    private _cancel = compile format [
        "private _m=missionNamespace getVariable ['ACME_assessmentInputProvider',objNull]; if (!isNull _m && {local _m}) then {[_m,%1,true] call ACME_fnc_assessmentStop;}; false",
        _epoch
    ];
    {_keys pushBack ([_x, [false,false,false], _cancel, "keydown", "", false, 0] call CBA_fnc_addKeyHandler);} forEach [0x01, 0xF0];
};
_record set [6, _keys];
private _pfh = [ACME_fnc_assessmentTick, 0, [_medic, _epoch]] call CBA_fnc_addPerFrameHandler;
_record set [3, _pfh];
true
