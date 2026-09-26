#include "script_component.hpp"

// Presentation worker exists only on clients.
if (hasInterface && {isNil QGVAR(visualEffectsPFH)}) then {
    GVAR(visualEffectsPFH) = [LINKFUNC(updateVisualEffects), 0.25, []] call CBA_fnc_addPerFrameHandler;
};

if (isNil QGVAR(activePatients)) then {GVAR(activePatients) = [];};
if (isNil QGVAR(lastDiscovery)) then {GVAR(lastDiscovery) = -1;};

// Owner-authoritative shield placement. The treatment callback may originate on another medic,
// but the patient's HMD slot and durable ocular state are mutated only where that patient is local.
[QGVAR(applyEyeShield), {
    params ["_patient","_shieldItem","_eyeIndex"];
    if (isNull _patient || {!local _patient} || {!alive _patient}) exitWith {};

    private _existingHmd = hmd _patient;
    if (_existingHmd != "" && {_existingHmd != _shieldItem}) then {
        _patient unlinkItem _existingHmd;
        _patient addItem _existingHmd;
    };
    if ((hmd _patient) != _shieldItem) then {_patient linkItem _shieldItem;};

    _patient setVariable [QGVAR(eyeShieldItem),_shieldItem,true];
    _patient setVariable [QGVAR(eyeShieldIndex),_eyeIndex,true];
    _patient setVariable [QGVAR(eyeShieldAppliedAt),CBA_missionTime,true];
    GVAR(activePatients) pushBackUnique _patient;

    if (hasInterface && {_patient isEqualTo ACE_player}) then {
        private _displayId = [17103,17102] select _eyeIndex;
        [_displayId] call FUNC(showEyeShieldOverlay);
    };
}] call CBA_fnc_addEventHandler;

// One locality-safe ocular worker per machine. Active structural casualties tick every second;
// a slow discovery fallback recovers locality migration/JIP and restored persistent state.
if (isNil QGVAR(structuralPFH)) then {
    GVAR(structuralPFH) = [{
        private _active = GVAR(activePatients) select {!isNull _x && {alive _x}};

        {
            if (local _x) then {[_x] call FUNC(structuralTick);};
        } forEach _active;

        _active = _active select {
            local _x && {alive _x} && {
                private _eyes = _x getVariable [QGVAR(eyeInjuries),[1,1]];
                (_eyes isEqualType [] && {count _eyes == 2} && {({_x < 0.999} count _eyes) > 0})
                || {(_x getVariable [QGVAR(eyeShieldItem),""]) != ""}
            }
        };

        if (GVAR(lastDiscovery) < 0 || {CBA_missionTime - GVAR(lastDiscovery) >= 10}) then {
            GVAR(lastDiscovery) = CBA_missionTime;
            {
                private _patient = _x;
                if (local _patient && {alive _patient} && {_patient isKindOf "CAManBase"}) then {
                    private _eyes = _patient getVariable [QGVAR(eyeInjuries),[1,1]];
                    private _needs = (_eyes isEqualType [] && {count _eyes == 2} && {({_x < 0.999} count _eyes) > 0})
                        || {(_patient getVariable [QGVAR(eyeShieldItem),""]) != ""};
                    if (_needs) then {_active pushBackUnique _patient;};
                };
            } forEach allUnits;
        };

        GVAR(activePatients) = _active;
    }, 1, []] call CBA_fnc_addPerFrameHandler;
};

["CBA_settingsInitialized", {
    if (!GVAR(enable)) exitWith {};

    // Dust/rotor-wash effects are local presentation events.
    if (hasInterface) then {
        [QACEGVAR(goggles,effect), LINKFUNC(handleDustInjury)] call CBA_fnc_addEventHandler;
    };

    // Explosion injury state must exist for every casualty, not only ACE_player.
    ["CAManBase", "explosion", LINKFUNC(handleExplosion)] call CBA_fnc_addClassEventHandler;
}] call CBA_fnc_addEventHandler;

[QACEGVAR(medical_treatment,fullHealLocalMod), LINKFUNC(fullHealLocal)] call CBA_fnc_addEventHandler;
[QACEGVAR(medical_gui,updateInjuryListPart), LINKFUNC(gui_updateInjuryListPart)] call CBA_fnc_addEventHandler;
