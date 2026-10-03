/* Called inside the existing IV tick: no permanent new PFH, no whole-list
   rebuilding for an animation frame. Remote viewers read the owner job. */
private _d=uiNamespace getVariable ["ACME_IV_DLG",displayNull];
if (isNull _d) exitWith {};
private _patient=uiNamespace getVariable ["ACME_IV_Patient",objNull];
private _medic=uiNamespace getVariable ["ACME_IV_Medic",objNull];
private _active=+(_d getVariable ["ACME_IV_FinishActive",[]]);
private _marks=_patient getVariable ["ACME_IV_Marks",[]];
private _p=if (isNull _medic) then {[]} else {_medic getVariable ["ACME_IV_FinishPending",[]]};
if (count _active>=3 && {count _p>=9}) then {
    private _row=_active select 0;private _uid=_row param [14,""];
    private _i=_marks findIf {(_x param [14,""])==_uid && {(_x param [4,""])=="hub"}};
    if (_i<0 || {!((_p select 7) call ACME_fnc_ivMinigameViewValid)}
        || {([_medic,_patient] call ACME_fnc_patientInteractionDistance)>3}
        || {!alive _medic} || {_medic getVariable ["ACE_isUnconscious",false]}
        || {(objectParent _medic) isNotEqualTo (objectParent _patient)}
        || {((_row param [16,[]]) param [5,""])=="blood_return_flush" && {!([_patient,_row] call ACME_fnc_ivFinishPatency)}}) then {
        [] call ACME_fnc_ivFinishAbort;_active=[];
    } else {
        private _job=_row param [16,[]];
        if (count _job>=7 && {!(_active select 2)} && {diag_tickTime-(_active select 1)>=(_job select 4)}) then {
            _active set [2,true];_d setVariable ["ACME_IV_FinishActive",_active];
            [_patient,"ivFinish",[_medic,"finish",_p select 2,_p select 3,_p select 1,_p select 4,_p select 5]] call ACME_fnc_ownerDispatch;
        };
    };
};
{
    _x params ["_uid","_accessory","_dressing"];
    private _i=_marks findIf {(_x param [14,""])==_uid && {(_x param [4,""])=="hub"}};
    if (_i>=0) then {
        private _row=_marks select _i;
        private _job=_row param [16,[]];private _elapsed=if (count _job>=7) then {serverTime-(_job select 3)} else {0};
        if (count _active>=3 && {((_active select 0) param [14,""])==_uid}) then {
            _row=_active select 0;_job=_row param [16,[]];_elapsed=diag_tickTime-(_active select 1);
        };
        private _state=_row param [15,[false,false,false,false]];
        private _tex=if (_state select 3) then {"\acm_extended\ui\iv\finish\line_ca.paa"} else {
            if (_state select 0) then {"\acm_extended\ui\iv\finish\extension_ca.paa"} else {""}
        };
        private _film=if (_state select 2) then {"\acm_extended\ui\iv\finish\dressing_ca.paa"} else {""};
        if (count _job>=7 && {serverTime<=(_job select 6)}) then {
            private _frame=[_job select 5,_elapsed] call ACME_fnc_ivFinishFrame;
            if ((_job select 2)=="dressing") then {_film=_frame;} else {_tex=_frame;};
        };
        {
            _x params ["_ctrl","_texture"];
            if (!isNull _ctrl) then {
                if ((_ctrl getVariable ["ACME_IV_FinishTexture","-"])!=_texture) then {
                    _ctrl ctrlSetText _texture;_ctrl setVariable ["ACME_IV_FinishTexture",_texture];
                };
                [_ctrl,_row] call ACME_fnc_ivFinishPose;
                _ctrl ctrlShow (_texture!="");
            };
        } forEach [[_accessory,_tex],[_dressing,_film]];
    } else {_accessory ctrlShow false;_dressing ctrlShow false;};
} forEach (_d getVariable ["ACME_IV_FinishCtrls",[]]);
