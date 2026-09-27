/* B11: preserve ACE's menu gates; resolve only supported-patient pose distance.
   Reference: supplied ACE medical_gui/functions/fnc_canOpenMenu.sqf. */
params ["_player", "_target"];
if (!isNull findDisplay 312) exitWith {
    !isNull _target && {missionNamespace getVariable ["ace_medical_gui_enableZeusModule", true]}
    && {ace_medical_gui_enableMedicalMenu > 0}
};
(_player call ace_common_fnc_isAwake) && {!isNull _target}
&& {[_player, _target] call ACME_fnc_patientInteractionReachable}
&& {ace_medical_gui_enableMedicalMenu == 1
    || {ace_medical_gui_enableMedicalMenu == 2 && {!isNull objectParent _player || {!isNull objectParent _target}}}}
