// Unscheduled patient-owner arbitration. An unexpired lease wins even before the
// provider's Active flag replicates. No inventory, dose, patient-life or animation policy here.
params ["_patient", "_operation", "_args"];
if (isNull _patient || {!local _patient}) exitWith {false};
_args params [["_medic", objNull, [objNull]], ["_episode", -1, [0]],
    ["_flow", 1.75, [0]], ["_epoch", -1, [0]], ["_providerOwner", -1, [0]]];
private _holder = _patient getVariable ["ACME_hang_Medic", objNull];
private _heldEpisode = _patient getVariable ["ACME_hang_Episode", -2];
private _exact = _holder isEqualTo _medic && {_heldEpisode == _episode};
if (_operation == "release") exitWith {
    if (_exact) then {
        _patient setVariable ["ACME_hang_flowMult", 1, true];
        _patient setVariable ["ACME_hang_Medic", objNull, true];
        _patient setVariable ["ACME_hang_Episode", -1, true];
        _patient setVariable ["ACME_hang_LeaseUntil", -1, true];
    };
    _exact
};
if !(_operation in ["claim", "renew"]) exitWith {false};
private _now = serverTime;
private _valid = !isNull _medic && {alive _medic} && {finite _episode} && {_episode >= 0}
    && {finite _flow} && {_providerOwner > 0}
    // owner returns 0 off-server. The server resolves remote ownership; a client can verify only its own medic.
    && {if (isServer) then {_providerOwner == owner _medic} else {!local _medic || {_providerOwner == clientOwner}}}
    && {!(_medic getVariable ["ACE_isUnconscious", false])}
    && {isNull objectParent _medic}
    && {_medic distance _patient <= (missionNamespace getVariable ["ACME_hang_leash", 3])}
    && {_epoch == ([_patient] call ACME_fnc_clinicalEpoch)}
    && {!(_patient getVariable ["ACME_clinicalRestoring", false])}
    && {missionNamespace getVariable ["ACME_sys_hang", true]};
private _leaseUntil = _patient getVariable ["ACME_hang_LeaseUntil", -1];
private _holderValid = !isNull _holder && {alive _holder} && {
    if (_leaseUntil >= 0) then {
        _leaseUntil > _now && {(_patient getVariable ["ACME_hang_LeaseEpoch", -1]) == _epoch}
    } else {
        // Preserve a pre-upgrade active holder rather than steal its workspace.
        _holder getVariable ["ACME_hang_Active", false]
    }
};
private _accepted = _valid && {
    if (_operation == "renew") then {
        _exact && {_leaseUntil > _now}
    } else {
        // An old request cannot reacquire a cancelled hold long after its timeout.
        _now - _episode <= 5 && {!_holderValid || {_exact}}
    }
};
if (_accepted) then {
    if (!_exact) then {
        _patient setVariable ["ACME_hang_Medic", _medic, true];
        _patient setVariable ["ACME_hang_Episode", _episode, true];
        _patient setVariable ["ACME_hang_LeaseEpoch", _epoch, true];
    };
    _patient setVariable ["ACME_hang_LeaseUntil", _now + 6, true];
    private _nextFlow = (_flow max 1) min 5;
    if ((_patient getVariable ["ACME_hang_flowMult", 1]) != _nextFlow) then {
        _patient setVariable ["ACME_hang_flowMult", _nextFlow, true];
    };
};
if (!isNull _medic) then {
    ["ACME_hangClaimAck", [_patient, _medic, _episode, _accepted, _epoch, _providerOwner, _now + 6], _medic] call CBA_fnc_targetEvent;
};
_accepted
