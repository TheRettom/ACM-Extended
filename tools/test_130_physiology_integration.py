from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def assert_has(path: str, *needles: str) -> str:
    text = read(path)
    for needle in needles:
        assert needle in text, f"{path}: missing {needle!r}"
    return text

def assert_not(path: str, *needles: str) -> str:
    text = read(path)
    for needle in needles:
        assert needle not in text, f"{path}: unexpected {needle!r}"
    return text


def test_130_dev_identity():
    v = read("addons/main/script_version.hpp")
    assert "#define MAJOR 1" in v
    assert "#define MINOR 3" in v
    assert "#define PATCH 0" in v

    cfg = read("addons/acm_extended/config.cpp")
    assert 'name = "ACM Extended [DEV Branch]";' in cfg
    assert 'dir = "@ACM Extended [DEV Branch]";' in cfg
    assert 'version = "1.3.0";' in cfg

    boot = read("addons/acm_extended/functions/fn_initForkStartupRuntime.sqf")
    assert 'ACME_buildBatch = "DEV-130-PHYS1";' in boot
    assert 'ACME_networkAuditRevision = "NA3-1.3.0-dev";' in boot


def test_new_physiology_has_no_per_patient_pfh_creator():
    for path in [
        "addons/infection/functions/fnc_handleInfectionPFH.sqf",
        "addons/infection/functions/fnc_handleSepsisPFH.sqf",
        "addons/burns/functions/fnc_tickPatient.sqf",
        "addons/ophthalmology/functions/fnc_structuralTick.sqf",
        "addons/ophthalmology/functions/fnc_treatmentAdvanced_eyeShield.sqf",
    ]:
        assert "CBA_fnc_addPerFrameHandler" not in read(path), path

    for path in [
        "addons/infection/XEH_postInit.sqf",
        "addons/burns/XEH_postInit.sqf",
        "addons/ophthalmology/XEH_postInit.sqf",
    ]:
        text = read(path)
        assert "activePatients" in text
        assert "lastDiscovery" in text
        assert "CBA_fnc_addPerFrameHandler" in text


def test_hardcore_new_physiology_is_centralized():
    settings = read("addons/acm_extended/XEH_preInit.sqf")
    for name in ["ACME_hc_burns", "ACME_hc_infection", "ACME_hc_ophthalmology"]:
        assert name in settings

    applied = read("addons/acm_extended/functions/fn_applyHardcore.sqf")
    for name in ["ACME_hcEff_burns", "ACME_hcEff_infection", "ACME_hcEff_ophthalmology"]:
        assert name in applied

    assert "hardcorePersistentBurns" not in read("addons/burns/XEH_preInit.sqf")
    assert "hardcoreSepsisSequelae" not in read("addons/infection/XEH_preInit.sqf")
    assert "hardcorePersistentOcular" not in read("addons/ophthalmology/initSettings.inc.sqf")


def test_new_burn_classes_do_not_enter_penetrating_fatal_trauma_logic():
    wounds = read("addons/core/overrides/fnc_woundsHandlerBase.sqf")
    assert '["ThermalBurn","ChemicalBurn","Burn1","Burn2","Burn3"]' in wounds


def test_burns_do_not_fake_hemorrhage_or_own_cbrn_state():
    xeh = read("addons/burns/XEH_postInit.sqf")
    assert "Blood_Volume" not in xeh
    assert "EffectiveVolumeDeficitL" not in xeh  # derived by tick, not direct wound mutation
    assert "BurnSurface" in xeh and "BurnBurden" in xeh
    assert "bandageLocal" in xeh and "BURN_WRONG_DRESSING_PAIN" in xeh

    reset = read("addons/burns/functions/fnc_resetVariables.sqf")
    assert "ACM_CBRN_AirwayInflammation" not in reset

    tick = read("addons/burns/functions/fnc_tickPatient.sqf")
    assert 'ACME_hcEff_burns' in tick
    assert "EffectiveVolumeDeficitL" in tick
    assert "HeatLossDrive" in tick
    assert "InfectionRiskMult" in tick
    assert "_hardcore" in tick and "PermanentInjury" in tick


def test_burn_and_sepsis_flow_through_authoritative_acme_endpoints():
    hr = read("addons/core/overrides/fnc_updateHeartRate.sqf")
    assert "ACM_infection_HR_Adjust" in hr
    assert "ACM_burns_HR_Adjust" in hr
    assert "ACME_laryngo_vagalUntil" in hr

    rr = read("addons/breathing/functions/fnc_updateRespirationRate.sqf")
    assert "ACM_infection_RR_Adjust" in rr

    svr = read("addons/core/overrides/fnc_updatePeripheralResistance.sqf")
    assert "ACM_infection_Resistance_Delta" in svr
    assert "ACM_burns_Resistance_Delta" in svr
    assert "ACME_laryngo_vagalUntil" in svr

    bp = read("addons/acm_extended/functions/fn_bpCompute.sqf")
    assert "ACM_burns_EffectiveVolumeDeficitL" in bp
    assert "ACM_infection_EffectiveVolumeDeficitL" in bp

    do2 = read("addons/acm_extended/functions/fn_oxygenDelivery.sqf")
    assert "ACM_burns_EffectiveVolumeDeficitL" in do2
    assert "ACM_infection_EffectiveVolumeDeficitL" in do2

    circ = read("addons/acm_extended/functions/fn_circHandle.sqf")
    assert "ACM_infection_Metabolic_Demand" in circ
    assert "do2Adequacy" in circ

    coag = read("addons/acm_extended/functions/fn_coagulationTick.sqf")
    assert "ACM_infection_Coag_Mult" in coag
    assert 'ACME_ca_coagBaseMult",_base' in coag
    assert 'ACME_ca_coagBaseMult",_pathologyBase' not in coag

    temp = read("addons/acm_extended/functions/fn_hypothermiaTick.sqf")
    assert "ACM_burns_HeatLossDrive" in temp
    assert "ACM_infection_feverWarmPerMin" in temp


def test_sepsis_is_field_reversible_unless_hardcore_latches_sequelae():
    inf = read("addons/infection/functions/fnc_handleInfectionPFH.sqf")
    assert 'missionNamespace getVariable ["ACME_hcEff_infection",false]' in inf
    assert "Sepsis_Permanent" in inf
    assert "hardcoreSepsisEvacMinutes" in inf
    assert "ACME_requiresEvac" in inf

    stage = read("addons/infection/functions/fnc_applyInfectionStage.sqf")
    assert "handleSepsisPFH" not in stage  # stage transitions do not spawn a worker


def test_burn_airway_is_source_separated_and_ett_beats_igel_for_edema():
    grade = read("addons/acm_extended/functions/fn_airwayHasFacialBurn.sqf")
    for wound in ["Burn1", "Burn2", "Burn3"]:
        assert wound in grade

    airway = read("addons/airway/functions/fnc_getAirwayState.sqf")
    assert "ACM_CBRN_AirwayInflammation" in airway
    assert "ACM_burns_AirwayInflammation" in airway
    ett_pos = airway.index('ACME_ETT_Inserted')
    inflammation_pos = airway.index('ACM_burns_AirwayInflammation')
    assert ett_pos < inflammation_pos, "ETT must bypass upper-airway burn edema"

    insert = read("addons/airway/functions/fnc_insertAirwayItem.sqf")
    assert "ACM_burns_AirwayInflammation" in insert
    assert '_type == "SGA"' in insert


def test_ett_has_explicit_better_aspiration_protection_than_igel():
    aspiration = read("addons/acm_extended/functions/fn_aspirationTick.sqf")
    assert "if (_ett && {_cuff}) then {_protection = 0.05;}" in aspiration
    assert 'if (_oral == "SGA") then {_protection = 0.25;};' in aspiration

    protect = read("addons/acm_extended/functions/fn_ettAirwayProtect.sqf")
    assert "not equivalent" in protect
    assert "stronger aspiration seal" in protect
    assert "ACME_ETT_Obstructing" in protect

    airway = read("addons/airway/functions/fnc_getAirwayState.sqf")
    assert "ACME_ETT_Obstructing" in airway


def test_adult_vagal_intubation_reflex_is_transient_and_uses_sole_writers():
    consequence = read("addons/acm_extended/functions/fn_laryngoConsequenceLocal.sqf")
    assert "ACME_laryngo_vagalSeverity" in consequence
    assert "ACME_laryngo_vagalUntil" in consequence
    assert "ACME_laryngo_vagalHypoxiaAddMax" in consequence
    assert "ace_medical_heartRate" not in consequence
    assert "ace_medical_peripheralResistance" not in consequence

    cfg = read("addons/acm_extended/functions/fn_initAirwayProcedureConfig.sqf")
    assert "ACME_laryngo_vagalPassChance" in cfg
    assert "ACME_laryngo_vagalManipChance" in cfg
    assert "adult" in cfg.lower()

    stimulus = read("addons/acm_extended/functions/fn_laryngoStimulusEffect.sqf")
    assert "ACME_laryngo_vagalUntil" in stimulus


def test_ocular_irritation_and_structural_trauma_are_separate():
    wash = read("addons/ophthalmology/functions/fnc_canWashEyes.sqf")
    assert "GET_DUST_INJURY" in wash
    assert "eyeInjuries" not in wash

    shield = read("addons/ophthalmology/functions/fnc_treatmentAdvanced_eyeShield.sqf")
    assert "CBA_fnc_addPerFrameHandler" not in shield
    assert "applyEyeShield" in shield

    structural = read("addons/ophthalmology/functions/fnc_structuralTick.sqf")
    assert 'ACME_hcEff_ophthalmology' in structural
    assert "structuralRecoveryMinutes" in structural
    assert "ACME_requiresEvac" in structural
    assert "private _permanent" in structural

    blast = read("addons/ophthalmology/functions/fnc_handleExplosion.sqf")
    assert "ACE_player) exitWith" not in blast
    assert "explosionSource" not in blast
    assert "eyeShieldIndex" in blast
    assert "_shieldProtection = 0.90" in blast


def test_new_durable_physiology_is_in_clinical_persistence():
    fields = read("addons/acm_extended/functions/fn_clinicalFields.sqf")
    for name in [
        "ACM_burns_BurnBurden",
        "ACM_burns_SystemicBurden",
        "ACM_burns_PermanentInjury",
        "ACM_infection_Infection_Stage",
        "ACM_infection_Sepsis_Permanent",
        "ACM_ophthalmology_eyeInjuries",
        "ACM_ophthalmology_ocularPermanent",
    ]:
        assert name in fields


def test_efak_remains_optional_and_not_bundled():
    assert not (ROOT / "addons/FAK-core").exists()
    assert not (ROOT / "addons/FAK-main").exists()
    inventory = read("addons/acm_extended/functions/fn_itemCount.sqf")
    assert "efak_medical_fnc_countItem" in inventory


def test_130_debug_overlay_exposes_integrated_physiology():
    debug = read("addons/acm_extended/functions/fn_debugMenuClinical.sqf")
    assert "1.3 PHYSIOLOGY" in debug
    for name in [
        "ACM_burns_BurnBurden",
        "ACM_infection_Sepsis_Severity",
        "ACM_infection_EffectiveVolumeDeficitL",
        "ACM_ophthalmology_eyeInjuries",
        "ACME_laryngo_vagalUntil",
    ]:
        assert name in debug
