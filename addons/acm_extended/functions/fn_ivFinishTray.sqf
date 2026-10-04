/* Second tool column keeps the established catheter tray size and every button
   on screen. Equipment bundled with the catheter has no invented stock item. */
params ["_d","_left","_y","_w","_h","_labelH","_step"];
private _tools=[["extension","EXTENSION"],["flush","10 mL FLUSH"],["dressing","TEGADERM"],["line","IV TUBING"]];
private _ctrls=[];
{
    _x params ["_tool","_label"];
    private _top=_y+_step*_forEachIndex;
    private _bg=_d ctrlCreate ["RscText",-1];_bg ctrlSetBackgroundColor [0.10,0.13,0.17,0.92];
    _bg ctrlSetPosition [_left,_top,_w,_h];_bg ctrlCommit 0;_bg ctrlEnable false;
    private _pic=_d ctrlCreate ["RscPictureKeepAspect",-1];
    _pic ctrlSetText format ["\acm_extended\ui\iv\finish\icon_%1_ca.paa",_tool];
    _pic ctrlSetPosition [(_left)+_w*0.08,_top+_h*0.08,_w*0.84,_h*0.84];_pic ctrlCommit 0;_pic ctrlEnable false;
    private _text=_d ctrlCreate ["ACME_IV_ToolLabel",-1];_text ctrlSetText _label;
    _text ctrlSetPosition [_left,_top+_h,_w,_labelH];_text ctrlSetFontHeight (_labelH*0.75);_text ctrlCommit 0;_text ctrlEnable false;
    private _click=_d ctrlCreate ["ACME_IV_ToolButton",-1];_click ctrlSetText "";
    _click ctrlSetPosition [_left,_top,_w,_h];_click ctrlSetBackgroundColor [0,0,0,0];_click ctrlCommit 0;
    _click ctrlSetTooltip (switch (_tool) do {
        case "extension": {"Connect the extension to a seated catheter hub."};
        case "flush": {"Connect, aspirate and flush. A missed line gives no blood return."};
        case "dressing": {"Secure the hub and proximal extension after checking the line."};
        default {"Connect IV tubing to the extension. Hang the bag in Transfuse Fluids."};
    });
    _click setVariable ["ACME_IV_Tool",_tool];
    _click ctrlAddEventHandler ["ButtonClick",{[(_this select 0) getVariable ["ACME_IV_Tool",""]] call ACME_fnc_ivFinishGrab;}];
    _ctrls pushBack [_tool,_pic,_text,_click];
} forEach _tools;
_d setVariable ["ACME_IV_FinishTray",_ctrls];
