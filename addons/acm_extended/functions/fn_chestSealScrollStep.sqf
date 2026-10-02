/* B223: one corner, one direction, one completed burp per hover. No wrapping.
   Return [frame, locked direction, fired, newly completed]. Hover exit alone resets input state. */
params [["_frame", 0, [0]], ["_openDir", 0, [0]], ["_fired", false, [false]], ["_delta", 0, [0]]];
if (!finite _frame) then {_frame = 0;};
_frame = (floor _frame) max 0 min 5;
if (!finite _delta || {_delta == 0}) exitWith {[_frame, _openDir, _fired, false]};
private _direction = [1, -1] select (_delta < 0);
if (_openDir == 0) then {_openDir = _direction;};
if (_direction != _openDir || {_fired} || {_frame >= 5}) exitWith {[_frame, _openDir, _fired, false]};
_frame = (_frame + 1) min 5;
private _complete = _frame == 5;
[_frame, _openDir, _fired || _complete, _complete]
