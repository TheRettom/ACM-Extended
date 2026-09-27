#include "..\script_component.hpp"
/*
 * Author: Blue
 * Handle AED vitals tracking
 *
 * Arguments:
 * 0: Medic <OBJECT>
 * 1: Patient <OBJECT>
 *
 * Return Value:
 * None
 *
 * Example:
 * [player, cursorTarget] call ACM_circulation_fnc_handleAED;
 *
 * Public: No
 */

params ["_medic", "_patient"];

if ((_patient getVariable [QGVAR(AED_PFH), -1]) != -1) exitWith {};

private _inVehicle = !(isNull (objectParent _medic));

_patient setVariable [QGVAR(AED_Provider), _patient, true];
_medic setVariable [QGVAR(AED_Target_Patient), _patient, true];
_medic setVariable [QGVAR(AED_Medic_InUse), false, true];

_patient setVariable [QGVAR(AED_StartTime), CBA_missionTime, true];
_patient setVariable [QGVAR(AED_UpdateStep), 1, true];
_patient setVariable [QGVAR(AED_MuteAlarm), true, true];
_patient setVariable [QGVAR(AED_InUse), false, true];

_patient setVariable [QGVAR(AED_EKGRhythm), -2, true];
_patient setVariable [QGVAR(AED_PORhythm), -2, true];
_patient setVariable [QGVAR(AED_CORhythm), -2, true];

private _initialTorsadesPulseless = (_patient getVariable ["ACME_rhythm_active",0]) == 102
    && {_patient getVariable ["ACME_rhythm_torsadesNonPerfusing",false]};
if ((_patient getVariable [QGVAR(Cardiac_RhythmState), ACM_Rhythm_Sinus] in [ACM_Rhythm_Asystole,ACM_Rhythm_VF,ACM_Rhythm_PVT,ACM_Rhythm_VT]) || {_initialTorsadesPulseless}) then {
    _patient setVariable [QGVAR(AED_Alarm_CardiacArrest_State), true];
    _patient setVariable [QGVAR(AED_Alarm_State), true];

    [{
        params ["_patient"];

        !([_patient] call FUNC(hasAED)) || (_patient getVariable [QGVAR(AED_InUse), false]);
    }, {}, [_patient], 5, {
        params ["_patient"];

        playSound3D [QPATHTO_R(sound\aed_pushanalyze.wav), _patient, false, getPosASL _patient, 15, 1, 15]; // 1.715s
    }] call CBA_fnc_waitUntilAndExecute;
} else {
    _patient setVariable [QGVAR(AED_Alarm_CardiacArrest_State), false];
    _patient setVariable [QGVAR(AED_Alarm_State), false];

    [{
        params ["_patient"];

        _patient setVariable [QGVAR(AED_MuteAlarm), false, true];
    }, [_patient], 5] call CBA_fnc_waitAndExecute;
};

private _PFH = [{
    params ["_args", "_idPFH"];
    _args params ["_patient", "_medic"];

    private _padsStatus = _patient getVariable [QGVAR(AED_Placement_Pads), false];
    private _pulseOximeterPlacement = _patient getVariable [QGVAR(AED_Placement_PulseOximeter), -1];
    private _pulseOximeterPlacementStatus = (_pulseOximeterPlacement != -1 && {HAS_TOURNIQUET_APPLIED_ON(_patient,_pulseOximeterPlacement)});
    private _pressureCuffPlacement = _patient getVariable [QGVAR(AED_Placement_PressureCuff), -1];
    private _capnographStatus = _patient getVariable [QGVAR(AED_Placement_Capnograph), false];

    if (!_padsStatus && _pulseOximeterPlacement == -1 && _pressureCuffPlacement == -1 && !_capnographStatus) exitWith {
        _patient setVariable [QGVAR(AED_Pads_Display), 0, true];
        _patient setVariable [QGVAR(AED_Pads_LastSync), -1];
        _patient setVariable [QGVAR(AED_PulseOximeter_Display), -1, true];
        _patient setVariable [QGVAR(AED_PulseOximeter_LastSync), -1];

        _patient setVariable [QGVAR(AED_Capnograph_LastSync), -1];
        _patient setVariable [QGVAR(AED_RR_Display), 0, true];
        _patient setVariable [QGVAR(AED_CO2_Display), 0, true];

        _patient setVariable [QGVAR(AED_PFH), -1];

        _medic setVariable [QGVAR(AED_Target_Patient), objNull, true];
        _patient setVariable [QGVAR(AED_Provider), objNull, true];

        _patient setVariable [QGVAR(AED_MuteAlarm), false, true];

        _patient setVariable [QGVAR(AED_Analyze_Busy), false, true];

        [_idPFH] call CBA_fnc_removePerFrameHandler;
    };

    if (_padsStatus) then {
        private _lastSync = _patient getVariable [QGVAR(AED_Pads_LastSync), -1];

        // The AED PFH can run every frame, but the electrical-rate cache is allowed to advance only on its own
        // one-second cadence.  Every consumer below reads that same cached value.
        private _ekgHR = [_patient] call FUNC(updateEKGHeartRate);
        private _rhythmState = _patient getVariable [QGVAR(Cardiac_RhythmState), ACM_Rhythm_Sinus];
        private _effectiveRhythm = [_patient] call ACME_fnc_rhythmGet;
        private _torsadesPulseless = _effectiveRhythm == 102
            && {_patient getVariable ["ACME_rhythm_torsadesNonPerfusing",false]};

        // Restore ACM's monitor sampling behavior: the large numeric HR updates once per monitor sample rather than
        // visually racing through every intermediate value while the physiologic HR is moving.
        if (_lastSync + 5.25 < CBA_missionTime) then {
            _patient setVariable [QGVAR(AED_Pads_LastSync), CBA_missionTime];
            _patient setVariable [QGVAR(AED_Pads_Display), round (_ekgHR max 0), true];
        };

        if ([_patient] call FUNC(AED_IsSilent)) then {
            _patient setVariable [QGVAR(AED_Alarm_CardiacArrest_State), false];
            _patient setVariable [QGVAR(AED_Alarm_State), false];
        };

        if (!(_patient getVariable [QGVAR(AED_InUse), false]) && !([_patient] call FUNC(AED_IsSilent)) && !([_patient] call EFUNC(core,cprActive))) then {
            if (_ekgHR > 0) then {
                private _lastBeep = _patient getVariable [QGVAR(AED_Pads_LastBeep), -1];
                private _nominalRR = 60 / _ekgHR;
                private _afibClock = _effectiveRhythm in [100, 103];
                // One selected R-R interval owns BOTH the next audible beat and the next rendered R wave. Keep that
                // interval fixed for the duration of a beat instead of recalculating the due time every frame from a
                // moving HR. That removes the characteristic "R wave chases the beep" acceleration artifact.
                private _clockRhythm = _patient getVariable ["ACME_AED_ClockRhythm", -999];
                private _hrDelay = _patient getVariable ["ACME_AED_NextRR", _nominalRR];
                if (_clockRhythm != _effectiveRhythm) then {
                    _patient setVariable ["ACME_AED_ClockRhythm", _effectiveRhythm, false];
                    _hrDelay = _nominalRR;
                    _patient setVariable ["ACME_AED_NextRR", _hrDelay, false];

                    // A rhythm change gets one clean clock handoff.  Preserve a recent organized beat so sinus -> VT
                    // and similar transitions do not invent an extra QRS; if the previous epoch is stale (for example
                    // VF -> PEA), begin a fresh organized cycle from now.
                    if (_lastBeep < 0 || {(CBA_missionTime - _lastBeep) > ((_nominalRR max 0.25) * 1.5)}) then {
                        _lastBeep = CBA_missionTime;
                        _patient setVariable [QGVAR(AED_Pads_LastBeep), _lastBeep];
                        _patient setVariable ["ACME_AED_PreviousRR", _hrDelay, false];
                    };
                };
                if (!(_hrDelay isEqualType 0) || {!finite _hrDelay} || {_hrDelay <= 0}) then {_hrDelay = _nominalRR;};

                if (!(_patient getVariable [QGVAR(AED_Alarm_State), false]) && {(_rhythmState in [ACM_Rhythm_VF,ACM_Rhythm_PVT]) || {_torsadesPulseless}}) then {
                    _patient setVariable [QGVAR(AED_Alarm_State), true];

                    [{
                        params ["_patient"];

                        private _torsadesPulselessNow = ([_patient] call ACME_fnc_rhythmGet) == 102
                            && {_patient getVariable ["ACME_rhythm_torsadesNonPerfusing",false]};
                        if (_torsadesPulselessNow || {!(_patient getVariable [QGVAR(Cardiac_RhythmState), ACM_Rhythm_Sinus] in [ACM_Rhythm_Sinus,ACM_Rhythm_PEA])}) then {
                            [_patient] call FUNC(AED_PlayAlarm);
                            _patient setVariable [QGVAR(AED_Alarm_CardiacArrest_State), true];
                        } else {
                            _patient setVariable [QGVAR(AED_Alarm_State), false];
                        };
                    }, [_patient], 2] call CBA_fnc_waitAndExecute;
                };

                if (_patient getVariable [QGVAR(AED_Alarm_CardiacArrest_State), false]) exitWith {
                    if (_rhythmState in [0,5] && {!_torsadesPulseless}) then {
                        _patient setVariable [QGVAR(AED_Alarm_CardiacArrest_State), false];
                        _patient setVariable [QGVAR(AED_Alarm_State), false];
                        playSound3D [QPATHTO_R(sound\aed_3beep.wav), _patient, false, getPosASL _patient, 15, 1, 15]; // 0.369s
                    };
                };

                if ((_lastBeep + _hrDelay) <= CBA_missionTime) then {
                    // One authoritative electrical beat event.  The waveform generator and the sound use the same
                    // scheduled epoch.  A normal render-frame delay therefore cannot accumulate into R-wave drift.
                    // If the client actually hitches for a large fraction of an R-R interval, resynchronize once
                    // instead of replaying/catching up several historical beats in rapid succession.
                    private _dueAt = _lastBeep + _hrDelay;
                    private _lateBy = (CBA_missionTime - _dueAt) max 0;
                    private _beatAt = if (_lateBy <= ((_hrDelay * 0.35) min 0.20)) then {_dueAt} else {CBA_missionTime};
                    _patient setVariable [QGVAR(AED_Pads_LastBeep), _beatAt];
                    _patient setVariable ["ACME_AED_PreviousRR", _hrDelay, false];
                    // Select the next interval exactly once at the beat. Regular rhythms adopt the latest physiologic
                    // HR here; AFib additionally applies an irregular-RR factor. The generator reads this same value.
                    private _nextRR = _nominalRR;
                    if (_afibClock) then {
                        private _factor = random [0.62, 0.94, 1.42];
                        if ((random 1) < 0.20) then {_factor = _factor + random [0.20, 0.38, 0.72];};
                        _nextRR = (_nominalRR * _factor) max 0.24;
                    };
                    _patient setVariable ["ACME_AED_NextRR", _nextRR, false];
                    _patient setVariable ["ACME_AED_LastRR", _hrDelay, false];
                    _patient setVariable ["ACME_AED_BeatSerial", (_patient getVariable ["ACME_AED_BeatSerial", 0]) + 1, false];

                    private _pitch = 1;
                    if (_pulseOximeterPlacement != -1) then { // Beep pitch affected by SpO2
                        _pitch = linearConversion [50, 90, ([_patient, true] call EFUNC(breathing,getSpO2)), 0.5, 1, true];
                    };

                    playSound3D [QPATHTO_R(sound\aed_hr_beep.wav), _patient, false, getPosASL _patient, 15, _pitch, 15]; // 0.15s
                };
            } else {
                if !(_patient getVariable [QGVAR(AED_Alarm_State), false]) then {
                    _patient setVariable [QGVAR(AED_Alarm_State), true];

                    [{
                        params ["_patient"];

                        private _torsadesPulselessNow = ([_patient] call ACME_fnc_rhythmGet) == 102
                            && {_patient getVariable ["ACME_rhythm_torsadesNonPerfusing",false]};
                        if (_torsadesPulselessNow || {!(_patient getVariable [QGVAR(Cardiac_RhythmState), ACM_Rhythm_Sinus] in [ACM_Rhythm_Sinus,ACM_Rhythm_PEA])}) then {
                            [_patient] call FUNC(AED_PlayAlarm);
                            _patient setVariable [QGVAR(AED_Alarm_CardiacArrest_State), true];
                        } else {
                            _patient setVariable [QGVAR(AED_Alarm_State), false];
                        };
                    }, [_patient], 2] call CBA_fnc_waitAndExecute;
                };
            };
        };
    };

    if (_pulseOximeterPlacement != -1) then {
        private _lastSync = _patient getVariable [QGVAR(AED_PulseOximeter_LastSync), -1];

        if (_lastSync + 3 < CBA_missionTime) then {
            _patient setVariable [QGVAR(AED_PulseOximeter_LastSync), CBA_missionTime];

            (GET_BLOOD_PRESSURE(_patient)) params ["", "_BPSystolic"];

            private _torsadesPulselessPO = ([_patient] call ACME_fnc_rhythmGet) == 102
                && {_patient getVariable ["ACME_rhythm_torsadesNonPerfusing",false]};
            if (!(HAS_TOURNIQUET_APPLIED_ON(_patient,_pulseOximeterPlacement)) && _BPSystolic >= 80 && HAS_PULSE_P(_patient) && {!_torsadesPulselessPO}) then {
                _patient setVariable [QGVAR(AED_PulseOximeter_Display), round([_patient] call EFUNC(breathing,getSpO2)), true];
                if !(_padsStatus) then {
                    _patient setVariable [QGVAR(AED_Pads_Display), round(GET_HEART_RATE(_patient)), true];
                };
            } else {
                _patient setVariable [QGVAR(AED_PulseOximeter_Display), 0, true];
                if !(_padsStatus) then {
                    _patient setVariable [QGVAR(AED_Pads_Display), 0, true];
                };
            };
        };
    };

    if (_capnographStatus) then {
        private _lastSync = _patient getVariable [QGVAR(AED_Capnograph_LastSync), -1];

        if (_lastSync + 4 < CBA_missionTime) then {
            _patient setVariable [QGVAR(AED_RR_Display), round(GET_RESPIRATION_RATE(_patient)), true];
            _patient setVariable [QGVAR(AED_CO2_Display), round([_patient] call EFUNC(breathing,getEtCO2)), true];
        };
    };
}, 0, [_patient, _medic]] call CBA_fnc_addPerFrameHandler;

_patient setVariable [QGVAR(AED_PFH), _PFH];

// AED leads follow the same clinical reach rule as the medical menu. Same-vehicle occupants remain connected
// regardless of model-origin spacing; treating a casualty through a vehicle doorway remains valid while within
// the configured AED leash.
[{
    params ["_patient", "_medic"];
    isNull _patient || {isNull _medic}
        || {!([_medic, _patient, GVAR(AEDDistanceLimit)] call ACME_fnc_patientInteractionReachable)}
}, {
    params ["_patient", "_medic"];

    if !(isNull _patient) then {
        [_medic, _patient, "body", 0, false, true] call FUNC(setAED);
        [_medic, _patient, "body", 1, false, true] call FUNC(setAED);
        [_medic, _patient, "body", 2, false, true] call FUNC(setAED);
        [_medic, _patient, "body", 3, false, true] call FUNC(setAED);
        [_patient, "activity", LLSTRING(AED_%1_Disconnected), [[_medic, false, true] call ACEFUNC(common,getName)]] call ACEFUNC(medical_treatment,addToLog);
        [QACEGVAR(common,displayTextStructured), [LLSTRING(AED_PatientDisconnected), 1.5, _medic], _medic] call CBA_fnc_targetEvent;
    };
}, [_patient, _medic], 3600] call CBA_fnc_waitUntilAndExecute;
