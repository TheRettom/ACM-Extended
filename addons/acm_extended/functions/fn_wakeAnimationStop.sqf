/* Retire only this owner-local wake presentation. Never change consciousness or lying flags.
 * _exit=true permits a normal graph exit only while this exact visual still owns the body. */
params [["_patient",objNull,[objNull]], ["_serial",-1,[0]], ["_exit",false,[false]]];
if (isNull _patient) exitWith {false};
private _record = _patient getVariable ["ACME_wakeVisual", []];
if (count _record < 12 || {_serial >= 0 && {(_record select 0) != _serial}}) exitWith {false};
_patient setVariable ["ACME_wakeVisual", [], false];
private _pfh = _record select 7;
if (_pfh >= 0) then {[_pfh] call CBA_fnc_removePerFrameHandler;};
if (!local _patient) exitWith {true};
if (((_patient getVariable ["ACME_wakeVisualToken",[]]) param [0,-1]) == (_record select 0)) then {
    _patient setVariable ["ACME_wakeVisualToken", [], true];
};
if (_exit && {alive _patient} && {!(_patient getVariable ["ACE_isUnconscious",false])}
    && {isNull objectParent _patient} && {isNull attachedTo _patient}
    && {(_record select 6) == ([_patient] call ACME_fnc_clinicalEpoch)}
    && {((_patient getVariable ["ACME_patientAnimLock",[]]) param [4,-1]) <= serverTime}
    && {(toLowerANSI animationState _patient) == toLowerANSI (_record select 1)}) then {
    private _rest = _record select 2;
    if (_rest == "ACM_LyingState" && {!(_patient getVariable ["ACM_core_Lying_State",false])}) then {
        _rest = "AmovPpneMstpSnonWnonDnon";
    };
    _patient playMoveNow _rest;
};
true
