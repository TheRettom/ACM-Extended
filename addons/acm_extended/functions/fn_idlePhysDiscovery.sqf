/* B245: one bounded discovery pass for idle-capable physiology.
 * Active registries run at their original clinical cadence; this 0.5 Hz pass is
 * only a missed-transition/locality safety net. Healthy units are read-only and
 * never published from here.
 */
private _now = CBA_missionTime;
private _preox = [];
private _aspiration = [];
private _shock = [];
{
    private _u = _x;
    if (isNull _u || {!local _u} || {!alive _u}) then {continue};

    // Preoxygenation: displaced reserve, active respiratory support, or a state
    // capable of consuming/limiting reserve.
    private _reserve = (_u getVariable ["ACME_preox_reserve",0.30]) max 0 min 1;
    private _rr = _u getVariable ["ACME_resp_neuralRR", (_u getVariable ["ACM_breathing_RespirationRate",16])];
    private _support = alive (_u getVariable ["ACM_breathing_BVM_Medic",objNull])
        || {_u getVariable ["ACME_vent_onPatient",false]}
        || {_u getVariable ["ACME_nrb_on",false]};
    private _preoxPhys = (_rr <= 2)
        || {_u getVariable ["ACE_isUnconscious",false]}
        || {_u getVariable ["ace_medical_inCardiacArrest",false]}
        || {(_u getVariable ["ace_medical_spo2",97]) < 94}
        || {(_u getVariable ["ACME_blastLung_State",0]) > 0}
        || {(_u getVariable ["ACME_aspiration_load",0]) > 0.001}
        || {(_u getVariable ["ACME_alt_pRatio",1]) < 0.999};
    if (abs (_reserve - 0.30) > 0.001 || {_support} || {_preoxPhys}) then {
        _preox pushBack _u;
    };

    // Aspiration: a fresh emesis edge, retained lung burden, or one final
    // replicated/local drive that still needs neutralization.
    private _load = (_u getVariable ["ACME_aspiration_load",0]) max 0;
    private _edema = (_u getVariable ["ACME_aspiration_edema",0]) max 0;
    private _event = _u getVariable ["ACME_laryngo_emesis", []];
    private _vomitState = _u getVariable ["ACM_airway_AirwayObstructionVomit_State",0];
    private _eventKey = if (_event isEqualType [] && {count _event >= 3}) then {
        format ["%1:%2:%3:%4", _event param [0,""], _event param [1,0], _event param [2,0], _vomitState]
    } else {
        format ["native:%1",_vomitState]
    };
    private _freshAspiration = (_eventKey != (_u getVariable ["ACME_aspiration_lastEmesisKey",""]))
        && {_vomitState > 0 || {count _event >= 3}};
    private _aspResidue = (_u getVariable ["ACME_aspiration_injury",0]) > 0.0005
        || {(_u getVariable ["ACME_aspiration_SpO2Penalty",0]) > 0.001}
        || {abs (_u getVariable ["ACME_aspiration_RRDrive",0]) > 0.001}
        || {(_u getVariable ["ACME_aspiration_shunt",0]) > 0.0001}
        || {_u getVariable ["ACME_aspiration_edemaActive",false]}
        || {abs (_u getVariable ["ACME_aspiration_lastRRAdj",0]) > 0.001};
    if (_freshAspiration || {_load > 0.0005} || {_edema > 0.0005} || {_aspResidue}) then {
        _aspiration pushBack _u;
    };

    // Shock: forced phenotype, hemodynamic/chest trigger, hypovolemia, or a
    // prior drive that needs one neutralization pass.
    private _priorShock = (toLowerANSI (_u getVariable ["ACME_shock_phenotype","none"])) != "none"
        || {abs (_u getVariable ["ACME_shock_severity",0]) > 0.001}
        || {abs (_u getVariable ["ACME_shock_resistDelta",0]) > 0.01}
        || {abs (_u getVariable ["ACME_shock_hrAdj",0]) > 0.01}
        || {_u getVariable ["ACME_shock_warm",false]}
        || {_u getVariable ["ACME_shock_ownsCirc",false]};
    private _forced = _u getVariable ["ACME_shock_forced", []];
    private _forcedLive = _forced isEqualType [] && {count _forced >= 2}
        && {(_forced param [2,-1]) < 0 || {_now <= (_forced param [2,-1])}};
    private _circ = _u getVariable ["ACME_circ_State", createHashMap];
    private _circShock = _circ isEqualType createHashMap && {_circ getOrDefault ["shockActive",false]};
    if (_priorShock || {_forcedLive}
        || {_u getVariable ["ACM_breathing_TensionPneumothorax_State", false]}
        || {(_u getVariable ["ACM_breathing_Hemothorax_Fluid",0]) >= 0.75}
        || {_circShock}
        || {(_u getVariable ["ACM_circulation_Blood_Volume",6]) < 5.1}) then {
        _shock pushBack _u;
    };
} forEach (missionNamespace getVariable ["ACME_clinical_ownedUnits", []]);

ACME_preox_activePatients = _preox;
ACME_aspiration_activePatients = _aspiration;
ACME_shock_activePatients = _shock;
