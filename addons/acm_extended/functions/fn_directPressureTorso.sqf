// Torso direct pressure is persistent hemorrhage control, not an ACM exclusive continuous action.
// The provider keeps access to the medical menu and ordinary treatments. Movement and real maneuvers yield the
// hold instead of locking input, and the shared tick reapplies pressure once the provider can resume it.
params ["_medic", "_patient", "_bodyPart"];
if (isNull _medic || {isNull _patient} || {!local _medic}) exitWith {};

// A direct call can bypass fn_directPressureStart, so retain the maneuver guard. Any clinical marker cleanup is
// owner-routed and cannot erase another provider's replacement hold.
if (missionNamespace getVariable ["ACM_core_ContinuousAction_Active", false]) exitWith {
    [_patient, "directPressureMarker", [_medic, _bodyPart, false, _medic getVariable ["ACME_DP_ClaimToken", ""], _medic getVariable ["ACME_DP_ClaimEpoch", -1]]] call ACME_fnc_ownerDispatch;
    ["Another active maneuver is already in progress.", 2, _medic] call ace_common_fnc_displayTextStructured;
};

_medic setVariable ["ACME_DP_Active", true, true];
_medic setVariable ["ACME_DP_Patient", _patient, true];
_medic setVariable ["ACME_DP_Part", _bodyPart, true];
_medic setVariable ["ACME_DP_Mode", "torso"];
_medic setVariable ["ACME_DP_Start", CBA_missionTime];
_medic setVariable ["ACME_DP_NextClot", CBA_missionTime + 15];
_medic setVariable ["ACME_DP_Paused", false];
_medic setVariable ["ACME_DP_InPose", false];
_medic setVariable ["ACME_DP_IdleStart", CBA_missionTime];
_medic setVariable ["ACME_DP_LastPos", getPosASL _medic];
_medic setVariable ["ACME_DP_LastPoseAssert", 0];
_medic setVariable ["ACME_DP_ClinicalYield", false];
_medic setVariable ["ACME_DP_ClinicalYieldStart", 0];
_medic setVariable ["ACME_DP_OwnsContinuous", false];

// Enter the connected two-handed pressure hold directly. No scripted weapon draw/holster cycle is introduced.
if (isNull objectParent _medic) then {
    private _prone = stance _medic == "PRONE";
    private _pose = [_medic, "ACME_DirectPressureHold", _prone] call ACME_fnc_providerAnimation;
    _prone = _prone || {_pose == "ACM_ProneContinuous"};
    _medic setVariable ["ACME_DP_Pose", _pose];
    _medic setVariable ["ACME_DP_PoseProne", _prone];
    _medic setUnitPos (["MIDDLE", "DOWN"] select _prone);
    _medic setVariable ["ACME_DP_PoseToken", (_medic getVariable ["ACME_DP_PoseToken", 0]) + 1];
    _medic setVariable ["ACME_DP_PoseGraceUntil", CBA_missionTime + 0.15];
    [_medic, _pose, 1.1, 1, true] call ACME_fnc_doAnimHeld;
    _medic setVariable ["ACME_DP_InPose", true];
    _medic setVariable ["ACME_DP_LastPoseAssert", CBA_missionTime];
};

// Keep the menu available and show RMB cancellation. MMB remains accepted for existing users.
["", "Stop Direct Pressure", ""] call ace_interaction_fnc_showMouseHint;

// Direct Pressure has no keyboard cancellation binding. RMB/MMB use the display guard; the explicit
// Stop Direct Pressure menu action is the deliberate UI fallback. Escape/H remain available to the player.
_medic setVariable ["ACME_DP_KeyIDs", []];

[_patient, "activity", "%1 started Direct pressure on %2", "%1 started Direct pressure on %2", [[_medic, false, true] call ace_common_fnc_getName, ([_bodyPart, "abbr"] call ACME_fnc_bodyPartName)]] call ACME_fnc_medLog;

// Publish the clinical pressure marker only after provider-local episode state is fully initialized.
[_patient, "directPressureMarker", [_medic, _bodyPart, true, _medic getVariable ["ACME_DP_ClaimToken", ""], _medic getVariable ["ACME_DP_ClaimEpoch", -1]]] call ACME_fnc_ownerDispatch;

private _episode = [_medic getVariable ["ACME_DP_ClaimToken", ""], _medic getVariable ["ACME_DP_ClaimEpoch", -1], clientOwner,
    +(_medic getVariable ["ACME_DP_KeyIDs", []]), _medic getVariable ["ACME_DP_Draw3D", -1],
    _medic getVariable ["ACME_providerLocalityEpoch", 0]];
private _pfh = [ACME_fnc_directPressureTick, 0, [_medic, _patient, _bodyPart, "torso", _episode]] call CBA_fnc_addPerFrameHandler;
_medic setVariable ["ACME_DP_PFH", _pfh];
