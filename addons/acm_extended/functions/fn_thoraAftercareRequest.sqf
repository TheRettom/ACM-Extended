/* One discrete surgical-tract input, identified before crossing patient locality. */
params ["_patient", "_medic", "_side", "_operation", ["_usedKit", false], ["_receipt", []]];
if (isNull _patient || {isNull _medic}) exitWith {};
private _sequence = (missionNamespace getVariable ["ACME_pleuralDrainSequence", 0]) + 1;
missionNamespace setVariable ["ACME_pleuralDrainSequence", _sequence];
private _epoch = [_patient] call ACME_fnc_clinicalEpoch;
private _request = [clientOwner, _sequence, serverTime];
private _packet = [_patient, "thoraAftercare", [_patient, _medic, _side, _operation, _epoch, _request, _usedKit, _receipt]];
if (_operation == "widen") then {
    uiNamespace setVariable ["ACME_Thora_WidenPending", [_patient, _side, _epoch, diag_tickTime, _request]];
};
_packet call ACME_fnc_ownerDispatch;
if !(_receipt isEqualTo []) then {
    // Query the SAME transaction once if its ACK was delayed/lost during locality
    // transfer. Never refund solely on a timeout: it may already have succeeded.
    [{
        params ["_packet", "_receipt"];
        private _pending = missionNamespace getVariable ["ACME_supplyReceipts", createHashMap];
        if ((_pending getOrDefault [_receipt param [3, ""], []]) isEqualTo _receipt) then {
            _packet call ACME_fnc_ownerDispatch;
        };
    }, [_packet, _receipt], 16] call CBA_fnc_waitAndExecute;
};
