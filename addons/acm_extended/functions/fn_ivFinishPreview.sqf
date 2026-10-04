/* Full-size instrument preview. Within the magnetic radius it uses exactly
   the installed accessory transform, including the socket and final port. */
params ["_ctrl","_tool","_cursor"];
if (isNull _ctrl || {count _cursor!=2}) exitWith {};
private _d=uiNamespace getVariable ["ACME_IV_DLG",displayNull];
private _buttons=(_d getVariable ["ACME_IV_FinishTray",[]]) apply {_x select 3};
{_buttons pushBack (_d displayCtrl _x);} forEach [86532,86537,86543,86547,86551,86559,86555];
private _overTray=(_buttons findIf {
    private _r=ctrlPosition _x;
    (ctrlShown _x) && {(_cursor select 0)>=(_r select 0)} && {(_cursor select 0)<=(_r select 0)+(_r select 2)}
        && {(_cursor select 1)>=(_r select 1)} && {(_cursor select 1)<=(_r select 1)+(_r select 3)}
})>=0;
if (_overTray) exitWith {_ctrl ctrlShow false;};
private _target=[_cursor select 0,_cursor select 1,_tool] call ACME_fnc_ivFinishTarget;
private _texture=format ["\acm_extended\ui\iv\finish\cursor_%1_ca.paa",_tool];
if ((ctrlText _ctrl)!=_texture) then {_ctrl ctrlSetText _texture;};
if (_target isNotEqualTo []) then {
    [_ctrl,_target select 0] call ACME_fnc_ivFinishPose;
} else {
    // Free tool keeps the catheter-scale canvas and its logical contact point.
    private _r=uiNamespace getVariable ["ACME_IV_BodyRect",[0,0,1,1]];
    private _h=(_r select 3)*(uiNamespace getVariable ["ACME_IV_CathScale",0.62]);
    private _w=_h*(pixelW/(pixelH max 1e-9));
    private _uv=if (_tool in ["flush","line"]) then {[1033.02/2048,1386.52/2048]} else {[1006.5/2048,1032/2048]};
    _ctrl ctrlSetAngle [0,_uv select 0,_uv select 1,false];
    _ctrl ctrlSetPosition [(_cursor select 0)-_w*(_uv select 0),(_cursor select 1)-_h*(_uv select 1),_w,_h];
    _ctrl ctrlCommit 0;_ctrl setVariable ["ACME_IV_FinishPose",[]];
};
_ctrl ctrlShow true;
