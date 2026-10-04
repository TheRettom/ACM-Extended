/* Pure dependency graph. Array length four is retained for legacy assemblies. */
params ["_state","_action"];
private _next=+_state;
private _lock=_next param [4,false];
switch (_action) do {
    case "lock": {_next=[false,false,false,false,true,0];};
    case "field14": {_next=[false,false,false,false,true,14];};
    case "field16": {_next=[false,false,false,false,true,16];};
    case "removeLock": {_next=[false,false,false,false];};
    case "removeSecondary": {_next=[false,false,false,false,true,0];};
    case "removeExtension": {
        if (_lock) then {_next set [0,false];_next set [1,false];_next set [3,false];}
        else {_next=[false,false,false,false];};
    };
    case "removeDressing": {_next set [2,false];};
    case "removeLine": {_next set [3,false];};
    case "extension": {_next set [0,true];if (_lock) then {_next set [1,false];};};
    case "dressing": {_next set [2,true];};
    case "line": {_next set [3,true];};
};
_next
