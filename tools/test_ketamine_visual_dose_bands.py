from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CFG = (ROOT / "addons/acm_extended/functions/fn_initVisualEffectsConfig.sqf").read_text(encoding="utf-8")
VFX = (ROOT / "addons/acm_extended/functions/fn_visualFxTick.sqf").read_text(encoding="utf-8")
KET = (ROOT / "addons/acm_extended/functions/fn_ketamineOnBoard.sqf").read_text(encoding="utf-8")

# Ketamine perception must follow the same weight-normalized medication load used by pharmacology.
assert "IV calibration is retained (7 ~= 1.75 mg/kg)" in KET
assert "ACME_visualFx_ketamineMgKgPerInduction = 1.75;" in CFG
assert "ACME_visualFx_ketamineAnalgesicMaxMgKg = 0.35;" in CFG
assert "ACME_visualFx_ketamineWetStartMgKg = 0.20;" in CFG
assert "ACME_visualFx_ketamineWetAnalgesicOut = 0.045;" in CFG
assert "_ketDoseMgKg = _kNorm *" in VFX

# Analgesic ketamine may have only a very small water cue near the upper range.
assert 'missionNamespace getVariable ["ACME_visualFx_ketamineWetStartMgKg",0.20]' in VFX
assert 'missionNamespace getVariable ["ACME_visualFx_ketamineWetAnalgesicOut",0.045]' in VFX
assert 'missionNamespace getVariable ["ACME_visualFx_ketamineGeneralStartMgKg",0.35]' in VFX
assert "if (_ketDoseMgKg <= _generalStart) then" in VFX

# Ketamine must never own any blur-family effect. Shared DynamicBlur remains for real hypoxia/shock/CO2/syncope.
for token in [
    "private _ketMotion =",
    "private _ketZoom =",
    "_ketBlurReal",
    "_ketSharedBlur",
    "_dbgKetBlur",
    "_ketAnalgesicBlurEnvelope",
]:
    assert token not in VFX, token
assert 'private _blurV = ((_hyp*0.90)+(_low*0.80)+(_co2*0.70)+(_syn*1.00)) min 2.6;' in VFX
assert "Ketamine intentionally has no RadialBlur/zoom pass" in VFX

# Chromatic separation is also gated above the analgesic band so it cannot masquerade as smear at pain doses.
assert "_ketDoseMgKg > _chromStartMgKg" in VFX
assert "private _legacyDoseGate = linearConversion [_chromStartMgKg,0.90,_ketDoseMgKg,0,1,true];" in VFX

print("ketamine visual dose bands: PASS")
