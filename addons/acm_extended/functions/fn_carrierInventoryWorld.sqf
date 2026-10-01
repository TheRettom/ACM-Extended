/* Client-local standard world Inventory action. The real native cargo object is global and JIP-persistent.
   No custom inventory UI, and no wearable copy that can be taken away from the treatment lease. */
params ["_cargo"];
if (!hasInterface || {isNull _cargo}
    || {typeOf _cargo != "ACME_RemovedCarrierCargo"}
    || {(_cargo getVariable ["ACME_carrierWorldAction",-1]) >= 0}) exitWith {false};
private _id = _cargo addAction ["Plate carrier inventory", {
    params ["_cargo","_caller"];
    [_caller,_cargo getVariable ["ACME_carrierPatient",objNull],_cargo] call ACME_fnc_carrierInventoryOpen;
},nil,1.5,true,true,"", "alive _this && {!(_this getVariable ['ACE_isUnconscious',false])} && {!(_target getVariable ['ACME_carrierClosing',false])}",2.5,false];
_cargo setVariable ["ACME_carrierWorldAction",_id,false];
true
