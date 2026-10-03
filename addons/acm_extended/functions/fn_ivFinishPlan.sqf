/* Pure procedural rules. No UI colors or random success roll can establish patency.
   Existing line/hub outcome stays authoritative; a missed placement is never repaired here. */
params ["_state", "_action", "_patent"];
_state params [["_extension",false],["_tested",false],["_dressed",false],["_line",false]];
switch (_action) do {
    case "extension": {if (_extension) then {[false,"The extension is already connected.","",0]} else {[true,"","extension_attach",0.8]}};
    case "flush": {
        if (!_extension) exitWith {[false,"Connect the extension first.","",0]};
        if (_line) exitWith {[false,"Tubing is already connected to this port.","",0]};
        [true,"",["resisted_no_return","blood_return_flush"] select _patent,[5.6,7.4] select _patent]
    };
    case "dressing": {
        if (!_extension || {!_tested}) exitWith {[false,"Check the line with the saline flush first.","",0]};
        if (!_patent) exitWith {[false,"Recheck the line with the saline flush.","",0]};
        if (_dressed) exitWith {[false,"The dressing is already applied.","",0]};
        [true,"","tegaderm_apply",1.2]
    };
    case "line": {
        if (!_extension || {!_tested} || {!_dressed}) exitWith {[false,"Check and secure the extension first.","",0]};
        if (!_patent) exitWith {[false,"Recheck the line with the saline flush.","",0]};
        if (_line) exitWith {[false,"The tubing is already connected.","",0]};
        [true,"","iv_line_attach",1]
    };
    default {[false,"Select an IV tool.","",0]};
}
