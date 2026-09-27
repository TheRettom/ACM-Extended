// B191: prepared/tagged syringes and opened-vial remainder are personal kit state, not permanent player state.
if (hasInterface) then {
    player addEventHandler ["Killed", {
        params ["_unit"];
        [_unit] call ACME_fnc_resetPersonalMedicationKit;
    }];

    player addEventHandler ["Respawn", {
        params ["_unit"];
        [_unit] call ACME_fnc_resetPersonalMedicationKit;
    }];

    // ACE Arsenal applies the selected saved loadout before this event fires. Reset ACME's hidden medication
    // ledgers at the same boundary so restored physical vials/syringes cannot coexist with stale partial vials or
    // previously prepared syringes. Manual Arsenal browsing and ordinary inventory changes do not trigger this.
    ["ace_arsenal_onLoadoutLoad", {
        if (is3DEN) exitWith {};
        private _unit = ACE_player;
        if (isNull _unit) exitWith {};
        [_unit] call ACME_fnc_resetPersonalMedicationKit;
    }] call CBA_fnc_addEventHandler;

    // Clipboard-imported loadouts are another wholesale kit replacement path in ACE Arsenal.
    ["ace_arsenal_loadoutImported", {
        params ["", ["_editorImport", false]];
        if (is3DEN || {_editorImport}) exitWith {};
        private _unit = ACE_player;
        if (isNull _unit) exitWith {};
        [_unit] call ACME_fnc_resetPersonalMedicationKit;
    }] call CBA_fnc_addEventHandler;
};
