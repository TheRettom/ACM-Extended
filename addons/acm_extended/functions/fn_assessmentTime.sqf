/* Native action time, including the complete final airway RTM at the shared 1.5x rate.
 * CfgMoves speed is negative duration or positive cycles/second. Read the installed game's
 * inherited config instead of guessing an RTM length from ACE's approximate treatment table.
 * Returns zero (native treatment refuses to start) for an unavailable/invalid airway state.
 */
params [["_classname", "CheckAirway", [""]]];
if ((toLowerANSI _classname) == "checkbreathing") exitWith {2};
private _speed = getNumber (configFile >> "CfgMovesMaleSdr" >> "States" >> "AinvPknlMstpSnonWnonDr_medic4" >> "speed");
if (!finite _speed || {_speed == 0}) exitWith {
    diag_log "[ACME ASSESSMENT] Check Airway requires a configured Dr_medic4 duration; refusing an unknown timer.";
    0
};
private _duration = if (_speed < 0) then {-_speed} else {1 / _speed};
// B213: allow the initial airway inspection another 0.25 real seconds at 1.5x.
// Keep the native source cutoff aligned with assessmentTick and assessmentAdvance.
ceil ((1.75 + _duration) / 1.5)
