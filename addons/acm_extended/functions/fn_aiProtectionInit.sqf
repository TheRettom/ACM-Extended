/* ACE owns the effect implementation and aggregation. ACME owns one reason and bounded observer refreshes. */
if !(missionNamespace getVariable ["ACME_aiProtection_installed", false]) then {
    missionNamespace setVariable ["ACME_aiProtection_installed", true];
    ["CBA_settingsInitialized", {[] call ACME_fnc_aiProtectionInit;}] call CBA_fnc_addEventHandler;
    ["ACME_aiProtectionObserverReady", {
        // Several machines joining together coalesce into one replay per already-protected patient.
        missionNamespace setVariable ["ACME_aiProtection_replaySerial", 1 + (missionNamespace getVariable ["ACME_aiProtection_replaySerial", 0])];
    }] call CBA_fnc_addEventHandler;
};
if !(missionNamespace getVariable ["ace_common_settingsInitFinished", false]) exitWith {};
if (isNil "ace_common_fnc_statusEffect_set" || {isNil "ace_common_fnc_statusEffect_sendEffects"}) exitWith {};
private _reasons = missionNamespace getVariable ["ace_common_statusEffects_setHidden", []];
// Never let clients concurrently append different reason indices through statusEffect_set. Preserve ACE's
// pre-seeded reasons and wait for that registered effect before the server publishes our one stable addition.
if (isServer && {!(_reasons isEqualTo [])} && {!("acme_medical_downed" in _reasons)}) then {
    _reasons = +_reasons;
    _reasons pushBack "acme_medical_downed";
    missionNamespace setVariable ["ace_common_statusEffects_setHidden", _reasons, true];
};
if !("acme_medical_downed" in _reasons) exitWith {};
missionNamespace setVariable ["ACME_aiProtection_ready", true];
if !(missionNamespace getVariable ["ACME_aiProtection_announced", false]) then {
    missionNamespace setVariable ["ACME_aiProtection_announced", true];
    // ACE setHidden is global but not JIP. Once a new client's ACE receiver/reason table is ready, notify existing
    // patient owners to replay their current aggregate state. No server patient registry or world scan is needed.
    ["ACME_aiProtectionObserverReady", []] call CBA_fnc_globalEvent;
};
