/* B227 owner-local queue. Replayed/delayed requests cannot double-debit or queue on a new patient epoch. */
params ["_p", "_medic", "_part", "_iv", "_site", "_epoch", ["_mode", "flush"], ["_request", ""], ["_issued", -1]];
if (isNull _p || {!local _p} || {!alive _p} || {isNull _medic} || {!alive _medic}
    || {_medic getVariable ["ACE_isUnconscious", false]} || {_epoch != ([_p] call ACME_fnc_clinicalEpoch)}
    || {([_medic, _p] call ACME_fnc_patientInteractionDistance) > 5}) exitWith {};
if (_request != "" && {serverTime - _issued > 10 || {_issued > serverTime + 2}}) exitWith {};
private _receipts = _p getVariable ["ACME_yServiceReceipts", createHashMap];
if (_request != "" && {_request in _receipts}) exitWith {};
{if (serverTime - (_receipts get _x) > 12) then {_receipts deleteAt _x;};} forEach keys _receipts;
if (_request != "") then {_receipts set [_request, serverTime]; [_p,"ACME_yServiceReceipts",_receipts] call ACME_fnc_setVarNet;};
_part = toLowerANSI _part;
if !([_p, _part, _iv, _site] call ACME_fnc_isYLineAccess) exitWith {[_medic, "No Y tubing on that access site."] call ACME_fnc_clinicalNotice;};
if !([_p, _part, _iv, _site] call ACME_fnc_transfusionAccessValid) exitWith {};
private _key = toLowerANSI format ["%1#%2#%3", _part, _iv, _site];
private _refill = (_p getVariable ["ACME_yRefillClaims", createHashMap]) getOrDefault [_key, []];
if (count _refill >= 4 && {CBA_missionTime - (_refill select 3) < 30}) exitWith {
    [_medic, "Finish replacing the bag before servicing this line."] call ACME_fnc_clinicalNotice;
};
private _jobs = _p getVariable ["ACME_yFlushJobs", createHashMap];
([_p,_part,_iv,_site] call ACME_fnc_yServiceState) params ["_reserve","_reserved","_blood","_dirty","_primed","_running","_id","_job"];
if (_mode == "cancel") exitWith {
    // Right click removes the last QUEUED flush only. Fluid already delivered is never refunded.
    private _queue = +(_job param [9, []]);
    if (_running == "flush" && {_queue isNotEqualTo []}) then {
        _queue deleteAt (count _queue - 1); _job set [9, _queue]; _jobs set [_key, _job];
        [_p, "ACME_yFlushJobs", _jobs] call ACME_fnc_setVarNet;
    };
};
([_mode,_reserve,_reserved,_blood,_dirty,_primed,_running] call ACME_fnc_yServicePlan) params ["_ok","_total","_reason"];
if (!_ok) exitWith {[_medic,_reason] call ACME_fnc_clinicalNotice;};
if (_job isNotEqualTo [] && {count (_job param [9,[]]) >= 100}) exitWith {};
if (_job isNotEqualTo []) then {
    private _queue = +(_job param [9, []]); _queue pushBack _total;
    _job set [9, _queue];
} else {
    if (_id == "") then {
        private _bags = (_p getVariable ["ACM_circulation_IV_Bags", createHashMap]) getOrDefault [_part, []];
        private _index = _bags findIf {(_x param [0, ""]) in ["Saline","ACME_SalineY"] && {(_x param [3,-1]) == _site} && {(_x param [4,true]) isEqualTo _iv}};
        if (_index >= 0) then {_id = [_p, _part, _index] call ACME_fnc_bagIdentity;};
    };
    if (_id != "") then {_job = [_part,_iv,_site,_id,_total,_total / ((missionNamespace getVariable ["ACME_YFlushSeconds",5]) max 0.1),serverTime,_medic,_epoch,[],_mode,_total,0];};
};
if (_job isEqualTo []) exitWith {};
_jobs set [_key,_job];
[_p, "ACME_yFlushJobs", _jobs] call ACME_fnc_setVarNet;
