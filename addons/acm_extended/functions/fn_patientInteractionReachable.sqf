/* One clinical reach rule for patient-scoped medical actions.
 *
 * Vehicle occupancy changes presentation, not treatment eligibility:
 * - occupants of the same vehicle remain reachable regardless of model-origin spacing;
 * - every other pairing uses the same ACME interaction distance as the medical menu.
 *
 * Unit animations remain independently suppressed by ACME_fnc_animBlocked while seated.
 */
params [
    ["_medic", objNull, [objNull]],
    ["_patient", objNull, [objNull]],
    ["_maxDistance", -1, [0]]
];

if (isNull _medic || {isNull _patient}) exitWith {false};
if (_maxDistance < 0) then {_maxDistance = ace_medical_gui_maxDistance;};
if (!finite _maxDistance || {_maxDistance <= 0}) exitWith {false};

private _medicVehicle = vehicle _medic;
private _patientVehicle = vehicle _patient;

if (_medicVehicle isNotEqualTo _medic && {_medicVehicle isEqualTo _patientVehicle}) exitWith {true};

([_medic, _patient] call ACME_fnc_patientInteractionDistance) < _maxDistance
