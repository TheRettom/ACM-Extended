#include "script_component.hpp"

[QGVAR(initFullHealFacility), {
    params ["_object"];

    [_object] call FUNC(initFullHealFacility);
}] call CBA_fnc_addEventHandler;

["CBA_settingsInitialized", {
    GVAR(TrainingCasualtyGroup) = createGroup [civilian, false];
    if (isServer) then {GVAR(TrainingBluforGroup) = createGroup [west, false];};
}] call CBA_fnc_addEventHandler;

[QGVAR(requestTrainingPatient), {
    if (!isServer) exitWith {};
    _this call FUNC(requestTrainingPatient);
}] call CBA_fnc_addEventHandler;
