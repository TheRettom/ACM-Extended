/* Original request-machine supply settlement; never follows provider locality. */
params ["_patient", "_side", "_epoch", "_request", "_receipt", "_accepted"];
if !(_receipt isEqualTo []) then {[_receipt, !_accepted] call ACME_fnc_treatmentSupplyRefund;};
private _pending = uiNamespace getVariable ["ACME_Thora_WidenPending", []];
if (count _pending >= 5 && {(_pending select 0) isEqualTo _patient}
    && {(_pending select 1) == _side} && {(_pending select 2) == _epoch}
    && {(_pending select 4) isEqualTo _request}) then {
    uiNamespace setVariable ["ACME_Thora_WidenPending", []];
    if (!_accepted && {hasInterface}) then {
        ["Thoracostomy state changed; check the current tract and retry.", 3] call ace_common_fnc_displayTextStructured;
    };
};
