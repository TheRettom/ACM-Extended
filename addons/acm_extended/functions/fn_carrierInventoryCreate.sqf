/* Patient owner only. Stage live contents BEFORE removeVest destroys the worn container.
   The holder contains supplies, never a wearable copy of the removed carrier. */
params ["_patient", "_savedVar"];
if (isNull _patient || {!local _patient} || {isNull vestContainer _patient}) exitWith {objNull};
if (!isNull (_patient getVariable ["ACME_carrierCargo", objNull])) exitWith {objNull};
private _snapshot = [vestContainer _patient] call ACME_fnc_carrierCargoSnapshot;
private _cargo = createVehicle ["ACME_RemovedCarrierCargo", getPosATL _patient, [], 0, "CAN_COLLIDE"];
if (isNull _cargo) exitWith {objNull};
[_cargo, _snapshot] call ACME_fnc_carrierCargoPopulate;
if !([_snapshot, [_cargo] call ACME_fnc_carrierCargoSnapshot] call ACME_fnc_carrierCargoEqual) exitWith {
    // A rejected engine cargo write must never destroy the still-worn original.
    deleteVehicle _cargo;
    diag_log "[ACME CARRIER] Cargo staging did not round-trip; worn carrier retained.";
    objNull
};
_cargo allowDamage false;
_cargo setVariable ["ACME_carrierPatient", _patient, true];
_cargo setVariable ["ACME_carrierSavedVar", _savedVar, true];
_cargo setVariable ["ace_dragging_canDrag", false, true];
_cargo setVariable ["ace_dragging_canCarry", false, true];
_cargo setVariable ["ace_cargo_canLoad", false, true];
_patient setVariable ["ACME_carrierCargo", _cargo, true];
_patient setVariable [_savedVar + "Live", true, true];
_patient setVariable [_savedVar + "Settled", false, true];
_cargo
