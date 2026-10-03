/* Patient-owner commit. Receipts survive full heal so delayed retries stay idempotent.
   The pressure infuser itself is reusable and is never consumed; _isNewCuff only distinguishes first application
   from pumping an already fitted cuff. Modern pump receipts expire only after their request deadline. Legacy receipts keep their original lifetime. */
params ["_patient", "_medic", "_bagId", "_epoch", "_id", "_issued", "_isNewCuff", ["_allowDrug", false], ["_protocol", ""]];
if (isNull _patient || {!local _patient} || {isNull _medic}) exitWith {};
if (_protocol == "pump-b227" && {serverTime - _issued > 10 || {_issued > serverTime + 2}}) exitWith {
    ["ACME_piAck", [_id, false, false, "Pressure pump request expired. Press again."], _medic] call CBA_fnc_targetEvent;
};
private _receipts = _patient getVariable ["ACME_piReceipts", createHashMap];
{
    private _r = _receipts get _x;
    if (count _r >= 4 && {serverTime - (_r select 3) > 12}) then {_receipts deleteAt _x;};
} forEach keys _receipts;
private _old = _receipts getOrDefault [_id, []];
if !(_old isEqualTo []) exitWith {
    ["ACME_piAck", [_id, _old select 0, _old select 1, _old select 2], _medic] call CBA_fnc_targetEvent;
};
private _ok = false;
private _refund = false;
private _message = "Pressure cuff request rejected: the patient or bag changed.";
private _found = [];
// Legacy _issued originates on the provider-local clock and is never compared with the owner's CBA clock.
// B227 requests explicitly use shared serverTime and were deadline-checked above. Both paths also recheck
// epoch, stable bag identity, live contents, provider distance and duplicate receipts.
if (alive _medic && {!(_medic getVariable ["ACE_isUnconscious", false])} && {(_medic distance _patient) <= 5}
    && {_epoch == ([_patient] call ACME_fnc_clinicalEpoch)}) then {
    {
        private _i = _y findIf {(_x param [8, ""]) == _bagId};
        if (_i >= 0) exitWith { _found = _y select _i; };
    } forEach (_patient getVariable ["ACM_circulation_IV_Bags", createHashMap]);
    if !(_found isEqualTo []) then {
        private _hasDrug = ((_patient getVariable ["ACME_infusion_BagMedications", []]) findIf {(_x param [23, ""]) == _bagId}) >= 0;
        private _type = _found param [0, ""];
        private _eligible = _type in ["Blood", "FreshBlood", "Saline", "Plasma", "PlasmaLyte"] || {(toLowerANSI _type) in keys (missionNamespace getVariable ["ACME_infusion_premixedByType", createHashMap])};
        if (!(_hasDrug isEqualTo _allowDrug)) then {_message = "The bag changed section. Select it in the correct list.";};
        if (_hasDrug isEqualTo _allowDrug && {_eligible} && {(_found param [1, 0]) > 0.5}) then {
            private _cuffs = _patient getVariable ["ACME_piCuffs", createHashMap];
            private _already = _bagId in _cuffs;
            if (_already || {_isNewCuff && {([_medic, _patient, "ACME_PressureInfuser"] call ACME_fnc_treatmentSupplyCount) > 0}}) then {
                private _level = [_cuffs getOrDefault [_bagId, []]] call ACME_fnc_pressureLevel;
                _cuffs set [_bagId, [serverTime, (_level + 0.25) min 1, "server"]];
                [_patient, "cuffs", _cuffs] call ACME_fnc_pressureInfuserStateCommit;
                _ok = true;
                _message = if (_already) then {"Pressure cuff pumped."} else {"Pressure infuser applied to the selected bag."};
            };
        };
    };
};
private _receipt = [_ok, _refund, _message];
if (_protocol == "pump-b227") then {_receipt pushBack serverTime;};
_receipts set [_id, _receipt];
[_patient, "receipts", _receipts] call ACME_fnc_pressureInfuserStateCommit;
["ACME_piAck", [_id, _ok, _refund, _message], _medic] call CBA_fnc_targetEvent;
