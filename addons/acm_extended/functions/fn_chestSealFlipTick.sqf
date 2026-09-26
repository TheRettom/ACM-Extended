// Completion watcher for an already-dispatched chest-seal Flip.
// The button itself starts provider medic4 and the casualty roll immediately; this PFH never gates roll startup.
disableSerialization;
params ["_args","_handle"];
_args params ["_patient","_provider","_display","_session","_token","_epoch","_rollToken",
    "_side","_rollTime","_rollStarted","_deadline"];

private _current = (uiNamespace getVariable ["ACME_CS_FlipPendingToken",""]) == _token;
private _finish = {
    [_handle] call CBA_fnc_removePerFrameHandler;
    if ((uiNamespace getVariable ["ACME_CS_FlipPFH",-1]) == _handle) then {
        uiNamespace setVariable ["ACME_CS_FlipPFH",-1];
    };

    // Retire only this Flip's provider owner. A newer animation episode is never stopped by an old completion.
    if (!isNull _provider && {local _provider}
        && {(_provider getVariable ["ACME_rollProviderToken",""]) == _rollToken}
        && {_rollToken != ""}) then {
        private _pfh = _provider getVariable ["ACME_rollProviderPFH",-1];
        if (_pfh >= 0) then {[_pfh] call CBA_fnc_removePerFrameHandler;};
        _provider setVariable ["ACME_rollProviderPFH",-1];
        _provider setVariable ["ACME_rollProviderToken",""];
        _provider setVariable ["ACME_rollProviderActive",false];
        [_provider,"roll",_epoch,_current] call ACME_fnc_treatmentPoseStop;
    };
    if (!_current) exitWith {};

    // Restore hands-on-chest only when another provider action has not already taken animation ownership.
    private _after = if (isNull _provider) then {[]} else {_provider getVariable ["ACME_treatmentPoseState",[]]};
    if (_after isEqualTo [] && {!isNull _provider} && {local _provider}) then {
        private _holdEpoch = [_provider,_patient,true] call ACME_fnc_chestSealProviderHoldStart;
        _provider setVariable ["ACME_CS_providerHoldEpoch",_holdEpoch,false];
        uiNamespace setVariable ["ACME_CS_ProviderHoldEpoch",_holdEpoch];
    };

    uiNamespace setVariable ["ACME_CS_FlipPendingToken",""];
    uiNamespace setVariable ["ACME_CS_FlipLockedUntil",0];
    uiNamespace setVariable ["ACME_CS_FlipTarget",""];
    if (!isNull _display) then {
        private _button = _display displayCtrl 86426;
        _button ctrlEnable true;
        _button ctrlSetText "Flip";
    };
    if (!isNull _provider
        && {(_provider getVariable ["ACME_DP_PauseTreatmentClass",""]) == "chestsealflip"}) then {
        _provider setVariable ["ACME_DP_Paused",false];
        _provider setVariable ["ACME_DP_PauseTreatmentClass",""];
        _provider setVariable ["ACME_DP_TreatmentBusy",false];
        _provider setVariable ["ACME_DP_IdleStart",CBA_missionTime];
    };
};

if (!_current || {isNull _display} || {isNull _patient} || {isNull _provider}
    || {!alive _patient} || {!alive _provider}
    || {(uiNamespace getVariable ["ACME_CS_SessionToken",""]) != _session}
    || {!((uiNamespace getVariable ["ACME_CS_Patient",objNull]) isEqualTo _patient)}) exitWith {call _finish;};

// Startup is never deferred to this PFH anymore. A negative stamp is malformed/stale state and is retired.
if (_rollStarted < 0) exitWith {call _finish;};

private _patientDone = diag_tickTime >= (_rollStarted + _rollTime);
private _poseNow = _provider getVariable ["ACME_treatmentPoseState",[]];
private _providerStillRoll = (_poseNow param [0,-2]) == _epoch
    && {(_poseNow param [1,""]) == "roll"}
    && {(_provider getVariable ["ACME_rollProviderToken",""]) == _rollToken};
private _providerCompleted = (_provider getVariable ["ACME_rollProviderCompletedEpoch",-1]) == _epoch;
private _providerDone = _providerCompleted || {!_providerStillRoll} || {diag_tickTime >= _deadline};

// Both authored motions get their bounded accelerated window, but a missing animation callback can no longer
// strand the button for five-plus seconds. The deadline is derived at click time and capped at three seconds.
if (_patientDone && {_providerDone}) then {call _finish;};
