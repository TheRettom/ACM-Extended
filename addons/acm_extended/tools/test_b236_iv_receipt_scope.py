"""B236 real SQF reservation/scope/replay code. Inventory, objects and wire are mocks.

No test treats CBA routing or replicated client variables as sender authentication.
"""
import pytest
from test_b232_iv_finish import run, source

PREP = r'''
_row set [15,[true,false,false,false]];_patient setVariable ["ACME_IV_Marks",[_row]];
(missionNamespace getVariable "ACME_supplyReceipts") set ["stock1",+_receipt];
private _bind={[_medic,_patient,"ivhub:7:1","flush","first",7,130,_receipt] call ACME_fnc_ivSupplyBind};
private _begin={[_patient,_medic,"begin","ivhub:7:1","flush","first",7,130,_receipt] call ACME_fnc_ivFinishCommit};
private _finish={[_patient,_medic,"finish","ivhub:7:1","flush","first",7,130,[]] call ACME_fnc_ivFinishCommit};
'''

@pytest.mark.parametrize('change',[
 'private _token="second";',
 'private _uid="ivhub:7:2";',
 'private _ep=8;',
 'private _deadline=131;',
 'private _target=missionNamespace;',
 'private _provider=missionNamespace;',
 '_receipt set [0,_patient];',
 '_receipt set [2,_patient];',
])
def test_bound_receipt_cannot_cross_scope(change):
    run(PREP+r'''
[call _bind,"real reservation bound"] call _check;
private _token="first";private _uid="ivhub:7:1";private _ep=7;private _deadline=130;
private _target=_patient;private _provider=_medic;
'''+change+r'''
private _result=[_provider,_target,_uid,"flush",_token,_ep,_deadline,_receipt] call ACME_fnc_ivSupplyScopeCheck;
[_result!=1,"different scope admitted"] call _check;
[count (call _credits)==0,"no fluid credit"] call _check;
''')

@pytest.mark.parametrize('moment',['active','done','cancelled','expired_history'])
def test_audited_fresh_token_replay_is_closed(moment):
    body=PREP+r'''[call _bind,"bind"] call _check;call _begin;'''
    if moment in ('done','expired_history'):
        body+='_serverTime=108;call _finish;'
    elif moment=='cancelled':
        body+='[_patient,_medic,"cancel","ivhub:7:1","flush","first",7,130,[]] call ACME_fnc_ivFinishCommit;'
    if moment=='expired_history':
        body+='_serverTime=200;'
    body+=r'''
private _before=count (call _credits);
private _renewed=_serverTime+30;
[_patient,_medic,"begin","ivhub:7:1","flush","replay",7,_renewed,_receipt] call ACME_fnc_ivFinishCommit;
[!((call _lastReply) select 4),"reused reservation accepted"] call _check;
_serverTime=_serverTime+8;
[_patient,_medic,"finish","ivhub:7:1","flush","replay",7,_renewed,[]] call ACME_fnc_ivFinishCommit;
[count (call _credits)==_before,"replay produced fluid"] call _check;
'''
    run(body)

def test_missing_binding_waits_for_replication_without_reject_or_credit():
    run(PREP+r'''
call _begin;
[count _events==0,"premature rejection would refund valid stock"] call _check;
[(call _getRow select 16) isEqualTo [],"no unbound job"] call _check;
[call _bind,"binding arrives"] call _check;
call _begin;_serverTime=108;call _finish;
[count (call _credits)==1,"one credit after retry"] call _check;
''')

def test_same_token_retry_after_binding_retirement_is_still_idempotent():
    run(PREP+r'''
[call _bind,"bind"] call _check;call _begin;
[_medic,"first",_receipt] call ACME_fnc_ivSupplyRelease;
call _begin;_serverTime=108;call _finish;call _finish;
[count (call _credits)==1,"only one credit"] call _check;
[(call _getState) select 1,"flush completed"] call _check;
''')

@pytest.mark.parametrize('donor,vehicle',[('_medic','objNull'),('_patient','objNull'),('_patient','missionNamespace'),('_medic','missionNamespace')])
def test_legitimate_provider_patient_and_vehicle_provenance_preserved(donor,vehicle):
    run(PREP+f'''
_receipt set [0,{donor}];_receipt set [2,{vehicle}];
(missionNamespace getVariable "ACME_supplyReceipts") set ["stock1",+_receipt];
[call _bind,"supported donor rejected"] call _check;
call _begin;_serverTime=108;call _finish;
[count (call _credits)==1,"supported source lost"] call _check;
''')

@pytest.mark.parametrize('receipt',['[]','[objNull,"ACM_SalineFlush_10",objNull,""]','[objNull,"ACM_SalineFlush_10",objNull,5]',
 '[objNull,"ACM_Syringe_10",objNull,"stock1"]','[objNull,"ACM_SalineFlush_10",0,"stock1"]','[0,"ACM_SalineFlush_10",objNull,"stock1"]'])
def test_malformed_or_wrong_item_never_passes_owner_scope(receipt):
    run(PREP+f'''
private _r={receipt};
[([_medic,_patient,"ivhub:7:1","flush","first",7,130,_r] call ACME_fnc_ivSupplyScopeCheck)!=1,"bad receipt"] call _check;
''')

def test_origin_refuses_fabricated_or_already_settled_receipt():
    run(PREP+r'''
(missionNamespace getVariable "ACME_supplyReceipts") deleteAt "stock1";
[!(call _bind),"unreserved supply bound"] call _check;
''')

@pytest.mark.parametrize('change',['private _target=missionNamespace;','private _provider=missionNamespace;','private _token="second";'])
def test_origin_will_not_bind_same_live_reservation_twice(change):
    run(PREP+r'''
[call _bind,"first bind"] call _check;
private _target=_patient;private _provider=_medic;private _token="first";
'''+change+r'''
[!([_provider,_target,"ivhub:7:1","flush",_token,7,130,_receipt] call ACME_fnc_ivSupplyBind),"receipt rebound"] call _check;
''')

def test_cancel_before_begin_returns_no_fluid_and_does_not_start_on_late_replication():
    run(PREP+r'''
[_patient,_medic,"cancel","ivhub:7:1","flush","first",7,130,[]] call ACME_fnc_ivFinishCommit;
[call _bind,"late binding"] call _check;call _begin;_serverTime=108;call _finish;
[count (call _credits)==0 && {(call _getRow select 16) isEqualTo []},"late begin escaped tombstone"] call _check;
''')

def test_scope_follows_patient_owner_state_not_machine_local_receipt_cache():
    # Switching native locality is a mocked boundary. Carry replicated patient
    # and provider state while dropping origin-only reservation maps.
    run(PREP+r'''
[call _bind,"bind"] call _check;
missionNamespace setVariable ["ACME_supplyReceipts",createHashMap];
missionNamespace setVariable ["ACME_IV_SupplyScopes",createHashMap];
call _begin;_serverTime=108;call _finish;call _finish;
[count (call _credits)==1,"new owner lost replicated binding"] call _check;
''')

def test_expired_unknown_supply_cannot_be_rebound_with_new_deadline():
    run(PREP+r'''
[call _bind,"bind"] call _check;_serverTime=200;
[!([_medic,_patient,"ivhub:7:1","flush","new",7,230,_receipt] call ACME_fnc_ivSupplyBind),"expired reservation revived"] call _check;
[!("stock1" in (missionNamespace getVariable "ACME_supplyReceipts")),"expired unknown result must not recreate stock"] call _check;
''')

@pytest.mark.parametrize('accepted',[False,True])
def test_actual_supply_settlement_cannot_duplicate_refund_or_rebind(accepted):
    code=source('treatmentSupplyRefund').replace('_vehicle addItemCargoGlobal [_item, 1];','_returns=_returns+1;')
    run(PREP+'ACME_fnc_treatmentSupplyRefund={'+code+r'''};
private _returns=0;ace_common_fnc_addToInventory={_returns=_returns+1;};
[call _bind,"bind"] call _check;
[_medic,"first",_receipt] call ACME_fnc_ivSupplyRelease;
'''+f'''
[_receipt,{str(not accepted).lower()}] call ACME_fnc_treatmentSupplyRefund;
[_receipt,{str(not accepted).lower()}] call ACME_fnc_treatmentSupplyRefund;
[_returns=={0 if accepted else 1},"single settlement"] call _check;
[!(call _bind),"settled receipt rebound"] call _check;
''')
