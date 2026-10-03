/* B227: actions belong to selected access (not arbitrary selected row); frame updates don't recreate controls. */
disableSerialization;
params ["_display", "_patient", "_part", "_iv", "_site", "_isY"];
private _flush = _display displayCtrl 86143;
private _prime = _display displayCtrl 86150;
_flush ctrlShow _isY; _prime ctrlShow _isY;
if (!_isY || {isNull _patient}) exitWith {};
private _state = [_patient,_part,_iv,_site] call ACME_fnc_yServiceState;
_state params ["_reserve","_reserved","_blood","_dirty","_primed","_kind","_id","_job"];
private _flushPlan = ["flush",_reserve,_reserved,_blood,_dirty,_primed,_kind] call ACME_fnc_yServicePlan;
private _primePlan = ["prime",_reserve,_reserved,_blood,_dirty,_primed,_kind] call ACME_fnc_yServicePlan;
private _canCancel = _kind == "flush" && {count (_job param [9,[]]) > 0};
_flush ctrlEnable ((_flushPlan select 0) || {_canCancel});
_prime ctrlEnable (_primePlan select 0);
private _count = if (_job isEqualTo []) then {0} else {1 + count (_job param [9,[]])};
private _text = if (_kind == "flush") then {format ["Flush In Progress... (%1)",_count]} else {"Flush Line"};
if (ctrlText _flush != _text) then {_flush ctrlSetText _text;};
private _primeText = if (_kind == "prime") then {"Priming..."} else {["Prime Line (25 mL)","Line Primed"] select _primed};
if (ctrlText _prime != _primeText) then {_prime ctrlSetText _primeText;};
if !(_flush getVariable ["ACME_serviceRightClick",false]) then {
    _flush setVariable ["ACME_serviceRightClick",true];
    _flush ctrlAddEventHandler ["MouseButtonDown", {
        params ["_control","_button"];
        if (_button != 1) exitWith {false};
        ["cancel"] call ACME_fnc_transfusionFlushLine;
        true
    }];
};
