params ["_medic", "_patient"];
if (isNull _medic || {!local _medic} || {!alive _medic}
    || {_medic getVariable ["ACE_isUnconscious", false]}
    || {([_medic, _patient] call ACME_fnc_patientInteractionDistance) > ace_medical_gui_maxDistance}) exitWith {false};
private _cargo = [_patient] call ACME_fnc_carrierInventoryGet;
if (isNull _cargo) exitWith {false};
// Closing the medical display releases its own provider pose. Only the supplies container is openable.
ace_medical_gui_pendingReopen = false;
if (!isNull (uiNamespace getVariable ["ace_medical_gui_menuDisplay", displayNull])) then {closeDialog 0;};
_medic action ["Gear", _cargo];
true
