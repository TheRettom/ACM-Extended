/* Each click captures its exact site, epoch and request identity before leaving the UI. */
params [["_mode", "flush", [""]]];
private _p = missionNamespace getVariable ["ACM_circulation_TransfusionMenu_Target", objNull];
if (isNull _p) exitWith {};
private _part = missionNamespace getVariable ["ACM_circulation_TransfusionMenu_Selected_BodyPart", ""];
private _iv = missionNamespace getVariable ["ACM_circulation_TransfusionMenu_SelectIV", true];
private _site = missionNamespace getVariable ["ACM_circulation_TransfusionMenu_Selected_AccessSite", -1];
private _seq = (missionNamespace getVariable ["ACME_yServiceSequence", 0]) + 1;
missionNamespace setVariable ["ACME_yServiceSequence", _seq];
private _id = format ["ys:%1:%2:%3", clientOwner, netId ACE_player, _seq];
[_p, "yFlush", [_p, ACE_player, _part, _iv, _site, [_p] call ACME_fnc_clinicalEpoch, _mode, _id, serverTime]] call ACME_fnc_ownerDispatch;
