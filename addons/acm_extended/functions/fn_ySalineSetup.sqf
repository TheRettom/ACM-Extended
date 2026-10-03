// this runs on the owning machine of the patient, fired through CBA_fnc_targetEvent with the target as the patient.
// the root cause of the recurring y saline still transfuses bug: ace_medical_status_fnc_getBloodVolumeChange, the
// sole iv-bag drainer, runs where the patient is local, and the patient owns ACM_circulation_IV_Bags and rewrites
// it every medical tick. the machine of the medic did the ACME_SalineY retag and a public setvariable, and the
// per-tick write of the owner can clobber that broadcast before its own override ever sees ACME_SalineY, so the
// reserve drains.
// doing the registration and retag here, on the owner, makes both authoritative: ACME_YLines is set locally, so the
// self-heal of the override reads it with no sync latency, and the saline is re-typed ACME_SalineY in the own
// IV_Bags of the owner, so the type-based clamp holds it for good.
// the medic still sets ACME_YLines publicly for its own menu ui, and this simply guarantees the owner agrees.
params ["_patient", "_lineKey", "_iv"];
if (isNull _patient) exitWith {};

// 1. make sure the y line is registered on the owner, both locally and globally.
private _yl = +(_patient getVariable ["ACME_YLines", []]);
if (!(_lineKey in _yl)) then {
    _yl pushBack _lineKey;
    [_patient, _yl] call ACME_fnc_yLinesCommit;
};

// 2. retag the just-hung saline to ACME_SalineY in the IV_Bags of the owner. it retries a few ticks, because the bag
// is hung through a separate ivbaglocal event that may land just after this one. it searches every body-part key,
// so a key we did not expect cannot make it miss. the self-heal of the override is the backstop if all the
// retries somehow miss.
private _tag = {
    params ["_patient", "_iv"];
    if (isNull _patient) exitWith { true };
    private _bags = _patient getVariable ["ACM_circulation_IV_Bags", createHashMap];
    private _done = false;
    {
        private _keyPart = _x;
        private _arr = _y;
        if (!_done) then {
            private _i = _arr findIf { ((_x param [0, ""]) == "Saline") && {(_x param [4, true]) isEqualTo _iv} };
            if (_i >= 0) then {
                private _e = +(_arr select _i);
                _e set [0, "ACME_SalineY"];
                _arr set [_i, _e];
                _bags set [_keyPart, _arr];
                [_patient, _bags] call ACME_fnc_ivBagsCommit;
                _done = true;
            };
        };
    } forEach _bags;
    _done
};

if (!([_patient, _iv] call _tag)) then {
    // not found yet, so a couple of short retries.
    [{
        params ["_args", "_h"];
        _args params ["_patient", "_iv", "_tag", "_tries"];
        _tries set [0, (_tries # 0) + 1];
        if (([_patient, _iv] call _tag) || {(_tries # 0) >= 12}) then {
            [_h] call CBA_fnc_removePerFrameHandler;
        };
    }, 0.25, [_patient, _iv, _tag, [0]]] call CBA_fnc_addPerFrameHandler;
};
