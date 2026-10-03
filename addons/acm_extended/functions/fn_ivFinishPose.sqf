/* All accessory frames share the supplied base angle and insertion pivot.
   Add the authored catheter angle to its existing live tilt. Preserve the
   original gauge-colored hub underneath; never rotate around canvas center. */
params ["_ctrl","_row"];
private _rect=uiNamespace getVariable ["ACME_IV_BodyRect",[]];
if (isNull _ctrl || {count _rect != 4}) exitWith {};
_rect params ["_x","_y","_w","_h"];
private _suffix=_row param [6,""];
private _axis=(uiNamespace getVariable ["ACME_IV_FrameAxis",createHashMap]) getOrDefault [_suffix,[0,-1]];
private _angle=((_axis select 0) atan2 (-(_axis select 1))) + (_row param [13,0]);
[_ctrl,_x+_w*(_row select 2),_y+_h*(_row select 3),"",_angle,
    uiNamespace getVariable ["ACME_IV_CathScale",0.62],[1006.5/2048,910/2048]] call ACME_fnc_ivCathPose;
