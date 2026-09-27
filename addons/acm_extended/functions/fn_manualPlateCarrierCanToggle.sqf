/* DEV 1.3.0 PC1: eligibility for the persistent manual plate-carrier toggle.
 *
 * Manual custody is deliberately separate from ACME_chestAccess_* / ACME_CS_* temporary custody.
 * A manually removed carrier stays off across later chest interventions until Replace Plate Carrier is pressed.
 */
params [
    ["_medic", objNull, [objNull]],
    ["_patient", objNull, [objNull]],
    ["_restore", false, [false]]
];

if (isNull _medic || {isNull _patient} || {!(_patient isKindOf "CAManBase")}) exitWith {false};
if (!alive _medic || {!([_medic] call ace_common_fnc_isAwake)}) exitWith {false};

// Never race temporary chest-access ownership. Manual custody can exist before/after these systems, not during them.
private _accessSaved = +(_patient getVariable ["ACME_chestAccess_vestLoadout", []]);
private _sealSaved = +(_patient getVariable ["ACME_CS_vestLoadout", []]);
private _accessBusy = _patient getVariable ["ACME_chestAccess_vestBusy", ""];
private _sealBusy = _patient getVariable ["ACME_CS_vestBusy", ""];
private _leases = _patient getVariable ["ACME_chestAccess_leases", createHashMap];
if !(_leases isEqualType createHashMap) then {_leases = createHashMap;};

private _procedureBusy =
    (count _accessSaved) == 2
    || {(count _sealSaved) == 2}
    || {_accessBusy != ""}
    || {_sealBusy != ""}
    || {_patient getVariable ["ACME_CS_ProcedureActive", false]}
    || {_patient getVariable ["ACME_Thora_ChestAccessActive", false]}
    || {(count _leases) > 0}
    || {[_patient] call ACME_fnc_chestAccessManeuverActive};
if (_procedureBusy) exitWith {false};

private _saved = +(_patient getVariable ["ACME_manualPlateCarrierLoadout", []]);
private _savedClass = _saved param [0, "", [""]];
private _hasStored = (count _saved) == 2 && {_savedClass != ""};
private _worn = vest _patient;

if (_restore) exitWith {
    _hasStored && {_worn == ""}
};

// Remove is available only while something is actually in the vest slot. If another script has already restored
// the exact stored carrier, allow removal again and refresh the stored snapshot instead of leaving a dead toggle.
_worn != "" && {!_hasStored || {_worn == _savedClass}}
