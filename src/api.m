;; =================================================================================== 
;; ^api - ABox Data Access API subroutines - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 	 — database engine licensed under SSPL v1.0
;; TaxisBase — knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;;
;; Purpose
;;   Public ABox API for asserting, retracting, committing, and inspecting
;;   entity datoms.
;;
;; Description
;;   Provides the primary interface for loading and maintaining entity facts.
;;   Supports single datom operations, batch assertions/retractions, transactional
;;   commits, and entity history inspection.
;;
;; Responsibilities
;;   • Initialise process-local assertion staging buffer
;;   • Stage single and batch datom assertions
;;   • Stage single and batch datom retractions
;;   • Commit staged datoms transactionally
;;   • Display entity state and datom history
;;
;; Public API Groups
;;   Initialisation
;;		INIT
;;
;;	Assertions & Retractions
;;		Stage
;;
;;   Datom Assertion
;;		AssertDatom  (+)
;;
;;   Datom Retraction
;;		RetractDatom (-)
;;
;;   Transactions
;;		Transact
;;
;;   Inspection
;;		PrintEntity
;;		PrintHistory
;;
;;	Short-form Aliases
;;		AD	-> AssertDatom
;;		RD 	-> RetractDatom	
;;		PE	-> PrintEntity              
;;		PH	-> PrintHistory
;;
;; Notes
;;   • INIT must be called once per process before using the API.
;;   • Stage, AssertDatom, RetractDatom stage changes only; callers must invoke
;;     Transact to persist them.
;;   • This routine forms the stable public interface. Internal
;;     implementation should remain in supporting routines whenever
;;     possible to preserve API compatibility.
;;====================================================================================

INIT	
;;------------------------------------------------------------------
;; Procedure : INIT  —  Module entry point
;;
;; Call      : DO INIT^api
;;
;; Purpose   : Must be called once per user session before any other entry point in this module.
;;
;; Parameters: None
;;
;; Returns   : Nothing (procedure)
;;
;; Sets      : %ABR = 0  (process-level staging buffer)
;;
;; Notice    : %ABR is initialised to 0 by INIT^api on session
;;             startup and reset to 0 by TransactCLEAR after every
;;             Transact call — success or failure.
;;------------------------------------------------------------------    
    KILL %ABR
    SET %ABR=0    
        
    QUIT

  
AD(ekv,akey,val,ns) ; Short-form alias for AssertDatom
;;------------------------------------------------------------------
;; Procedure : AD
;; Call      : DO AD^api(ekv,akey,val,ns)
;;
;; Purpose   : Short-form alias for AssertDatom.
;;------------------------------------------------------------------
    DO AssertDatom^api($GET(ekv),$GET(akey),$GET(val),$GET(ns,"sandbox"))
    QUIT


AssertDatom(ekv,akey,val,ns) ; Convenience wrapper of Stage to stage a single datom assertion for a new or existing entity
;;-------------------------------------------------------------------------------------------------------------------------
;; Procedure : AssertDatom
;; Call      : DO AssertDatom^api(ekv,akey,val,ns)
;;
;; Purpose   : Convenience wrapper of Stage to stage a single datom assertion for a new or existing entity.
;;             Detects the ekv format, builds the minimal Stage-compatible Datom structure
;;             and delegates to Stage.
;;
;; Parameters
;;   ekv     : (IN) entity specified with one of the following formats
;;   				Format A — raw EID       					e.g. "654f2564f8165hevmhe6"
;;   				Format B — compound lookup attr-key|value  	e.g. "sandbox.dlc.id|042"
;;   				Format C — entity's (sys.attr.key)			e.g. "obj.tom_hanks"
;;
;;   akey    : (IN) attribute key 								e.g. "movie.title"
;;
;;   val     : (IN) Value to assert — "|"-delimited for multi-value
;;
;;   ns      : (IN, optional) Namespace. Default: "sandbox"
;;
;;
;;	Examples : Format A  — DO AssertDatom^api("6583d90d9b0e5704qj59","sys.attr.name","Mr. Foobar")
;;			   Format B  — DO AssertDatom^api("sandbox.dlc.id|042","sandblox.dlc.checkup","F3 checkup update @en")
;;			   Format C  — DO AssertDatom^api("obj.tom_hanks","sys.attr.name","Tommy")
;;
;; 
;; TODO		: ATTENTION FORMAT C !!! it can accept anything here as ekv
;; 			  and if it is not found, it will create a new entity with 
;; 			  (1,"sys.attr.key")=ekv
;; 			  (1,akey)=val
;;
;;--------------------------------------------------------------------------------------------------------------------
    NEW Datom,attrkey,attrval
    SET ns=$GET(ns,"sandbox")

    IF $GET(ekv)=""  DO LOGERROR^logger("API","AssertDatom: ekv is required") QUIT
    IF $GET(akey)="" DO LOGERROR^logger("API","AssertDatom: akey is required") QUIT
    IF $GET(val)=""  DO LOGERROR^logger("API","AssertDatom: val is required") QUIT

    
    IF $$IsEID^utils(ekv) DO				; Format A — raw EID
    . SET Datom(1,"sys.attr.id")=ekv
    ELSE  IF ekv["|" DO						; Format B — compound lookup attr-key|value
    . SET attrkey=$PIECE(ekv,"|",1)
    . SET attrval=$PIECE(ekv,"|",2)    
    . SET Datom(1,attrkey)=attrval    
    ELSE  SET Datom(1,"sys.attr.key")=ekv 	; Format C — entity's sys.attr.key
	
    SET Datom(1,akey)=val    
    DO Stage(.Datom,ns,0)
    QUIT


RD(ekv,akey,val,ns) ; Short-form alias for RetractDatom
;;------------------------------------------------------------------
;; Procedure : RD
;; Call      : DO RD^api(ekv,akey,val,ns)
;;
;; Purpose   : Short-form alias for RetractDatom.
;;------------------------------------------------------------------
    DO RetractDatom^api($GET(ekv),$GET(akey),$GET(val),$GET(ns,"sandbox"))
    QUIT


RetractDatom(ekv,akey,val,ns) ; Convenience wrapper of Stage to stage a single datom retraction for an existing entity
;;---------------------------------------------------------------------------------------------------------------------
;; Procedure : RetractDatom
;; Call      : DO RetractDatom^api(ekv,akey,val,ns)
;;
;; Purpose   : Convenience wrapper of Stage to stage a single datom retraction for an existing entity.
;;             Detects the ekv format, builds the minimal Stage-compatible Datom structure, 
;;			   and delegates to Stage.
;;
;; Parameters
;;   ekv     : (IN) entity specified with one of the following formats
;;   				Format A — raw EID       					e.g. "654f2564f8165hevmhe6"
;;   				Format B — compound lookup attr-key|value  	e.g. "sandbox.dlc.id|042"
;;   				Format C — entity's (sys.attr.key)			e.g. "obj.tom_hanks"
;;
;;   akey    : (IN) attribute key 								e.g. "movie.title"
;;
;;   val     : (IN) value to retract
;;					if attribute is a single-valued then it is omitted (it is not optional)
;;				    if attribute is multi-valued then it must be present
;;
;;   ns      : (IN) optional namespace. Default: "sandbox"
;;
;;
;;	Examples : Format A  — DO RetractDatom^api("6583d90d9b0e5704qj59","sys.attr.name")
;;			   Format B  — DO RetractDatom^api("sandbox.dlc.id|042","sandblox.dlc.checkup") — single-value atttribute
;;			   Format C  — DO RetractDatom^api("obj.tom_hanks","sys.attr.name")
;;
;;
;;	Notice	 : Retractions always target existing entities and must never create a new one
;;             Format B and Format C both must check that entity already exists before Stage is called
;;             If the entity cannot be resolved, the call is aborted with an error before any staging occurs.
;;---------------------------------------------------------------------------------------------------------------------
    NEW Datom,attrkey,attrval,isEntityFound
    
    SET isEntityFound=1
    SET ns=$GET(ns,"sandbox")

    IF $GET(ekv)=""  DO LOGERROR^logger("API","RetractDatom: ekv is required") QUIT
    IF $GET(akey)="" DO LOGERROR^logger("API","RetractDatom: akey is required") QUIT    

    IF $$IsEID^utils(ekv) DO			; Format A — raw EID
    . SET isEntityFound=$$GetEID^apiGet(ekv)
    . SET Datom(1,"sys.attr.id")=ekv
    ELSE  IF ekv["|" DO 				; Format B — compound lookup attr-key|value
    . SET attrkey=$PIECE(ekv,"|",1)
    . SET attrval=$PIECE(ekv,"|",2)
    . SET Datom(1,attrkey)=attrval
    . SET isEntityFound=$$LookupEID^apiGet(attrval,attrkey)    
    ELSE  DO							; Format C — entity's sys.attr.key
    . SET isEntityFound=$$GetEID^apiGet(ekv)
    . SET Datom(1,"sys.attr.key")=ekv

	; Check if entity exists — Retractions must never create new entities.
	IF isEntityFound DO
	. SET Datom(1,akey,"-")=$GET(val) ; use $GET because for cardinality-one attributes val is omitted
    . ; Delegate datoms to Stage
    . DO Stage(.Datom,ns,0)
	ELSE  DO LOGERROR^logger("API","RetractDatom: entity not found — "_ekv)
    
    QUIT


Stage(Data,ns,isBulkLoad,ok) ; builds a staged set of datoms (all or nothing) that will later be consumed by Transact.
;;------------------------------------------------------------------------------------------------------------------------------
;; Routine  : Stage
;;
;; Call     : DO Stage^api(.Data,ns,isBulkLoad,.ok)
;;
;; Usage    : Entry point for staging multiple records into %ABR before
;;            transactional commit via Transact^api. Supports both assertions
;;            (default) and retractions ("-") within the same record.
;;
;; Purpose  : Resolves each record's attribute keys, orchestrates entity
;;            resolution/validation/staging via StageRecord, and guarantees
;;            batch atomicity — the FOR loop stops on the first failure, and
;;            %ABR is discarded in full, not just the failing record.
;;
;; Parameters
;;   Data       : (IN)  Multi-record input structure
;;                       Data(idx,attributeName)     = value  ; assert (default)
;;                       Data(idx,attributeName,"-") = value  ; retract (explicit)
;;
;;   ns         : (IN)  namespace prefix path of arbitrary depth (one or more dot-separated segments)
;;						It's not restricted to a single top-level segment; 
;;						it's simply whatever comes before the entity-type-qualified attribute name
;;						e.g. (john.sandbox.cinema.) --> ns
;;							 (movie.title)			--> akey
;;                      Entity's attributes are relative to this namespace. e.g. movie.title
;;
;;   isBulkLoad : (IN)  1 = skips record validation
;;                      0 = performs record validation
;;
;;   ok         : (OUT)  2 : every record staged cleanly, but nothing changed
;;						 1 : if every record staged; 
;;						 0 : validation/resolution failure 
;;						-1 : deeper failure surfaced the batch was aborted %ABR discarded
;;
;; Namespace convention:
;;   ns parameter is the schema namespace used for attribute resolution and validation.
;;
;;   Data Input Example		:	e.g. ns="john.sandbox.cinema"
;;      						Then input records use attributes relative to the schema namespace e.g.:
;;								S M(17,"movie.title")="Seven @en"
;;    							S M(17,"movie.genre")="thriller|mystery"
;;						etc...
;;   							Do NOT pass fully qualified attribute names when using Stage:
;;     							S M(17,"john.sandbox.cinema.movie.imdbid")="tt0011100"  <-- invalid attribute 
;;
;; %ABR Example				: Staged triplets of two records
;;							  %ABR("6583f05ec5dd43kbzqc3",1000,"K3E8.01889C")=1
;; 				  			  %ABR("6583f05ec5dd43kbzqc3",1001,"K3E9.018859")=1
;; 				  			  %ABR("6583f05ec5dd43kbzqc3",1001,"K3E9.01885A")=1
;; 				  			  %ABR("6583f05ec5dd43kbzqc3",1002,"K3EA.018880")=1
;;
;; 				  			  %ABR("6583f05ec5e850wgrgnc",1000,"K3E8.01889E")=1
;; 				  			  %ABR("6583f05ec5e850wgrgnc",1001,"K3E9.018876")=1
;; 				  			  %ABR("6583f05ec5e850wgrgnc",1002,"K3EA.01889F")=1
;;
;;------------------------------------------------------------------------------------------
    SET ok=1
    ; Guard — %ABR must exist before staging can begin
    IF '$DATA(%ABR) DO LOGERROR^logger("API","Stage: %ABR not initialised — call INIT^api first") SET ok=0 QUIT

    NEW idx			; drives the FOR loop over record indices in Data
    NEW ReqAttr		; required-attribute map for ns, built once for the whole batch
    NEW AttrCache	; forward/reverse attribute key cache for ns, built once for the whole batch
    NEW recCount	; total records attempted, for the summary log line
    NEW failedIdx	; idx of the record that caused the batch to abort, if any
    
	SET ns=$GET(ns,"sandbox")          ; default namespace when caller omits ns
    SET isBulkLoad=$GET(isBulkLoad,0)  ; default 0 — validation runs unless caller opts into bulk load
    SET recCount=0                     ; running count of records attempted, for the summary log line
    SET failedIdx=""                   ; idx of the record that aborted the batch, if any

	
    ; Build required attributes map — used by ValidateRecord
    DO BuildAttrsRequired^sapiBld(ns,.ReqAttr)
	
    ; Build schema attributes cache — 
    ;	forward map used by ResolveRecAttrs
    ; 	reverse map used by ValidateRecord
    DO BuildAttrsCache^sapiBld(ns,.AttrCache)
		
    SET idx=""
    ; Iterate the top-level first subscript of Data input. Each idx represents a temporary ID for a record.
    ; Loop exits when idx is exhausted, or stops immediately on first failure (ok<1) —
    ; remaining records are never attempted.
    FOR  SET idx=$ORDER(Data(idx)) QUIT:(idx="")!(ok<1)  DO
    . NEW ResolvedRec 			; current record's attributes resolved to internal aids
    . SET recCount=recCount+1
    . SET ok=$$ResolveRecAttrs^apiRslv(ns,$NAME(Data(idx)),.AttrCache,.ResolvedRec) ; Resolve attribute keys to internal aids
    . IF ok=0 DO  QUIT
    . . SET failedIdx=idx
    . . DO LOGERROR^logger("API","Stage: attribute resolution failed for idx="_idx_" — batch will be aborted")
    . SET ok=$$StageRecord^apiWFL(.ResolvedRec,isBulkLoad,.ReqAttr,.AttrCache)
    . IF ok<1 SET failedIdx=idx

    IF ok<1 DO    
    . KILL %ABR
    . SET %ABR=0
    . DO LOGERROR^logger("API","Stage: batch aborted at record idx="_failedIdx_" (ok="_ok_") — entire batch discarded, "_recCount_" record(s) attempted for ns="_ns)
    ELSE  IF $GET(%ABR,0)=0 DO
    . SET ok=2
    . DO LOGINFO^logger("API","Stage: no-op — no staged records, nothing committed")
    ELSE  DO
    . DO LOGINFO^logger("API","Stage: processed "_recCount_" record(s) — "_$GET(%ABR,0)_" record(s) staged for ns="_ns_" isBulkLoad="_isBulkLoad)
    
    QUIT    


Transact(user) ; Commits the staged %ABR buffer to the ABox globals under a single transaction.
;;----------------------------------------------------------------------------------------------------
;; Routine  : Transact^api
;;
;; Purpose  : Commits the staged %ABR buffer to the ABox globals under a single transaction.
;;
;; Parameters
;;   user    : (IN)  User initiating the transaction, defaults to "Root" if not supplied.
;;
;;
;; Notice   : All writes are wrapped in TSTART/TCOMMIT. 
;;			  Any failure sets ok<1 and TROLLBACK discards all partial writes atomically.
;;          : %ABR is always KILLed on exit — success or failure.
;;----------------------------------------------------------------------------------------------------
    NEW ok      ;    transaction outcome:
    			;  2 no-op 
    		 	;  1 success, 
    			;  0 invalid, 
    			; -1 runtime error (drives TransactEND dispatch)
    
    NEW tx      ; transaction stamp shared by every assertion/retraction in this batch
    NEW aid     ; current attribute id while walking staged %ABR
    NEW valkey  ; current value key while walking staged %ABR
    NEW eid     ; current entity id while walking staged %ABR
    NEW cnt     ; $INCREMENT() return value (tx / entity / datom counters) — used for its side effect only

    SET ok=1
    SET user=$GET(user,"Root")

    ; Validate — %ABR must be initialised and populated before commit.
    IF '$DATA(%ABR) DO  GOTO TransactEND
    . SET ok=0

	; Empty staging is a valid no-op, not an error.
	IF $GET(%ABR,0)=0 DO  GOTO TransactEND
	. SET ok=2


; /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
    ; Wrap all global writes in a single transaction
    TSTART ()
    NEW $ETRAP
    SET $ETRAP="GOTO TransactERR^api"

    ; Generate transaction ID now — all assertions and retractions in this batch share a single
    ; tx stamp. Increment ^TXE root counter to track total indexed transactions.
    SET tx=$$TxAdd^sapiWFL(user)
    SET cnt=$INCREMENT(^TXE)

    ; Iterate all staged entity records. For each entity:    
    SET eid=""
    FOR  SET eid=$ORDER(%ABR(eid)) QUIT:(eid="")!(ok<1)  DO
    . QUIT:eid=%ABR            					; skip root node counter %ABR=n — not an entity subscript
    . IF '$$IsEntityRegistered^apiVld(eid) DO   ; Register entity in ABox entity index if not yet asserted
    . . SET ^ABE(eid,1)=""          			; mark entity as asserted
    . . SET cnt=$INCREMENT(^ABE)    			; increment total ABox entity counter
    . ; Iterate all attributes for this entity
    . SET aid=""
    . FOR  SET aid=$ORDER(%ABR(eid,aid)) QUIT:(aid="")!(ok<1)  DO
    . . ; Iterate all value keys for this attribute
    . . SET valkey=""
    . . FOR  SET valkey=$ORDER(%ABR(eid,aid,valkey)) QUIT:(valkey="")!(ok<1)  DO
    . . . NEW op
    . . . SET op=%ABR(eid,aid,valkey)		; Read OP from staging buffer
    . . . SET ^EATV(eid,aid,tx,valkey)=op   ; primary datom store, everything about a given entity
    . . . SET ^AVET(aid,valkey,eid,tx)=op   ; secondary-lookup index to find entities by attribute + value
    . . . SET ^AEVT(aid,eid,valkey,tx)=op   ; all values for a given attribute, column access
    . . . IF $$IsRefValType^sapiVld(aid) DO
    . . . . SET ^VAET(valkey,aid,eid,tx)=op ; reverse-reference index (reference attributes only)
    . . . SET ^TXE(tx,eid)=""               ; transaction → entity index
    . . . SET cnt=$INCREMENT(^EATV)         ; increment datom counter
    . . . DO LOGDEBUG^logger("API","Transact: ^EATV("_eid_","_aid_","_tx_","_valkey_")="_op)

TransactEND ; dispatch on ok/$TLEVEL to commit, rollback, or log-only
;;----------------------------------------------------------------------------------------------
;; Exit codes for ok:
;;   2  : no-op — no datom was asserted in the database, no changes, no entities affected
;;   1  : normal completion — TCOMMIT persists all globals
;;   0  : invalid data — validation guard failed, TROLLBACK discards partial writes
;;  -1  : runtime error — $ETRAP redirected here via TransactERR, TROLLBACK discards all writes
;;----------------------------------------------------------------------------------------------
    IF (ok=1)&($TLEVEL>0) DO  GOTO TransactCLEAR
    . TCOMMIT
    . DO LOGINFO^logger("API","Transact: committed "_$GET(%ABR,0)_" records, tx="_tx)

    IF (ok=0)&($TLEVEL>0) DO  GOTO TransactCLEAR
    . DO LOGERROR^logger("API","Transact: rolling back — invalid staging data")
    . TROLLBACK

    IF (ok=-1)&($TLEVEL>0) DO  GOTO TransactCLEAR
    . DO LOGCRITICAL^logger("API","Transact: rolling back — runtime error")
    . TROLLBACK

	; No transaction was ever open — this is the pre-TSTART guard-clause path
    ; (%ABR missing). Nothing to roll back, just log and clear.
    IF (ok=0)&($TLEVEL=0) DO  GOTO TransactCLEAR
    . DO LOGERROR^logger("API","Transact: %ABR not initialised — call INIT^api first")

	; No transaction was ever open — this is the pre-TSTART guard-clause path
    ; (%ABR empty). Nothing to commit or roll back, just log and clear.
    IF (ok=2)&($TLEVEL=0) DO  GOTO TransactCLEAR
    . DO LOGINFO^logger("API","Transact: no-op — no staged records, nothing committed")


TransactCLEAR ; reset staging buffer for the next batch, regardless of outcome
    KILL %ABR ; always clear — success or failure
    SET %ABR=0
    QUIT

TransactERR ; error trap target — captures runtime errors during the write loop
    ; Restore caller's trap immediately to prevent re-entry into this handler on any nested error
    NEW $ETRAP
    SET ok=-1
    DO LOGCRITICAL^logger("API","Transact: unexpected runtime error: "_$ZSTATUS)
    SET $ECODE=""          ; clear error code — required or error propagates
    GOTO TransactEND
; /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\


PE(val,attr)
;;------------------------------------------------------------------
;; Routine  : PE — Procedure
;; Call     : DO PE^api(val,attr)
;;
;; Purpose  : Short-form alias for PrintEntity.
;;            Defaults val and attr at the call boundary so that
;;            undefined actuals do not shadow PrintEntity's own
;;            $GET handling with empty strings.
;;
;; Parameters
;;   val     : (IN, optional) Entity reference — eid, sys.attr.key,
;;                            or unique attribute value
;;   attr    : (IN, optional) Attribute key or aid, used to scope
;;                            unique-attribute resolution
;;------------------------------------------------------------------
	SET val=$GET(val,"")
	SET attr=$GET(attr,"")
    D PrintEntity(val,attr)
    QUIT


PrintEntity(val,attr)
;;------------------------------------------------------------------
;; Routine  : PrintEntity — Procedure
;;
;; Purpose  : Resolves an entity from any supported reference and
;;            prints all currently active attribute values in tabular
;;            format (eid | attribute | value).
;;
;;            Only live datoms (latest tx with OP=1) are displayed.
;;            Retracted datoms (OP=0) and empty resolved values are
;;            suppressed.
;;
;;            Cardinality-one attributes display only the most recent
;;            active value.
;;
;;            Cardinality-many attributes display all active values
;;            (deduplicated by most recent transaction precedence).
;;
;; Accepts:
;;   val  : eid | sys.attr.key | unique attribute value
;;   attr : optional aid (forces unique lookup attribute resolution path)
;;
;;------------------------------------------------------------------
    NEW eid,aid,tx,valkey,op
    NEW attrName,vk
    NEW seen,isMany,done
    NEW attrOrig

	; Process attr parameter
 	SET attr=$GET(attr)
    SET attrOrig=attr
    ; only resolve when attr is supplied AND not already numeric;
    ; -1 on failure is intentional — lets GetEID^apiGet attempt Path 2
    ; instead of silently falling back to Path 1
    SET attr=$SELECT(attr="":attr,attr=+attr:attr,1:$$GetEID^sapiGet(attr))

    DO BuildKeysCatalog^sapiBld
    SET eid=$$GetEID^apiGet(val,attr)

    IF eid=0 DO  QUIT
    . DO LOGINFO^logger("API","PrintEntity: entity not found — val=`"_val_"`")
    
    ; ------------------------------------------------------------------
    ; Header output
    ; ------------------------------------------------------------------
    WRITE !
    WRITE !,"=============================="
    WRITE !,val
    WRITE !,"=============================="

    ; ------------------------------------------------------------------
    ; Step 2 — iterate all attributes for this entity
    ; ^EATV(eid,aid,...) yields all attribute IDs in sorted order
    ; ------------------------------------------------------------------
    SET aid=""
    FOR  SET aid=$ORDER(^EATV(eid,aid)) QUIT:aid=""  DO
    . NEW attrName,val,vk,isMany,done
    . NEW seen
    . ; Step 3 — resolve attribute display name
    . SET attrName=""
    . SET vk=$ORDER(%Keys(aid,AKEYID,""))
    . IF vk'="" SET attrName=$GET(%Keys(aid,AKEYID,vk))
    . ; Step 4 — determine cardinality behavior
    . SET isMany=$$IsMultiValue^sapiVld(aid)
    . KILL seen
    . SET done=0
    . ; --------------------------------------------------------------
    . ; Step 5 — iterate transactions in descending order
    . ; Most recent transaction is processed first
    . ; --------------------------------------------------------------
    . SET tx=$ORDER(^EATV(eid,aid,""),-1)
    . FOR  QUIT:(tx="")!(done)  DO
    . . NEW valkey,op
    . . ; ----------------------------------------------------------
    . . ; Step 6 — iterate all value keys within this transaction
    . . ; ----------------------------------------------------------
    . . SET valkey=$ORDER(^EATV(eid,aid,tx,""))
    . . FOR  QUIT:(valkey="")!(done)  DO
    . . . ; Step 6a — deduplicate across transactions - first encounter = most recent occurrence
    . . . IF '$DATA(seen(valkey)) DO
    . . . . SET seen(valkey)=1
    . . . . ; Step 7 — check datom state (OP=1 live, OP=0 retracted)
    . . . . SET op=$GET(^EATV(eid,aid,tx,valkey),0)
    . . . . IF op DO
    . . . . . ; Step 8 — resolve value key to human-readable label
    . . . . . IF $$IsRefValType^sapiVld(aid) DO
	. . . . . . NEW targeteid
	. . . . . . SET targeteid=$GET(^TBD(aid,valkey))
	. . . . . . SET val=$SELECT(targeteid'="":$$GetKeyForRefEID^apiGet(targeteid),1:"")
	. . . . . ELSE  DO
	. . . . . . SET val=$$GetDictValue^sapiGet(aid,valkey)
    . . . . . ; suppress unresolved/blank values
    . . . . . IF val'="" DO
    . . . . . . WRITE !
    . . . . . . WRITE $JUSTIFY(eid,22)
    . . . . . . WRITE "  "
    . . . . . . WRITE $EXTRACT(attrName_$JUSTIFY("",33),1,33)
    . . . . . . WRITE "  "
    . . . . . . WRITE val
    . . . . . ; Step 9 — cardinality-one optimization stop after first live value is found
    . . . . . IF 'isMany SET done=1
    . . . SET valkey=$ORDER(^EATV(eid,aid,tx,valkey))
    . . SET tx=$ORDER(^EATV(eid,aid,tx),-1)

    WRITE !
    QUIT


PH(val,attr)
;;------------------------------------------------------------------
;; Routine  : PH — Procedure
;; Call     : DO PH^api(val,attr)
;;
;; Purpose  : Short-form alias for PrintHistory.
;;            Defaults val and attr at the call boundary so that
;;            undefined actuals do not shadow PrintHistory's own
;;            $GET handling with empty strings.
;;
;; Parameters
;;   val     : (IN, optional) Entity reference — eid, sys.attr.key,
;;                            or unique attribute value
;;   attr    : (IN, optional) Attribute key or aid, used to scope
;;                            unique-attribute resolution
;;------------------------------------------------------------------
	SET val=$GET(val,"")
	SET attr=$GET(attr,"")
    D PrintHistory(val,attr)
    QUIT


PrintHistory(val,attr)
;;------------------------------------------------------------------
;; Routine  : PrintHistory — Procedure
;;
;; Purpose  : Prints the raw ^EATV content for a resolved entity.
;;            Displays full datom history including retractions.
;;
;;            Accepts multiple entity reference forms via GetEID:
;;              - eid
;;              - sys.attr.key
;;              - unique attribute value
;;
;; Parameters
;;   val     : (IN, optional) Entity reference — eid, sys.attr.key,
;;                            or unique attribute value
;;   attr    : (IN, optional) Attribute key or aid, used to scope
;;                            unique-attribute resolution
;;
;; Resolution Flow:
;;   1. Entity resolution   val,attr -> GetEID -> eid
;;   2. Raw scan           eid -> ^EATV(eid,aid,tx,valkey)
;;
;; Output:
;;   One row per (eid, aid, tx, valkey, op)
;;
;;     eid | aid | tx | valkey | ( + / - )
;;
;; Globals:
;;   ^EATV - datom store
;;------------------------------------------------------------------

    NEW eid,aid,tx,valkey,op
    NEW attrOrig

    ; ------------------------------------------------------------------
    ; Step 0 — normalize attr into internal attribute id (aid)
    ; Supports:
    ;   - numeric aid (e.g. 1005)
    ;   - sys.attr.key (e.g. sandbox.dlc.id)
    ;
    ; Resolution is delegated to GetEID to avoid duplicate logic.
    ;
    ; attrOrig preserves the raw caller-supplied string BEFORE it is
    ; overwritten by the resolved/unresolved aid below. This is needed
    ; later — if resolution ultimately fails, the error branch must be
    ; able to tell whether the problem was an invalid ATTRIBUTE name
    ; (attrOrig was non-numeric and never resolved) versus an invalid
    ; VALUE under an otherwise-valid attribute.
    ; ------------------------------------------------------------------
    SET attr=$GET(attr)
    SET attrOrig=attr
    IF attr'="" DO
    . NEW tmp
    . ; If attr is already numeric (aid), keep it
    . IF attr=+attr QUIT
    . ; Otherwise treat it as sys.attr.key and resolve via GetEID.
    . ; Keep whatever GetEID^sapi returns, including -1 on failure,
    . ; so GetEID^api receives a non-empty aid and attempts Path 2
    . ; resolution rather than silently falling back to Path 1.
    . SET tmp=$$GetEID^sapiGet(attr)
    . SET attr=tmp

    ; ------------------------------------------------------------------
    ; Step 1 — resolve entity using unified resolver
    ; ------------------------------------------------------------------
    SET eid=$$GetEID^apiGet(val,attr)

    IF eid<0 DO  QUIT
    . NEW isEidShaped
    . SET isEidShaped=$$IsEID^utils(val)
    . ; Distinguish WHY resolution failed, for diagnosability.
    . ; attrOrig is used (not attr) because attr has already been
    . ; overwritten with the resolved aid (or -1) by Step 0.
    . ;
    . ;   Case A — caller supplied a non-numeric attr string, but it
    . ;            never resolved to a known attribute id at all
    . ;            (typo, or not a registered sys.attr.key). Invalid
    . ;            ATTRIBUTE — caller/schema mistake.
    . ;
    . ;   Case B — attr resolved successfully (or was passed in
    . ;            numerically), but val does not resolve as a unique
    . ;            value under that attribute. Invalid VALUE under a
    . ;            valid attribute.
    . ;
    . ;   Case C — no attr supplied, and val is structurally a valid
    . ;            EID (correct length/format) but does not exist in
    . ;            ^EATV. This is different from a garden-variety
    . ;            unresolvable string — it means someone passed a
    . ;            real-looking entity ID that isn't actually live,
    . ;            e.g. stale, retracted-and-purged, or mistyped in a
    . ;            way that still happens to be well-formed.
    . ;
    . ;   Case D — no attr supplied, val is not EID-shaped, and it
    . ;            also did not resolve via sys.attr.key. Ordinary
    . ;            "unrecognized reference" case.
    . IF (attrOrig'="")&(attrOrig'=+attrOrig)&(attr<0) DO
    . . DO LOGINFO^logger("API","PrintHistory: invalid attribute — `"_attrOrig_"` does not resolve to a known sys.attr.key")
    . ELSE  IF attr'="" DO
    . . DO LOGINFO^logger("API","PrintHistory: invalid value — val=`"_val_"` not found under aid="_attr)
    . ELSE  IF isEidShaped DO
    . . DO LOGINFO^logger("API","PrintHistory: invalid value — val=`"_val_"` has a valid EID structure but does not exist in ^EATV")
    . ELSE  DO
    . . DO LOGINFO^logger("API","PrintHistory: invalid value — val=`"_val_"` not found via sys.attr.key lookup")    

    ; ------------------------------------------------------------------
    ; Header
    ; ------------------------------------------------------------------
    WRITE !
    WRITE !,"=============================="
    WRITE !,val
    WRITE !,"=============================="
    WRITE !
    WRITE $JUSTIFY("eid",22)
    WRITE "  "
    WRITE $JUSTIFY("aid",6)
    WRITE "  "
    WRITE $JUSTIFY("tx",6)
    WRITE "  "
    WRITE $JUSTIFY("valkey",14)
    WRITE "  "
    WRITE "OP"
    WRITE !

    ; ------------------------------------------------------------------
    ; Step 2 — iterate all attributes for this entity
    ; ------------------------------------------------------------------
    SET aid=""
    FOR  SET aid=$ORDER(^EATV(eid,aid)) QUIT:aid=""  DO
    . NEW tx,valkey
    . ; --------------------------------------------------------------
    . ; Step 3 — iterate transactions (natural order preserved)
    . ; --------------------------------------------------------------
    . SET tx=""
    . FOR  SET tx=$ORDER(^EATV(eid,aid,tx)) QUIT:tx=""  DO
    . . NEW valkey
    . . ; ----------------------------------------------------------
    . . ; Step 4 — iterate valkeys for this tx
    . . ; ----------------------------------------------------------
    . . SET valkey=""
    . . FOR  SET valkey=$ORDER(^EATV(eid,aid,tx,valkey)) QUIT:valkey=""  DO
    . . . SET op=$GET(^EATV(eid,aid,tx,valkey),0)
    . . . WRITE !
    . . . WRITE $JUSTIFY(eid,22)
    . . . WRITE "  "
    . . . WRITE $JUSTIFY(aid,6)
    . . . WRITE "  "
    . . . WRITE $JUSTIFY(tx,6)
    . . . WRITE "  "
    . . . WRITE $JUSTIFY(valkey,14)
    . . . WRITE "  "
    . . . WRITE $SELECT(op=1:"( + )",1:"( - )")

    WRITE !
    QUIT
    
;; =============================================== END OF api.m =======================================