/* Provider-local reply for the patient-owner Direct Pressure site claim. */
params ["_patient","_medic","_part","_token","_accepted","_epoch","_providerOwner",["_grantUntil",-1,[0]]];
if (isNull _medic || {!local _medic}) exitWith {};

// The pending slot is cleared after first activation. An identical accepted reply is then a duplicate,
// not a cancelled request: releasing it would tear down the live owner's reservation.
if (_accepted && {_providerOwner == clientOwner}
    && {_epoch == ([_patient] call ACME_fnc_clinicalEpoch)}
    && {_medic getVariable ["ACME_DP_Active",false]}
    && {(_medic getVariable ["ACME_DP_Patient",objNull]) isEqualTo _patient}
    && {(_medic getVariable ["ACME_DP_Part",""]) == _part}
    && {(_medic getVariable ["ACME_DP_ClaimToken",""]) == _token}
    && {(_medic getVariable ["ACME_DP_ClaimEpoch",-1]) == _epoch}) exitWith {};

private _pending = _medic getVariable ["ACME_DP_ClaimPending",[]];
private _same = (_pending isEqualType []) && {count _pending >= 4}
    && {(_pending select 0) isEqualTo _patient}
    && {(_pending select 1) == _part}
    && {(_pending select 2) == _token}
    && {(_pending select 3) == _epoch};
if (!_same) exitWith {
    // A delayed accepted ACK from a timed-out/superseded request must release only its own owner-side token.
    // Token matching in directPressureClaimLocal prevents this from touching a newer episode from the same medic.
    if (_accepted && {!isNull _patient}) then {
        [_patient,"directPressureClaim",["release",[_medic,_part,_token,_epoch,_providerOwner]]] call ACME_fnc_ownerDispatch;
    };
};

_medic setVariable ["ACME_DP_ClaimPending",[],false];
_medic setVariable ["ACME_DP_ClaimRequestedAt",-1,false];

private _stillValid = _accepted
    // The owner can hand this site to another provider once the pending grant expires.
    // Do not trust a replicated claim read here: the immutable owner deadline travels with the ACK.
    && {finite _grantUntil} && {serverTime < _grantUntil}
    && {!isNull _patient}
    && {alive _medic}
    && {!(_medic getVariable ["ACE_isUnconscious",false])}
    && {_providerOwner == clientOwner}
    && {_epoch == ([_patient] call ACME_fnc_clinicalEpoch)}
    && {!(missionNamespace getVariable ["ACM_core_ContinuousAction_Active",false])}
    && {!(_medic getVariable ["ACM_circulation_isPerformingCPR",false])}
    && {!(_medic getVariable ["ACM_breathing_isUsingBVM",false])}
    && {missionNamespace getVariable ["ACME_sys_dp",true]};

if (!_stillValid) exitWith {
    if (_accepted) then {
        [_patient,"directPressureClaim",["release",[_medic,_part,_token,_epoch,_providerOwner]]] call ACME_fnc_ownerDispatch;
    };
    if (!_accepted) then {
        ["Direct pressure is already being maintained on this site.",2,_medic] call ace_common_fnc_displayTextStructured;
    };
};

_medic setVariable ["ACME_DP_ClaimToken",_token,true];
_medic setVariable ["ACME_DP_ClaimEpoch",_epoch,true];
_medic setVariable ["ACME_DP_ClaimLostAt",-1,false];

[_patient,0.85] call ACME_fnc_markImportantSfx;
[_medic, "ACME_DirectPressure"] call ACME_fnc_worldSfxNearby;

if (_part == "body") then {
    [_medic,_patient,_part] call ACME_fnc_directPressureTorso;
} else {
    if (_patient isEqualTo _medic) then {
        [_medic,_patient,_part] call ACME_fnc_directPressureSelf;
    } else {
        [_medic,_patient,_part] call ACME_fnc_directPressureLimb;
    };
};
