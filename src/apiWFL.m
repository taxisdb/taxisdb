;; ================================================================================ 
;; ^apiWFL - ABox assertion workflow engine subroutines - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 		— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;;
;;============================================================================== 


AddKeyword(eid,val) ; register alias keyword into ^TBKW for an entity
;;------------------------------------------------------------------
;; Routine  : AddKeyword^apiWFL
;;
;; Call     : DO AddKeyword^apiWFL(eid,val)
;;
;; Purpose  : Registers an alias keyword into ^TBKW for a given entity.
;;
;; Parameters
;;   eid     : (IN) Entity ID of the assertion subject
;;   val     : (IN) Alias value to register as keyword (e.g. "%tomhanks")
;;
;;------------------------------------------------------------------
    NEW aliaskey    ; valkey of the entity's sys.attr.key (objkey), resolved below
    NEW objkey      ; human-readable object key, used as ^TBKW subscript
    NEW idx         ; next available ^TBKW(objkey,*) index    
    
    SET idx=""
    SET objkey=""

    ; Resolve the object key, Case 1 - A new entity with a freshly staged entity key    
    SET aliaskey=$ORDER(%ABR(eid,AKEYID,""))
    IF aliaskey'="" SET objkey=$GET(^TBD(AKEYID,aliaskey))

    ; Resolve the object key, Case 2 - Covers existing entity whose key is unchanged
    IF objkey="" DO
    . SET aliaskey=$$GetCurrentVK^apiGet(eid,AKEYID)
    . IF aliaskey'=-1,aliaskey'=0 SET objkey=$$GetDictValue^sapiGet(AKEYID,aliaskey) ; it is sapiGet

    IF objkey="" DO  QUIT
    . DO LOGERROR^logger("apiWFL","AddKeyword: could not resolve objkey for eid="_eid_", aliaskey="_aliaskey)

	;; Is alias a valid MUMPS variable name ?
    IF '$$IsAlphaNum^utils(val) DO  QUIT
    . DO LOGWARNING^logger("apiWFL","AddKeyword: alias rejected — not a valid identifier — "_val)

    ; Write keyword entry into ^TBKW at next available index subscript
    SET idx=$ORDER(^TBKW(objkey,""),-1)    ; last used index, "" if none
    SET idx=$SELECT(idx="":0,1:idx+1)
    SET ^TBKW(objkey,idx)=val
    DO LOGDEBUG^logger("apiWFL","AddKeyword: ^TBKW("""_objkey_""")="""_val_"""")
    QUIT


DatomStageMulti(eid,aid,val,op) ; stage a cardinality-many assert or retract for (eid,aid,val)
;;----------------------------------------------------------------------------------------------
;; Function  : DatomStageMulti^apiWFL
;;
;; Purpose   : Resolves val to a valkey. If newly allocated, it has no history in ^EATV, so
;;             assert creates it directly and retract fails directly — no scan needed. If the
;;             valkey already existed, walks ^EATV(eid,aid,*) from the most recent transaction
;;             backward until this valkey is found, and stages the requested polarity into %ABR
;;             based on its recorded state relative to the requested op.
;;
;;             Algorithm:
;;               1. Resolve val → valkey.
;;               2. NEW VALKEY (isNewValKey=1 — never existed before this call, no ^EATV history
;;                  is possible)
;;                    assert  → stage op=1                          CREATE
;;                    retract → fail, nothing to retract            FAIL
;;               3. EXISTING VALKEY (isNewValKey=0) — scan transactions for (eid,aid)
;;                  newest-to-oldest; stop at the first one where valkey is recorded — that op
;;                  IS the valkey's current state, since any more recent write would already
;;                  have been seen.
;;               4.   NOT FOUND (valkey has no recorded op in ^EATV despite being a known key)
;;                      assert  → stage op=1                        CREATE
;;                      retract → fail, nothing to retract          FAIL
;;               5.   FOUND, recorded op equals requested op
;;                      → no-op, nothing staged                     NO-OP
;;               6.   FOUND, recorded op differs from requested op
;;                      → stage requested op                        FLIP
;;
;; Parameters
;;   eid     : (IN) Entity ID
;;   aid     : (IN) Attribute ID — must be cardinality-many
;;   val     : (IN) Single value to assert/retract — must not contain "|"
;;   op      : (IN) 1 to assert, 0 to retract
;;
;; Returns
;;   1       : datom staged (CREATE or FLIP path)
;;   2       : no-op — recorded state already matches requested op
;;   0       : failed — value resolution failed, or valkey never recorded when retracting
;;
;; Scope
;;   Reads   : ^EATV
;;
;; Notes
;;   Branch 4 (existing valkey, not found in ^EATV) is kept defensively — pending confirmation
;;   of whether valkey registration can ever occur without a prior ^EATV write for it. If not,
;;   isNewValKey=0 always implies found=1 and branch 4 is unreachable.
;;----------------------------------------------------------------------------------------------
    NEW valkey       ; resolved value-type key for val
    NEW isNewValKey  ; resolution result — 1 new valkey allocated, 0 existing valkey reused, <0 resolution failure
    NEW curtx        ; tx cursor, walking ^EATV(eid,aid,*) from most recent transaction backward
    NEW found        ; 1 once valkey has been located at some transaction — stops the scan
    NEW recop        ; op recorded at the transaction where valkey was found; meaningful only if found=1

    SET valkey=""

    ; Resolve val into valkey. Reference-typed attributes resolve/register via ResolveAttrRef,
    ; everything else registers as a literal via RegisterAttrVal.
    IF $$IsRefValType^sapiVld(aid) DO
    . SET isNewValKey=$$ResolveAttrRef^sapiRslv(aid,val,.valkey,"ABox")
    ELSE  DO
    . SET isNewValKey=$$RegisterAttrVal^sapiRslv(aid,val,.valkey)

    ; Resolution failure (-1) must abort immediately — the resolver has already logged the cause.
    IF isNewValKey<0 DO  QUIT 0
    . DO LOGERROR^logger("apiWFL","DatomStageMulti: aborting — value resolution failed for (eid="_eid_",aid="_aid_",val="_val_")")

    ; New valkey, retract — never existed, nothing to retract, fail. No scan needed.
    IF isNewValKey&('op) DO  QUIT 0
    . DO LOGDEBUG^logger("apiWFL","DatomStageMulti: failed — ("_eid_","_aid_","_valkey_") is a new valkey, nothing to retract")

    ; New valkey, assert — create directly. No scan needed.
    IF isNewValKey&(op=1) DO  QUIT 1
    . SET %ABR(eid,aid,valkey)=1
    . DO LOGDEBUG^logger("apiWFL","DatomStageMulti: create staged ("_eid_","_aid_","_valkey_") — new valkey")

    ; Existing valkey — walk transactions for (eid,aid) newest-to-oldest. The first transaction
    ; where this valkey is recorded IS its current state — any more recent write would already
    ; have been visited first. Stop as soon as it's found.
    SET found=0
    SET recop=0
    SET curtx=$ORDER(^EATV(eid,aid,""),-1)
    FOR  QUIT:(curtx="")!found  DO
    . IF $$IsDatomRecorded^apiVld(eid,aid,curtx,valkey) DO
    . . SET recop=^EATV(eid,aid,curtx,valkey)
    . . SET found=1
    . ELSE  SET curtx=$ORDER(^EATV(eid,aid,curtx),-1) ; step backwards to previous transaction

    ; Existing valkey, not found in ^EATV, retract — fail
    IF 'found&('op) DO  QUIT 0
    . DO LOGDEBUG^logger("apiWFL","DatomStageMulti: failed — ("_eid_","_aid_","_valkey_") never recorded")

    ; Existing valkey, not found in ^EATV, assert — create
    IF 'found&(op=1) DO  QUIT 1
    . SET %ABR(eid,aid,valkey)=1
    . DO LOGDEBUG^logger("apiWFL","DatomStageMulti: create staged ("_eid_","_aid_","_valkey_")")

    ; Found, recorded state already matches requested op — no-op
    IF recop=op DO  QUIT 2
    . DO LOGDEBUG^logger("apiWFL","DatomStageMulti: no-op — ("_eid_","_aid_","_valkey_") already op="_op)

    ; Found, recorded state differs from requested op — flip it
    SET %ABR(eid,aid,valkey)=op
    DO LOGDEBUG^logger("apiWFL","DatomStageMulti: staged ("_eid_","_aid_","_valkey_")="_op)
    QUIT 1


DatomRevise(eid,aid,valkey) ; stage the cardinality-one Revise operation for (eid,aid) → valkey
;;------------------------------------------------------------------
;; Function : DatomRevise^apiWFL
;;
;; Purpose  : Implements the Revise compound operation for a cardinality-one (eid,aid) pair —
;;            retracts the currently active value at t1 and asserts the new valkey at t2,
;;            by staging the appropriate datoms into %ABR.
;;
;;            Three paths depending on current state of (eid, aid):
;;
;;            ABSENT (no active datom)
;;              → stage assert (OP=1) for new valkey           INSERT
;;
;;            ACTIVE, same valkey
;;              → no-op, nothing staged                        NO-OP
;;
;;            ACTIVE, different valkey
;;              → stage retract (OP=0) for old valkey          REPLACE
;;                stage assert  (OP=1) for new valkey
;;                (both in same transaction)
;;
;; Parameters
;;   eid     : (IN) Entity ID
;;   aid     : (IN) Attribute ID (must be cardinality-one)
;;   valkey  : (IN) Resolved value key for the new assertion
;;
;; Returns  :
;;   2       — no-op (value already current, nothing to stage)
;;   1       — datom(s) staged (INSERT or REPLACE path)
;;   0       — failure (reserved for future error conditions)
;;------------------------------------------------------------------
    NEW curvk
    SET curvk=$$GetCurrentVK^apiGet(eid,aid)

    ; Valkey is not found or it has been previously retracted
    IF curvk=-1 DO  QUIT 1
    . SET %ABR(eid,aid,valkey)=1
    . DO LOGDEBUG^logger("apiWFL","DatomRevise: insert ("_eid_","_aid_","_valkey_") — (eid,aid) not found")
    IF curvk=0 DO  QUIT 1
    . SET %ABR(eid,aid,valkey)=1
    . DO LOGDEBUG^logger("apiWFL","DatomRevise: insert ("_eid_","_aid_","_valkey_") — prior datom retracted")

    ; Same valkey with the current valkey — no-op
    IF curvk=valkey DO  QUIT 2
    . DO LOGDEBUG^logger("apiWFL","DatomRevise: no-op ("_eid_","_aid_","_valkey_") — value unchanged")

    ; Different valkey from the current valkey — retract old, assert new (revision operation)
    SET %ABR(eid,aid,curvk)=0
    SET %ABR(eid,aid,valkey)=1
    DO LOGDEBUG^logger("apiWFL","DatomRevise: replace ("_eid_","_aid_","_curvk_") → ("_valkey_")")
    QUIT 1


DatomAssertSingle(eid,aid,val) ; resolve and stage a single-value (cardinality-one) datom
;;----------------------------------------------------------------------------------------------
;; Function  : DatomAssertSingle^apiWFL
;;
;; Purpose   : Resolves val to a valkey, enforces the uniqueness constraint, and stages the
;;             Revise operation for the entity's current cardinality-one value via DatomRevise.
;;
;; Parameters
;;   eid     : (IN) Entity ID
;;   aid     : (IN) Attribute ID of the assertion predicate — must be cardinality-one
;;   val     : (IN) Literal or reference value — must not contain "|"
;;
;; Returns
;;   2       : no-op — value already current, nothing staged
;;   1       : triplet staged successfully
;;   0       : triplet assertion failed — bad delimiter, resolution failure, or uniqueness violation
;;----------------------------------------------------------------------------------------------
    NEW isAllOk       ; overall success flag returned to caller
    NEW valkey        ; resolved value-type key for val
    NEW isNewValKey   ; resolution result — 1 new valkey allocated, 0 existing valkey reused, <0 resolution failure

    SET isAllOk=1
    SET valkey=""

    ; Reject "|" outright — never silently store a pipe-delimited literal as a single value.
    IF val["|" DO  QUIT 0
    . DO LOGERROR^logger("apiWFL","DatomAssertSingle: '|' delimiter not allowed for cardinality-one attribute ("_aid_") — val="_val)

    ; Resolve into valkey. Reference-typed attributes resolve/register via ResolveAttrRef,
    ; everything else registers as a literal via RegisterAttrVal.
    IF $$IsRefValType^sapiVld(aid) DO
    . SET isNewValKey=$$ResolveAttrRef^sapiRslv(aid,val,.valkey,"ABox")
    ELSE  DO
    . SET isNewValKey=$$RegisterAttrVal^sapiRslv(aid,val,.valkey)

    ; Resolution failure (-1) must abort this datom immediately — the resolver has already
    ; logged the specific cause; this just enforces the abort.
    IF isNewValKey<0 DO  QUIT 0
    . DO LOGERROR^logger("apiWFL","DatomAssertSingle: aborting — value resolution failed for (eid="_eid_",aid="_aid_",val="_val_")")

    ; Uniqueness constraint — failed abort immediately, skipping DatomRevise
    IF '$$ValidateUniqueConstraint^apiVld(eid,aid,val,valkey,isNewValKey) QUIT 0

	; Apply the revise operation to stage the datom
    SET isAllOk=$$DatomRevise(eid,aid,valkey)
    QUIT isAllOk


DatomAssertMulti(eid,aid,val) ; recurse per "|" token, then stage each via DatomStageMulti
;;----------------------------------------------------------------------------------------------
;; Function  : DatomAssertMulti^apiWFL
;;
;; Purpose   : Splits "|"-delimited val into independent DatomAssertMulti calls, or — for a
;;             single token — delegates staging to DatomStageMulti with op=1.
;;
;; Parameters
;;   eid     : (IN) Entity ID
;;   aid     : (IN) Attribute ID of the assertion predicate — must be cardinality-many
;;   val     : (IN) Literal or reference value (can be multi-value "val1|val2")
;;
;; Returns
;;   1       : triplet(s) staged successfully
;;   2       : no-op — single token only, value already active, nothing staged
;;   0       : one or more triplets failed resolution/staging
;;----------------------------------------------------------------------------------------------
    NEW isAllOk   ; overall success flag returned to caller — cleared if any recursive/staging step fails
    NEW pIdx      ; 1-based piece index while splitting val on "|"
    NEW pieceVal  ; current "|"-delimited token during multi-value recursion
    NEW result    ; DatomStageMulti's return for this single token

    SET isAllOk=1

    ; Delimiter present — recurse per "|"-delimited token as an independent datom insertion.
    IF val["|" DO  QUIT isAllOk
    . FOR pIdx=1:1 SET pieceVal=$PIECE(val,"|",pIdx) QUIT:pieceVal=""!'isAllOk  DO
    . . IF '$$DatomAssertMulti(eid,aid,pieceVal) SET isAllOk=0

    SET result=$$DatomStageMulti(eid,aid,val,1)
    IF result=0 QUIT 0
    IF (result=1)&(aid=ALIASID) DO AddKeyword(eid,val) ; add alias as a keyword so it can be used in ydb console
    QUIT result



DatomAssert(eid,aid,val) ; dispatch to the single- or multi-value staging branch by attribute cardinality
;;----------------------------------------------------------------------------------------------
;; Function  : DatomAssert^apiWFL
;;
;; Purpose   : Dispatches to DatomAssertSingle or DatomAssertMulti based on the attribute's
;;             cardinality. Assumes %ABR has already been initialised by Stage.
;;
;; Parameters
;;   eid     : (IN) Entity ID
;;   aid     : (IN) Attribute ID of the assertion predicate
;;   val     : (IN) Literal or reference value (can be multi-value "val1|val2" when cardinality-many)
;;
;; Returns
;;   0       : triplet assertion failed
;;   1       : triplet staged successfully
;;   2       : no-op — value already current, nothing staged (cardinality-one path only)
;;----------------------------------------------------------------------------------------------    
    IF $$IsMultiValue^sapiVld(aid) QUIT $$DatomAssertMulti(eid,aid,val)
    
    QUIT $$DatomAssertSingle(eid,aid,val)



DatomRetractSingle(eid,aid,val) ; resolve and stage a single-value (cardinality-one) retraction
;;----------------------------------------------------------------------------------------------
;; Function  : DatomRetractSingle^apiWFL
;;
;; Purpose   : Resolves the entity's current cardinality-one value via GetCurrentVK and stages
;;             its retraction. val must be omitted — the active value is resolved automatically.
;;
;; Parameters
;;   eid     : (IN) Entity ID
;;   aid     : (IN) Attribute ID — must be cardinality-one
;;   val     : (IN) Must be "" — supplying a value is an error
;;
;; Returns
;;   1       : retraction staged, or no-op (nothing currently active)
;;   0       : failed — val was supplied for a cardinality-one attribute
;;----------------------------------------------------------------------------------------------
    IF val'="" DO  QUIT 0
    . DO LOGERROR^logger("apiWFL","DatomRetractSingle: val must be omitted for cardinality-one attribute ("_aid_") — use DatomRetract(eid,aid)")

    NEW curvk  ; current active valkey for (eid,aid), or -1/0 sentinel from GetCurrentVK
    SET curvk=$$GetCurrentVK^apiGet(eid,aid)

    IF curvk=-1 DO  QUIT 0 ; failed to find current valkey
    . DO LOGERROR^logger("apiWFL","DatomRetractSingle: failed — ("_eid_","_aid_") not found")
    
    IF curvk=0 DO  QUIT 2 ; current valkey found but its most recent state is already a retraction
    . DO LOGDEBUG^logger("apiWFL","DatomRetractSingle: no-op — ("_eid_","_aid_") is already retracted")

    SET %ABR(eid,aid,curvk)=0 ; stage the retracted triplet
    DO LOGDEBUG^logger("apiWFL","DatomRetractSingle: retract staged ("_eid_","_aid_","_curvk_")")
    QUIT 1


DatomRetractMulti(eid,aid,val) ; recurse per "|" token, then stage each via DatomStageMulti
;;----------------------------------------------------------------------------------------------
;; Function  : DatomRetractMulti^apiWFL
;;
;; Purpose   : Validates val is supplied, splits "|"-delimited val into independent
;;             DatomRetractMulti calls, or — for a single token — delegates to
;;             DatomStageMulti with op=0.
;;
;; Parameters
;;   eid     : (IN) Entity ID
;;   aid     : (IN) Attribute ID — must be cardinality-many
;;   val     : (IN) Value(s) to retract — required, can be multi-value "val1|val2"
;;
;; Returns
;;   2       : no-op — single token only, value already inactive/retracted
;;   1       : triplet(s) staged successfully
;;   0       : one or more retractions failed — val omitted, resolution failed, or never recorded
;;----------------------------------------------------------------------------------------------
    IF val="" DO  QUIT 0
    . DO LOGERROR^logger("apiWFL","DatomRetractMulti: value required for cardinality-many attribute ("_aid_")")

    NEW isAllOk   ; overall success flag returned to caller — cleared if any recursive/staging step fails
    NEW pIdx      ; 1-based piece index while splitting val on "|"
    NEW pieceVal  ; current "|"-delimited token during multi-value recursion

    SET isAllOk=1

    ; Delimiter present — recurse per "|"-delimited token as an independent datom retraction.
    IF val["|" DO  QUIT isAllOk
    . FOR pIdx=1:1 SET pieceVal=$PIECE(val,"|",pIdx) QUIT:pieceVal=""!'isAllOk  DO
    . . IF '$$DatomRetractMulti(eid,aid,pieceVal) SET isAllOk=0

    QUIT $$DatomStageMulti(eid,aid,val,0)



DatomRetract(eid,aid,val) ; dispatch to the single- or multi-value retraction branch by attribute cardinality
;;----------------------------------------------------------------------------------------------
;; Function  : DatomRetract^apiWFL
;;
;; Purpose   : Normalizes val, then dispatches to DatomRetractSingle or DatomRetractMulti based
;;             on the attribute's cardinality.
;;
;; Parameters
;;   eid     : (IN) Entity ID
;;
;;   aid     : (IN) Attribute ID
;;
;;   val     : (IN, must be omitted for cardinality-one)
;;             (IN, required for cardinality-many) Value to retract
;;
;; Returns
;;   1       : triplet retraction staged
;;   0       : triplet retraction failed
;;----------------------------------------------------------------------------------------------
    SET val=$GET(val)
    
    IF $$IsMultiValue^sapiVld(aid) QUIT $$DatomRetractMulti(eid,aid,val)
    
    QUIT $$DatomRetractSingle(eid,aid,val)



StageRecord(ResolvedRec,isBulkLoad,ReqAttr,AttrCache) ; resolve, validate, and stage one record's triplets into %ABR
;;------------------------------------------------------------------------------------------------------------------
;; Function : $$StageRecord^apiWFL
;;
;; Purpose  : Resolve target entity, validate, and stage one record's assertions and
;;            retractions into %ABR.
;;
;;            At the staging phase, ResolvedRec contains ONLY entity facts — control
;;            attributes have been consumed by ResolveTargetEntity and eid is immutable.
;;            Assertions "+" are processed before retractions "-" to ensure entity key is
;;            staged before any retractions are attempted.
;;
;; Parameters
;;   ResolvedRec : (IN) Resolved record — assertions and retractions; mutated by
;;                       ResolveTargetEntity during entity-key resolution
;;   isBulkLoad  : (IN) If 1, skips ValidateRecord entirely
;;   ReqAttr     : (IN) Required attributes map from BuildAttrsRequired
;;   AttrCache   : (IN) Schema attribute cache from BuildAttrsCache
;;
;; Returns
;;   2  — there have been no changes on the record no-op 
;;   1  — this record staged cleanly (see hasChanges handling below)
;;   0  — controlled failure (resolution/validation/staging rejected the record)
;;  -1  — uncaught runtime error
;;
;; Notes
;;   DatomAssert/DatomRetract may return 1 (staged), 2 (no-op), or 0 (failed) per attribute.
;;   Only 0 stops the staging loops early. A record where staging fully completes — whether
;;   every attribute wrote something, or some/all were no-ops — is reported as result=1;
;;   hasChanges (via $DATA(%ABR(eid))) is what actually distinguishes "wrote something" from
;;   "processed cleanly but nothing changed," so the per-attribute 1-vs-2 distinction doesn't
;;   need to be tracked separately here.
;;------------------------------------------------------------------------------------------------------------------
    NEW eid			; target entity being asserted or retracted against
    NEW isNewEntity	; whether the target entity is new or previously registered
    NEW hasChanges	; whether staging produced an actual change to %ABR
    NEW result		; outcome of this record's processing, returned to caller

    SET eid=0
    SET result=1
    SET hasChanges=0

    ; Phase 1 — Resolve target entity. No transaction open yet — QUIT directly on failure.
    SET eid=$$ResolveTargetEntity^apiRslv(.ResolvedRec) ; error or success message is logged in ResolveTargetEntity help functions
    IF eid=0  QUIT 0									; aborting — entity resolution failed


    ; Phase 2 — Validate entity facts. Still no transaction open — QUIT directly on failure.
    SET isNewEntity='$$IsEntityRegistered^apiVld(eid)
    IF 'isBulkLoad DO
    . SET result=$$ValidateRecord^apiVld(.ResolvedRec,.ReqAttr,.AttrCache,isNewEntity)
    ELSE  DO
    . DO LOGWARNING^logger("apiWFL","StageRecord: isBulkLoad=1 — ValidateRecord skipped for eid="_eid_" (required-attribute checks bypassed)")

    IF 'result DO  QUIT 0
    . DO LOGERROR^logger("apiWFL","StageRecord: aborting — entity fact validation failed")

	; /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
    ; Phase 3 — Stage datoms into %ABR (local only — no global write, no TSTART needed).
    ; $ETRAP armed to contain a runtime error inside this phase without aborting Stage^api's loop.
    NEW $ETRAP
    SET $ETRAP="GOTO StageRecordERR^apiWFL"

    NEW aid  ; current attribute id while walking ResolvedRec's staged assertions/retractions
    NEW ok   ; per-attribute staging outcome — loop stops early only when this is 0
    SET ok=1

    ; Process assertions "+" first
    SET aid=""
    FOR  SET aid=$ORDER(ResolvedRec("+",aid)) QUIT:aid=""!'ok  DO
    . SET ok=$$DatomAssert(eid,aid,ResolvedRec("+",aid))

    ; Process retractions "-" — only if assertions succeeded
    IF ok DO
    . SET aid=""
    . FOR  SET aid=$ORDER(ResolvedRec("-",aid)) QUIT:aid=""!'ok  DO
    . . SET ok=$$DatomRetract(eid,aid,ResolvedRec("-",aid))

    SET hasChanges=$DATA(%ABR(eid))>0
    
    IF ok=0  SET result=0
    ELSE  IF hasChanges SET result=1
    ELSE  SET result=2

    GOTO StageRecordEND


StageRecordERR
;;   Uncaught runtime error during Phase 3. No TROLLBACK needed — nothing global was ever open.
;;   GOTO StageRecordEND (not QUIT) so this record's failure funnels through the same single
;;   dispatch point as every other exit, restoring $ETRAP and reporting result=-1 to the caller.
    SET result=-1
    DO LOGCRITICAL^logger("apiWFL","StageRecord: unexpected runtime error for eid="_eid_": "_$ZSTATUS)
    SET $ECODE=""          ; clear error code — required or error propagates
    GOTO StageRecordEND


StageRecordEND
;;
;; Single exit point once Phase 3 begins. Restores $ETRAP, logs the outcome, and on any failure
;; cleans up this record's own partial staging as a defensive measure.
;;
    NEW $ETRAP

	IF result=2 DO
    . DO LOGINFO^logger("apiWFL","StageRecordEND: no-op — record processed, nothing changed for eid "_eid)

    IF result=1 DO
    . SET %ABR=$INCREMENT(%ABR)
    . DO LOGINFO^logger("apiWFL","StageRecordEND >>> staged <<< Total Records: "_%ABR)

	IF result=0 DO
    . DO LOGERROR^logger("apiWFL","StageRecordEND: staging failed for eid="_eid_" (result="_result_")")

    IF result<1 DO
    . KILL %ABR(eid)

    QUIT result
; /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\

