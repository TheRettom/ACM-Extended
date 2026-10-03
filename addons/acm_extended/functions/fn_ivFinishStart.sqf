/* Select a real seated hub, never a global 'last puncture' outcome. */
params ["_fx","_fy"];
private _d=uiNamespace getVariable ["ACME_IV_DLG",displayNull];
private _medic=uiNamespace getVariable ["ACME_IV_Medic",objNull];
private _patient=uiNamespace getVariable ["ACME_IV_Patient",objNull];
if (isNull _d || {isNull _medic} || {!local _medic} || {!([] call ACME_fnc_ivUiValid)}) exitWith {false};
if ((_medic getVariable ["ACME_IV_FinishPending",[]]) isNotEqualTo []) exitWith {true};
private _action=uiNamespace getVariable ["ACME_IV_Held","none"];
if !(_action in ["extension","flush","dressing","line"]) exitWith {false};
private _bp=uiNamespace getVariable ["ACME_IV_BodyPart",""];
private _view=uiNamespace getVariable ["ACME_IV_View",""];
private _aspect=uiNamespace getVariable ["ACME_IV_AspectFix",0.5625];
private _best=[];private _distance=0.07;
{
    if ((_x param [4,""])=="hub" && {(_x select 0)==_bp} && {(_x select 1)==_view}) then {
        // The same hub hit area remains selectable while the extension's distal port
        // can also be clicked; use the rendered accessory transform for that point.
        private _points=[[_x select 2,_x select 3]];
        private _axis=(uiNamespace getVariable ["ACME_IV_FrameAxis",createHashMap]) getOrDefault [_x param [6,""],[0,-1]];
        private _a=((_axis select 0) atan2 (-(_axis select 1)))+(_x param [13,0]);
        private _scale=uiNamespace getVariable ["ACME_IV_CathScale",0.62];
        private _dx=(1033.02-1006.5)/2048*_scale;
        private _dy=(1386.52-910)/2048*_scale;
        private _rect=uiNamespace getVariable ["ACME_IV_BodyRect",[0,0,1,1]];
        private _xRatio=(_rect select 3)*(pixelW/(pixelH max 1e-9))/((_rect select 2) max 1e-9);
        _points pushBack [(_x select 2)+(_dx*cos _a-_dy*sin _a)*_xRatio,(_x select 3)+_dx*sin _a+_dy*cos _a];
        private _row=+_x;
        {
            private _du=_fx-(_x select 0);private _dv=(_fy-(_x select 1))/_aspect;
            private _dist=sqrt (_du*_du+_dv*_dv);
            if (_dist<_distance) then {_distance=_dist;_best=_row;};
        } forEach _points;
    };
} forEach (_patient getVariable ["ACME_IV_Marks",[]]);
if (_best isEqualTo []) exitWith {false};
private _uid=_best param [14,""];
if (_uid=="") exitWith {["Reopen the IV view to load this catheter.",2,_medic] call ace_common_fnc_displayTextStructured;true};
private _plan=[_best param [15,[false,false,false,false]],_action,true] call ACME_fnc_ivFinishPlan;
if !(_plan select 0) exitWith {[_plan select 1,2,_medic] call ace_common_fnc_displayTextStructured;true};
private _receipt=[];
if (_action=="flush") then {_receipt=[_medic,_patient,["ACM_SalineFlush_10"]] call ACME_fnc_treatmentSupplyTake;};
if (_action=="flush" && {_receipt isEqualTo []}) exitWith {["A 10 mL saline flush is required.",2,_medic] call ace_common_fnc_displayTextStructured;true};
private _serial=(_medic getVariable ["ACME_IV_FinishSerial",0])+1;
_medic setVariable ["ACME_IV_FinishSerial",_serial];
private _token=format ["ivfinish:%1:%2:%3",clientOwner,netId _medic,_serial];
private _epoch=[_patient] call ACME_fnc_clinicalEpoch;
private _deadline=serverTime+30;
private _context=[_d,+(uiNamespace getVariable ["ACME_IV_Session",[]]),_d getVariable ["ACME_IV_ViewGeneration",0],_bp,_view];
private _pending=[_patient,_token,_uid,_action,_epoch,_deadline,_receipt,_context,false];
_medic setVariable ["ACME_IV_FinishPending",_pending];
_d setVariable ["ACME_IV_FinishBusy",true];
uiNamespace setVariable ["ACME_IV_Held","none"];
uiNamespace setVariable ["ACME_IV_Dragging",false];
(uiNamespace getVariable ["ACME_IV_HeldCursorCtrl",controlNull]) ctrlShow false;
[_patient,"ivFinish",[_medic,"begin",_uid,_action,_token,_epoch,_deadline,_receipt]] call ACME_fnc_ownerDispatch;
[{_this call ACME_fnc_ivFinishRetry;},[_medic,_token],1] call CBA_fnc_waitAndExecute;
playSound "ACE_Sound_Click";
true
