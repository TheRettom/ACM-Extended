/* Centralized local perception model. Debug variables and rendering stay client-local. */
ACME_visualFx_enabled = true;
ACME_visualFx_updateSec = 0.05;  // 20 Hz so HR-synchronous tunnel pulses remain legible even during tachycardia
ACME_visualFx_commitSec = 0.30;
ACME_visualFx_hypoxiaStart = 95;
ACME_visualFx_hypoxiaSevere = 72;
ACME_visualFx_mapStart = 70;
ACME_visualFx_mapSevere = 35;
ACME_visualFx_co2Start = 48;
ACME_visualFx_co2Severe = 85;
// Ketamine perception is tied to the same WEIGHT-NORMALIZED induction load used by ACME pharmacology.
// fn_ketamineOnBoard's IV calibration is 7 load units ~= 1.75 mg/kg IV, so the visual controller converts the
// current active load back to an IV-equivalent mg/kg before choosing a perceptual band. This makes a fixed mg dose
// produce less effect in a heavier casualty and more effect in a lighter casualty without maintaining a second PK model.
//
// Analgesic dosing should remain gameplay-clear. ACEP's common IV analgesic range is 0.1-0.3 mg/kg and acute-pain
// consensus guidance allows boluses through 0.35 mg/kg. ACME therefore uses 0.35 mg/kg as a SOFT upper analgesic
// grace band: no ketamine blur at any dose, no chromatic separation in the analgesic band, and only a very small
// WetDistortion cue near the upper end. The curve then rises progressively as exposure becomes dissociative.
ACME_visualFx_ketamineMgKgPerInduction = 1.75;
ACME_visualFx_ketamineAnalgesicMaxMgKg = 0.35;
ACME_visualFx_ketamineWetStartMgKg = 0.20;
ACME_visualFx_ketamineWetAnalgesicOut = 0.045;
ACME_visualFx_ketamineWetTransitionMgKg = 0.55;
ACME_visualFx_ketamineWetTransitionOut = 0.16;
ACME_visualFx_ketamineWetDissociativeMgKg = 1.00;
ACME_visualFx_ketamineWetDissociativeOut = 0.68;
ACME_visualFx_ketamineWetFullMgKg = 1.75;
ACME_visualFx_ketamineGeneralStartMgKg = 0.35;
ACME_visualFx_ketamineGeneralModerateMgKg = 0.75;
ACME_visualFx_ketamineGeneralModerateOut = 0.20;
ACME_visualFx_ketamineGeneralFullMgKg = 1.75;

// Analgesic/sub-dissociative water distortion is transient and slowly waxing/waning. Redosing refreshes the
// five-minute perception window. Pharmacology continues after the local perception window closes.
ACME_visualFx_ketamineAnalgesicWindowSec = 300;
ACME_visualFx_ketamineAnalgesicWaveSec = 34;
ACME_visualFx_ketamineWetRiseSec = 7.0;
ACME_visualFx_ketamineWetFallSec = 6.0;
ACME_visualFx_ketamineGeneralRiseSec = 8.5;
ACME_visualFx_ketamineGeneralFallSec = 7.0;
ACME_visualFx_tunnelStart = 0.50; // same severe-range onset used by the ACM-style radial tunnel profile

// Ketamine perceptual layering is intentionally dose-banded in fn_visualFxTick: sub-dissociative exposure favors
// mild blur/diplopia + subtle vividness and motion-lag; stronger depth/zoom and chromatic separation arrive later.
// ACME reproduces the magnitude of ACM's former ketamine chromatic pulse inside ONE PP handle. 0.86 comes close
// to the old stacked ACM+ACME look without actually running two competing ChromAberration effects.
ACME_visualFx_ketamineLegacyChromEquivalentScale = 1.00;

