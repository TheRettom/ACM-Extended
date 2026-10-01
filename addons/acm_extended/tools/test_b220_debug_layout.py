"""B220 executes production debug formatting/fitting; native font metrics are explicit fixtures.

These checks are not Arma rendering tests. The integration cases include the real
column-major medication builder AND its consumer, including an odd final row.
"""
import json

import pytest

from test_debug_single_overlay import definition
from test_menu_death_lifecycle import adapt, execute, read


def helpers(*names):
    return ''.join(definition(name) for name in names)


FORMATTING = ('_safe', '_padRight', '_alignValue', '_pair', '_one', '_wrapValue', '_formatRow', '_sect')


@pytest.mark.parametrize('count', [0, 1, 2, 3, 4, 8, 15, 29, 30, 31, 32, 63])
def test_complete_medication_pipeline_has_no_missing_second_field_or_ghost_colon(count):
    rows = [[f'Med {n:02}', f'{n}.00', 'color'] for n in reversed(range(count))]
    source = read('debugMenuClinical')
    consumer = source[source.index('_right pushBack (["MEDICATIONS"]'):source.index('// Nondrug sedation')]
    execute('private _cLabel="label";private _cSect="gold";private _cMute="muted";' + helpers(*FORMATTING) +
        'ACME_fnc_debugMedicationColumns={' + adapt(read('debugMedicationColumns')) + '};' +
        f'private _medicationRows={json.dumps(rows)};private _right=[];' + consumer + f'''
        private _data=_right select {{_x isEqualType []}};
        [count _data=={(count+1)//2},"medication integration lost or duplicated a row"] call _check;
        private _leftNames=[];private _rightNames=[];
        {{
            private _row=_x;
            [count _row in [3,6],"malformed medication row"] call _check;
            _leftNames pushBack (_row select 0);
            if (count _row==6) then {{_rightNames pushBack (_row select 3);}};
            private _text=[_row,11,[18,18]] call _formatRow;
            [(_text find "<br/>")==-1,"ordinary medication acquired an explicit blank line"] call _check;
            private _firstColon=_text find " :</t>";
            private _rest=_text select [_firstColon+6];
            if (count _row==3) then {{[(_rest find " :</t>")==-1,"singleton printed a ghost right-hand colon"] call _check;}};
        }} forEach _data;
        [_leftNames+_rightNames isEqualTo {json.dumps(sorted(row[0] for row in rows))},"rendered order is not down-left then down-right"] call _check;
    ''')


@pytest.mark.parametrize('name,value', [
    ('Adenosine', '0.00'), ('Calcium Gluconate', '0.00'), ('Fentanyl', '1.75'),
    ('Norepinephrine', '0.00'), ('TXA', '0.00'), ('HR', '77'),
    ('Auto', '1.00 / 0.00'), ('Ext', '1067 mL/min'),
])
def test_grid_padding_is_nonbreaking_and_last_value_has_no_trailing_padding(name, value):
    execute('private _cLabel="label";' + helpers(*FORMATTING) + f'''
        private _pad=["{name}",20] call _padRight;
        private _tail=_pad select [count "{name}"];
        [count _pad==20,"padding altered column width"] call _check;
        // SQF-VM exposes extended characters as signed bytes (-96 for 160).
        // Compare the exact character produced by the native character boundary.
        private _nbsp=(toArray (toString [160])) select 0;
        [{{_x!=_nbsp}} count toArray _tail==0,"padding contains breakable spaces"] call _check;
        private _row=[["{name}","{value}","good","TXA","0.00","good"],11,[20,20]] call _formatRow;
        [(_row select [(count _row)-8])=="0.00</t>","right-hand reading carries invisible trailing padding"] call _check;
        private _single=[["{name}","{value}","good"],11,[20,20]] call _formatRow;
        [(_single select [(count _single)-(count "{value}</t>")])=="{value}</t>","single reading carries invisible trailing padding"] call _check;
    ''')


def fit_setup(body_lines=99, available=1.0, width=0.4, metric_scale=1.0):
    """Insets/line spacing intentionally are not exactly proportional to font size."""
    return '''
        private _cLabel="label";private _cMute="mute";private _cSect="gold";
        private _valueW=11;private _baseFontH=0.0092;private _fontH=_baseFontH;
        private _gapFactor=0.26;private _gap=0;private _y=-0.16;
        private _ctrlH="header";private _ctrlL="body";private _last=[];private _measurements=[];
        private _applyFont={};private _renderBlock={};
    ''' + f'''
        private _panelBottom=_y+{available};private _totalW={width};
        private _metricScale={metric_scale};private _bodyLines={body_lines};
        private _measureNaturalWidth={{62*_fontH*0.53*_metricScale+0.008}};
        private _measureRows={{
            params ["_rows","_width"];
            private _lines=[_bodyLines,4] select ((_rows select 0)=="TITLE");
            private _h=_lines*_fontH*1.07*_metricScale+0.006;
            // An inset/rounding boundary may create additional wraps at the tight final width.
            if (_width<0.30) then {{_h=_h+8*_fontH*_metricScale;}};
            _measurements pushBack [_width,_fontH,_h];_h
        }};
        private _layout={{_last=[_totalW,_fontH,+_this];}};
    ''' + helpers(*FORMATTING, '_renderAll') + '''
        private _header=["TITLE"];private _top=[];private _network=[];private _left=[];
        private _right=[["MEDICATIONS"] call _sect,["Adenosine","0.00","good","TXA","0.00","good"] call _pair];
    '''


@pytest.mark.parametrize('width,height', [(1280,720),(1680,1050),(1920,1080),(2560,1440),(3440,1440),(3840,2160),(5120,1440)])
@pytest.mark.parametrize('scale', [0.7,1.0,1.35])
def test_fit_remeasures_at_drawn_width_and_retains_complete_footer_across_metric_fixtures(width,height,scale):
    ceiling=min(.40, width/height*.245)
    execute(fit_setup(99, .992, ceiling, scale) + '''
        call _renderAll;
        private _measuredHeader=_measurements select ((count _measurements)-2);
        private _measuredBody=_measurements select ((count _measurements)-1);
        [count _measurements<=16,"unbounded fit loop"] call _check;
        { [abs ((_x select 0)-(_last select 0))<0.000001,"height measured at a different width from the drawn control"] call _check;
          [abs ((_x select 1)-(_last select 1))<0.000001,"font changed after the last height measurement"] call _check;
        } forEach [_measuredHeader,_measuredBody];
        private _needed=_fontH*0.75+_gap+(_measuredHeader select 2)+(_measuredBody select 2);
        [_needed<=(_panelBottom-_y),"footer still exceeds available screen height"] call _check;
        [_totalW<=0.40 && {_fontH<=_baseFontH},"overlay exceeded its original reference box"] call _check;
    ''')


@pytest.mark.parametrize('lines', [30, 110, 160, 240])
def test_fit_remains_bounded_with_large_dynamic_sections(lines):
    execute(fit_setup(lines) + '''
        call _renderAll;
        private _heights=_last select 2;
        [_fontH*0.75+_gap+(_heights select 0)+(_heights select 1)<=1,"dynamic sections hide the footer"] call _check;
        [count _measurements<=16,"overflow spawned an unbounded loop"] call _check;
    ''')


def test_identical_explicit_attributes_and_final_font_are_used_for_measurement_and_drawing():
    source=definition('_renderBlock')
    assert "align='left'" in source and "valign='top'" in source
    assert 'ctrlSetStructuredText parseText format' in source
    assert source.index('ctrlSetStructuredText') < source.index('ctrlSetFontHeight _fontH')
    assert '[_ctrlM, _rows] call _renderBlock;' in definition('_measureRows')
    assert '[_ctrlM, _rows] call _renderBlock;' in definition('_measureNaturalWidth')
    assert '[_ctrlH, _headerRows] call _renderBlock;' in definition('_renderAll')
    assert '[_ctrlL, _bodyRows] call _renderBlock;' in definition('_renderAll')


def test_section_spacing_does_not_add_a_second_blank_row_before_sedation():
    source=read('debugMenuClinical')
    between=source[source.index('// Nondrug sedation'):source.index('// Cerebral seizure state')]
    assert 'pushBack ""' not in between
    assert '["SEDATION / AWARENESS"] call _sect' in between
