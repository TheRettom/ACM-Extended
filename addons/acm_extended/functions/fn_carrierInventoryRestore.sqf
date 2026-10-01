/* Settle custody once, in the patient owner's unscheduled frame. Live Gear/treatment changes win.
   Never overwrite a replacement vest or restore spent supplies from a stale loadout snapshot. */
params ["_patient", "_saved", "_savedVar"];
if (isNull _patient || {!local _patient}) exitWith {false};
private _class = _saved param [0, "", [""]];
if (_class == "") exitWith {false};
if (_patient getVariable [_savedVar + "Settled", false]) exitWith {true};
private _live = _patient getVariable [_savedVar + "Live", false];
if (!_live) exitWith {
    // Compatibility for a saved pre-B218 episode which has no live holder at all.
    if (vest _patient != "") exitWith {true};
    private _loadout = getUnitLoadout _patient;
    _loadout set [4, +_saved];
    _patient setUnitLoadout [_loadout, false];
    private _restored = vest _patient == _class;
    if (_restored) then {_patient setVariable [_savedVar + "Settled", true, true];};
    _restored
};
// Do not discard either carrier when another mod equips a different vest during custody.
if (vest _patient != "") exitWith {false};
private _cargo = _patient getVariable ["ACME_carrierCargo", objNull];
if (!isNull _cargo && {(_cargo getVariable ["ACME_carrierSavedVar", ""]) != _savedVar
    || {!((_cargo getVariable ["ACME_carrierPatient", objNull]) isEqualTo _patient)}}) exitWith {false};
if (!isNull _cargo) then {_cargo setVariable ["ACME_carrierClosing", true, true];};
private _snapshot = [_cargo] call ACME_fnc_carrierCargoSnapshot;
_patient addVest _class;
if (vest _patient != _class) exitWith {
    if (!isNull _cargo) then {_cargo setVariable ["ACME_carrierClosing", false, true];};
    false
};
[vestContainer _patient, _snapshot] call ACME_fnc_carrierCargoPopulate;
if !([_snapshot, [vestContainer _patient] call ACME_fnc_carrierCargoSnapshot] call ACME_fnc_carrierCargoEqual) exitWith {
    // Keep the live holder authoritative if the returned vest rejected any contents.
    removeVest _patient;
    if (!isNull _cargo) then {_cargo setVariable ["ACME_carrierClosing", false, true];};
    diag_log "[ACME CARRIER] Restored cargo did not round-trip; live custody retained.";
    false
};
_patient setVariable ["ACME_carrierCargo", objNull, true];
_patient setVariable [_savedVar + "Live", false, true];
_patient setVariable [_savedVar + "Settled", true, true];
if (!isNull _cargo) then {
    // Pending supply refunds fall back to the donor once this exact container is gone.
    [_cargo, [[], [], [], []]] call ACME_fnc_carrierCargoPopulate;
    deleteVehicle _cargo;
};
true
