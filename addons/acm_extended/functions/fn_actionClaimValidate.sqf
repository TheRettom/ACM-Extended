/* Shared patient-owner admission checks for DP/Hang Bag claims. Empty reason means valid.
 * Keep action-specific range, pose and setting policy in the caller. owner is server-only;
 * clients can validate the machine identity of a local provider with clientOwner.
 */
params [
    ["_patient",objNull,[objNull]], ["_medic",objNull,[objNull]],
    ["_epoch",-1,[0]], ["_providerOwner",-1,[0]],
    ["_sentAt",-1,[0]], ["_maxAge",5,[0]]
];
if (isNull _patient || {!local _patient}) exitWith {"patient-locality"};
if (isNull _medic || {!alive _medic} || {_medic getVariable ["ACE_isUnconscious",false]}) exitWith {"provider-unavailable"};
if (!finite _providerOwner || {_providerOwner <= 0} || {_providerOwner != floor _providerOwner}) exitWith {"provider-identity"};
if (if (isServer) then {_providerOwner != owner _medic} else {local _medic && {_providerOwner != clientOwner}}) exitWith {"provider-locality"};
if (!finite _epoch || {_epoch < 0} || {_epoch != ([_patient] call ACME_fnc_clinicalEpoch)}
    || {_patient getVariable ["ACME_clinicalRestoring",false]}) exitWith {"patient-epoch"};
if (!finite _sentAt || {_sentAt < 0} || {!finite _maxAge} || {_maxAge <= 0} || {_maxAge > 5}) exitWith {"request-time"};
private _age = serverTime - _sentAt;
if (_age < -0.5 || {_age > _maxAge}) exitWith {"request-expired"};
""
