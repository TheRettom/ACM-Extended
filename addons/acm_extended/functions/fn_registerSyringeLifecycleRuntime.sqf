// DEV PHYS1-PC2: prepared/tagged syringes are current-life state; fresh kits also invalidate opened-vial remainder.
if (hasInterface) then {
    player addEventHandler ["Killed", {
        params ["_unit"];
        [_unit, []] call ACME_fnc_narcStoreCommit;
        uiNamespace setVariable ["ACME_SK_SelectedSyringeId", ""];
        uiNamespace setVariable ["ACME_SK_CarouselIdx", -1];
        uiNamespace setVariable ["ACME_SK_SelDrawn", -1];
    }];

    player addEventHandler ["Respawn", {
        params ["_unit"];
        [_unit] call ACME_fnc_resetPersonalMedicationKit;
    }];

    // ACE Arsenal applies a selected saved loadout before this event fires. The physical kit is now fresh,
    // therefore ACME's virtual syringe/open-vial state must be fresh as well.
    ["ace_arsenal_onLoadoutLoad", {
        if (is3DEN) exitWith {};
        private _unit = ACE_player;
        if (isNull _unit) exitWith {};
        [_unit] call ACME_fnc_resetPersonalMedicationKit;
    }] call CBA_fnc_addEventHandler;

    // Clipboard-imported loadouts are another wholesale kit replacement path in ACE Arsenal.
    ["ace_arsenal_loadoutImported", {
        params ["_display", ["_editorImport", false]];
        if (is3DEN || {_editorImport}) exitWith {};
        private _unit = ACE_player;
        if (isNull _unit) exitWith {};
        [_unit] call ACME_fnc_resetPersonalMedicationKit;
    }] call CBA_fnc_addEventHandler;
};
