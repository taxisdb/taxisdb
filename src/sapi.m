;; ================================================================================ 
;; ^sapi - TBox Schema/Data Access API subroutines - This file is part of TaxisDB Platform
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
;; Purpose
;;   Public Schema API for TBox schema assertions, maintenance,
;;   inspection, and transaction management.
;;
;; Description
;;   This routine is the primary interface used by application code and
;;   interactive users. It provides high-level entry points for creating,
;;   updating, fetching, printing, exporting, and committing schema metadata.
;;
;;   Most entry points are thin wrappers that perform minimal parameter
;;   handling before delegating the actual work to specialised routines.
;;   The implementation logic is intentionally separated into supporting
;;   modules to keep this routine as the stable public API interface.
;;
;; Responsibilities
;;   • Initialise process-local schema state (INIT)
;;   • Stage schema metadata assertions (Stage, AssertDatom, AddAttr, AD)
;;   • Commit staged schema changes transactionally (Transact)
;;   • Print schema, entities, attributes and diagnostics
;;   • Export schema entities
;;   • Retrieve transaction history
;;   • Provide short interactive aliases for common operations
;;
;; Public API Groups
;;   Initialisation
;;     INIT
;;
;;   Schema Assertions 
;;     Stage
;;     AssertDatom
;;     AddAttr
;;
;;   Schema Transactions
;;     Transact
;;     GetTransactions
;;
;;   Inspection / Reporting
;;     PrintSchema
;;     PrintAttributes
;;     PrintAttributeDictionary
;;     PrintEntity
;;     PrintEntities
;;     PrintTBoxState
;;
;;   Export
;;     ExportEntities
;;
;;   Short-form Aliases
;;     AD  -> AssertDatom
;;     PA  -> PrintAttributes
;;     PS  -> PrintSchema
;;     PAD -> PrintAttributeDictionary
;;     PE  -> PrintEntity
;;     PEs -> PrintEntities
;;     EE  -> ExportEntities
;;
;; Notes
;;   • INIT must be called once per process before using the API.
;;   • Stage* and AddAttr stage changes only; callers must invoke
;;     Transact to persist them.
;;   • This routine forms the stable public interface. Internal
;;     implementation should remain in supporting routines whenever
;;     possible to preserve API compatibility.
;;==============================================================================


INIT
;;------------------------------------------------------------------
;; Routine  : INIT — Procedure
;; Call     : DO INIT^sapi
;;
;; Purpose  : Must be called once per process before any other entry point in this module.
;;
;;            Initialises:
;;              • process-level semantic metadata constants
;;              • process-local staging buffers
;;
;;            The resolved constants are cached in process memory so downstream routines
;;			  can perform fast semantic checks without repeated TBox lookups.
;;
;;-------------------------------------------------------------------	
	
	; Run-time constants
    SET AKEYID=210	; $$GetEID^sapiGet uses AKEYID=210 a hard-coded value 
    				; this constant must be initialized first.
    			    ; Everytime we start a user session, including the bootstrap of the system (^start)
    			    ; we must call INIT^sapi otherwise it will throw an error
    				; %YDB-E-LVUNDEF, Undefined local variable: AKEYID

    SET RANGEID=$$GetEID^sapiGet("sys.attr.range")
    SET CARDINID=$$GetEID^sapiGet("sys.attr.cardinality")	
	SET UNIQUEID=$$GetEID^sapiGet("sys.attr.unique")
	SET REQID=$$GetEID^sapiGet("sys.attr.required")
	SET ISAID=$$GetEID^sapiGet("sys.attr.isa")
	SET ALIASID=$$GetEID^sapiGet("sys.attr.alias")
	SET VALIDFNID=$$GetEID^sapiGet("sys.attr.validationfn")
	SET SYSATTRID=$$GetEID^sapiGet("sys.attr.id")
	SET RESOLVEDBYID=$$GetEID^sapiGet("sys.attr.resolvedby")
	SET UNQINSERTID=$$GetEID^sapiGet("sys.enum.unique.insert")
	SET UNQUPSERTID=$$GetEID^sapiGet("sys.enum.unique.upsert")
	
	; those entities OBJ and ASSOC types don't exist yet when the system is initially being built.
	SET OBJID=$$GetEID^sapiGet("sys.type.obj")
	SET ASSOCID=$$GetEID^sapiGet("sys.type.assoc")
	SET ATTRTYPEID=$$GetEID^sapiGet("sys.type.attr")
	
	; Reference value keys
	SET REFKEY=$$GetRefValKey^sapiGet("sys.val.ref")
	SET LANGSTRKEY=$$GetRefValKey^sapiGet("sys.val.langstr")
	SET FNKEY=$$GetRefValKey^sapiGet("sys.val.fn")
	SET ONEKEY=$$GetRefValKey^sapiGet("sys.enum.cardinality.one","sys.attr.cardinality")
	SET MANYKEY=$$GetRefValKey^sapiGet("sys.enum.cardinality.many","sys.attr.cardinality")
	SET INSERTKEY=$$GetRefValKey^sapiGet("sys.enum.unique.insert","sys.attr.unique")
	SET UPSERTKEY=$$GetRefValKey^sapiGet("sys.enum.unique.upsert","sys.attr.unique")
	
	; Required enum keys
	SET REQTRUEKEY=$GET(^TBDR(REQID,1))
	SET REQFALSEKEY=$GET(^TBDR(REQID,0))
	
    ; Initialise process-level staging buffers
    KILL %Keys
    SET %Keys=0

    KILL %Schema
    SET %Schema=0

    KILL %Tx
    SET %Tx=0

	KILL %TBR
    SET %TBR("count")=0

    QUIT


AD(ekey,akey,val,ns) ; short-form alias for AssertDatom
;;------------------------------------------------------------------
;; Function or Routine  : AD ; Routine (QUIT returns no value)
;;
;; Call     : DO AD^sapi(ekey,akey,val,ns)
;;
;; Usage    : DO AD^sapi("sandbox.person.name","sys.attr.description","name of the person @en")
;;
;; Purpose  : Short-form convenience alias for AssertDatom.
;;
;; Parameters
;;   ekey : (IN) Schema attribute key of an EXISTING attribute, e.g. "sandbox.person.name"
;;   akey : (IN) Metadata attribute key, e.g. "sys.attr.description"
;;   val  : (IN) Value to assert
;;   ns   : (IN, optional) Namespace, defaults to "sandbox"
;;
;; Notes    : Thin wrapper — all validation and staging logic lives in AssertDatom.
;;            Does not commit — caller must call Transact^sapi to persist.
;;------------------------------------------------------------------
    DO AssertDatom^sapi($GET(ekey),$GET(akey),$GET(val),$GET(ns,"sandbox"))
    QUIT


AssertDatom(ekey,akey,val,ns)
;;------------------------------------------------------------------
;; Procedure : AssertDatom
;; Call      : DO AssertDatom^sapi(ekey,akey,val,ns)
;;
;; Purpose   : Convenience wrapper — stages and commits a single
;;             metadata attribute assertion for an existing schema
;;             attribute. Mirrors AssertDatom^api in structure.
;;
;;             ATTENTION: ekey MUST EXIST — use the full namespace
;;             for ekey. This is only a shortcut method to update an
;;             existing attribute of the schema quickly.
;;             For bulk changes or new attributes use Stage^sapi
;;             with a 2D local array.
;;
;; Example   : DO AssertDatom^sapi("sandbox.person.name","sys.attr.description","name of the person @en")
;;
;; Parameters
;;   ekey    : (IN) Schema attribute key e.g. "sandbox.person.name"
;;   akey    : (IN) Metadata attribute key e.g. "sys.attr.description"
;;   val     : (IN) Value to assert
;;   ns      : (IN, optional) Namespace. Default: "sandbox"
;;------------------------------------------------------------------
    NEW Datom
    SET ns=$GET(ns,"sandbox")    
    SET Datom(1,"sys.attr.key")=ekey
    SET Datom(1,akey)=val
    DO Stage(.Datom,ns)
    QUIT


AddAttr(ekey,range,cardin,isa,unq,doc,alias,req,validfn,ns) ; stage one schema attribute for later commit
;;------------------------------------------------------------------
;; Function or Routine  : AddAttr ; Routine (QUIT returns no value)
;;
;; Call     : DO AddAttr^sapi(ekey,range,cardin,isa,unq,doc,alias,req,validfn,ns)
;;
;; Usage    : Convenience wrapper for staging a single schema attribute without
;;            building an Stage-compatible metadata array by hand
;;
;; Purpose  : Builds a minimal Stage-compatible metadata structure for one
;;            attribute and stages it via Stage.
;;
;; Parameters
;;   ekey    : (IN) Schema attribute key, e.g. "sandbox.person.name"
;;   range   : (IN) Value type, e.g. STRING, INT, DATE
;;   cardin  : (IN) Cardinality, e.g. ONE, MANY
;;   isa     : (IN) Type, e.g. ATYPE
;;   unq     : (IN, optional) Uniqueness
;;   doc     : (IN, optional) Documentation string
;;   alias   : (IN, optional) Alias string
;;   req     : (IN, optional) Required flag
;;   validfn : (IN, optional) Validation predicate
;;   ns      : (IN, optional) Namespace, defaults to "sandbox"
;;
;; Notes    : Does not commit — caller must call Transact^sapi to persist.
;;            Intended for interactive/manual use; logs errors rather than
;;            returning a status, since there is no caller to check one.
;;------------------------------------------------------------------
    SET ekey=$GET(ekey,"")
    SET range=$GET(range,"")
    SET cardin=$GET(cardin,"")
    SET isa=$GET(isa,"")

    ; Required fields missing — nothing to stage, log and exit
    IF (ekey="")!(range="")!(cardin="")!(isa="") DO  QUIT
    . DO LOGERROR^logger("SAPI","AddAttr: missing required field(s) — ekey/range/cardin/isa must all be non-empty")

    NEW Datom
    SET Datom(1,"sys.attr.key")=ekey
    SET Datom(1,"sys.attr.range")=range
    SET Datom(1,"sys.attr.cardinality")=cardin
    SET Datom(1,"sys.attr.isa")=isa

    SET unq=$GET(unq,"")
    SET doc=$GET(doc,"")
    SET alias=$GET(alias,"")
    SET req=$GET(req,"")
    SET validfn=$GET(validfn,"")
    SET ns=$GET(ns,"sandbox")

    ; Optional metadata fields only added when actually supplied
    SET:unq'="" Datom(1,"sys.attr.unique")=unq
    SET:doc'="" Datom(1,"sys.attr.description")=doc
    SET:alias'="" Datom(1,"sys.attr.alias")=alias
    SET:req'="" Datom(1,"sys.attr.required")=req
    SET:validfn'="" Datom(1,"sys.attr.validationfn")=validfn

    NEW ok
    DO Stage(.Datom,ns,.ok)
    IF 'ok DO LOGERROR^logger("SAPI","AddAttr: staging failed for ekey="_ekey)
    QUIT


Stage(Data,ns,ok) ; stage TBox schema metadata records into %TBR, all-or-nothing
;;---------------------------------------------------------------------------------
;; Routine  : Stage ; Routine (QUIT returns no value)
;;
;; Call     : DO Stage(.Data,ns,.ok)
;;
;; Usage    : Entry point for staging multiple schema attribute records into %TBR
;;            before transactional commit. Caller must check ok and only call
;;            Transact^sapi when ok=1.
;;
;; Purpose  : Iterates Data, extracts each record into RecMeta, and validates it before
;;            staging. Aborts on the first invalid record and discards everything
;;            staged in this call, so a partial batch can never be committed.
;;
;; Parameters
;;   Data : (IN)  Multi-record input structure, Data(idx,metaKey)=value
;;                e.g. Data(idx,"sys.attr.key")="sandbox.movie.title"
;;
;;   ns   : (IN)  Namespace/entity type, defaults to "sandbox"
;;
;;   ok   : (OUT) 1 if every record validated and staged successfully
;;                0 if a record failed validation — staging aborted, %TBR untouched
;;
;; Notes    : Each record is checked against the schema via GetEID to resolve an
;;            existing eid (or -1 if new) before IsNotValidAttrMetadata and StageRecord run.
;;------------------------------------------------------------------
    SET ok=1 ; tracks batch success; flips to 0 on first validation failure

    ; Guard clauses — bail out early if the staging buffer or input is unusable
    IF '$DATA(%TBR) DO LOGERROR^logger("SAPI","Stage: %TBR not initialised") SET ok=0 QUIT
    IF '$DATA(Data) DO LOGERROR^logger("SAPI","Stage: Data is empty — nothing to stage") SET ok=0 QUIT
    IF '$$IsTwoLevelArray^sapiVld(.Data) DO LOGERROR^logger("SAPI","Stage: Data must have exactly two subscript levels") SET ok=0 QUIT

    NEW idx	; drives the outer FOR loop over record indices in Data
    NEW RecMeta	; holds one record's metadata at a time
    NEW akey	; drives the inner FOR loop over metadata keys within one record
    SET ns=$GET(ns,"sandbox")
    SET idx=""

    ; For each record, validate before staging; stop as soon as any record fails
    FOR  SET idx=$ORDER(Data(idx)) QUIT:(idx="")!'ok  DO
    . KILL RecMeta
    . NEW eid
    . SET akey=""
    . ; Extract all metadata key-value pairs for this record into RecMeta
    . FOR  SET akey=$ORDER(Data(idx,akey)) QUIT:akey=""  DO
    . . SET RecMeta(akey)=Data(idx,akey)
    . ; Resolve an existing attribute EID for this key, if one is already in the schema
    . SET eid=-1
    . IF $DATA(RecMeta("sys.attr.key")) DO
    . . SET eid=$$GetEID^sapiGet(RecMeta("sys.attr.key"))
    . . IF eid>0 DO LOGDEBUG^logger("SAPI","Stage: Attribute with EID="_eid_" found.")
    . ; On failure, flag the batch as bad and skip staging this record; loop exits next pass
    . IF $$IsNotValidAttrMetadata^sapiVld(.RecMeta,eid) DO
    . . SET ok=0
    . . DO LOGERROR^logger("SAPI","Stage: validation failed at idx="_idx_" — aborting batch")
    . ELSE  IF '$$StageRecord^sapiWFL(.RecMeta,eid) SET ok=0

    ; All-or-nothing guarantee: on any failure, discard everything staged in this call
	IF 'ok DO
	. DO LOGERROR^logger("SAPI","Stage: batch aborted — discarding staged records")
	. KILL %TBR
	. SET %TBR("count")=0

    QUIT
     

Transact(user) ; commit staged %TBR batch to TBox globals under one transaction
;;------------------------------------------------------------------------------
;; Routine  : Transact^sapi
;;
;; Purpose  : Commits the staged %TBR buffer to the TBox globals. 
;;            Transact handles only TBox assertion writes and transaction stamping.
;;
;; Parameters
;;   user 	: (IN) User initiating the transaction, defaults to "Root" if not supplied.
;;
;;---------------------------------------------------------------------------------
    SET user=$GET(user,"Root")
    
    NEW ok        ; transaction outcome — 1 success, 0 invalid, 2 no-op, -1 runtime error (drives TransactEND dispatch)
    NEW tx        ; transaction stamp shared by every assertion in this batch
    NEW eid       ; current entity id while walking staged %TBR
    NEW aid       ; current attribute id while walking staged %TBR
    NEW valkey    ; current value key while walking staged %TBR
    NEW cnt       ; $INCREMENT() return value (tx counter / total assertion counter) — used for its side effect only
    NEW changes   ; count of triplets actually written (non-redundant) this transaction
        
    SET tx=""
    SET ok=1
    
    SET eid=""
    SET aid=""
    set valkey=""
    
    SET cnt=0
    SET changes=0

    ; Guard — %TBR must exist; Stage kills it entirely on any validation failure
    IF '$DATA(%TBR) DO  GOTO TransactEND
    . SET ok=0
    . DO LOGERROR^logger("SAPI","Transact: %TBR not initialised — call INIT^sapi first")

    ; Guard — a populated but empty batch (e.g. no records were ever staged) also aborts
    IF $GET(%TBR("count"),0)=0 DO  GOTO TransactEND
    . SET ok=0
    . DO LOGWARNING^logger("SAPI","Transact: %TBR is empty — nothing to commit")

    ; Wrap all global writes in a single transaction
    TSTART ()
    NEW $ETRAP
    SET $ETRAP="GOTO TransactERR^sapi"

    ; One tx stamp covers every assertion in this batch; ^TXE root tracks total tx count
    SET tx=$$TxAdd^sapiWFL(user)
    SET cnt=$INCREMENT(^TXE)

    SET eid=""
    ; Walk every staged entity, attribute, and value key, writing each as a TBox assertion
    FOR  SET eid=$ORDER(%TBR(eid)) QUIT:(eid="")  DO
    . ; Iterate all attributes for this entity
    . SET aid=""
    . FOR  SET aid=$ORDER(%TBR(eid,aid)) QUIT:(aid="")  DO
    . . ; Iterate all value keys for this attribute
    . . SET valkey=""
    . . FOR  SET valkey=$ORDER(%TBR(eid,aid,valkey)) QUIT:(valkey="")  DO
    . . . ; Skip if this exact (eid,aid,valkey) triplet was already asserted previously
    . . . IF $$IsNotRedundantTriplet^sapiVld(eid,aid,valkey) DO
    . . . . SET ^TBEAVT(eid,aid,valkey,tx)=1       ; TBox primary assertion store
    . . . . SET ^TBAVET(aid,valkey,eid,tx)=1       ; TBox inverted index
    . . . . SET ^TXE(tx,eid)=""                    ; reverse tx -> entity index
    . . . . SET cnt=$INCREMENT(^TBEAVT)            ; total assertion counter
    . . . . SET changes=$INCREMENT(changes)        ; actual write count this tx
    . . . . DO LOGDEBUG^logger("SAPI","Transact: ^TBEAVT("_eid_","_aid_","_valkey_","_tx_")")

    IF changes=0 SET ok=2 ; If nothing was changed under this tx. Flag as a no-op

    GOTO TransactEND


TransactEND ; dispatch on ok/$TLEVEL to commit, rollback, or log-only
;;----------------------------------------------------------------------------------------------
;; Exit codes for ok:
;;   2  : no-op — no datom was asserted in the database, no changes, no entities affected
;;   1  : normal completion — TCOMMIT persists all globals
;;   0  : invalid data — validation guard failed, TROLLBACK discards partial writes
;;  -1  : runtime error — $ETRAP redirected here via TransactERR, TROLLBACK discards all writes
;;-----------------------------------------------------------------------------------------------
	
	IF (ok=2)&($TLEVEL>0) DO  GOTO TransactCLEAR
	. SET ^TXE(tx,0)="" ; no-op 0 in reverse transaction index indicates that transaction did not add any facts in the database
    . DO LOGINFO^logger("SAPI","Transact: no-op — Total datoms written: "_changes_", tx counter: "_tx)
    . TCOMMIT    

    IF (ok=1)&($TLEVEL>0) DO  GOTO TransactCLEAR
    . TCOMMIT
    . DO LOGINFO^logger("SAPI","Transact: committed "_%TBR("count")_" records, Total datoms written: "_changes_", tx counter: "_tx)

    IF (ok=0)&($TLEVEL>0) DO  GOTO TransactCLEAR
    . DO LOGERROR^logger("SAPI","Transact: rolling back — invalid staging data")
    . TROLLBACK

    IF (ok=-1)&($TLEVEL>0) DO  GOTO TransactCLEAR
    . DO LOGCRITICAL^logger("SAPI","Transact: rolling back — runtime error")
    . TROLLBACK

    ; No transaction was ever open — this is the pre-TSTART guard-clause path 
    ; (%TBR missing or empty). Nothing to roll back, just log and clear.
    IF (ok=0)&($TLEVEL=0) DO  GOTO TransactCLEAR
    . DO LOGERROR^logger("API","Transact: invalid staging data — no transaction level, skipping rollback")

TransactCLEAR ; reset staging buffer for the next batch, regardless of outcome
    KILL %TBR ; always clear — success or failure
    SET %TBR("count")=0
    QUIT

TransactERR  
;;  Unexpected runtime error — caught by $ETRAP, redirected here. 
;;  Restore caller's trap first, before anything else runs, 
;;  to prevent re-entry into this same handler on a nested error.
    NEW $ETRAP
    SET ok=-1
    DO LOGCRITICAL^logger("SAPI","Transact: unexpected runtime error: "_$ZSTATUS)
    SET $ECODE=""
    GOTO TransactEND


PA(ns,isAidSorted) ; Thin wrapper around PrintAttributes.
	SET isAidSorted=$GET(isAidSorted,1)
	D PrintAttributes(ns,isAidSorted)
	QUIT


PrintAttributes(ns,isAidSorted) ; Print Attributes that match namespace pattern
;;------------------------------------------------------------------------------------
;; Routine  : PrintAttributes — Procedure
;; Call     : DO PrintAttributes^sapi(ns)
;;
;; Purpose  : Resolves all schema attributes whose key matches ns
;;            via BuildKeysCatalog and prints a formatted section header
;;            followed by one row per attribute showing its entity ID,
;;            key string, and value count in the data type.
;;            Only entities marked as attributes (see IsAttrType) are printed.

;; Parameters
;;   ns       	 : (IN) name space label is a schema prefix string used to
;;                 filter attributes e.g. "sandbox" or "sandbox.movie"
;;                 or "sys.attr"
;;   isAidSorted : (IN, optional, default 1) if 1, rows are sorted
;;                 alphabetically by attribute key. If 0, rows are printed in
;;                 the natural %Keys order (by attribute aid).
;;
;; Globals
;;   Read    : %Keys    	  — populated by BuildKeysCatalog, root node holds
;;                              total count, subscripted nodes hold
;;                              %Keys(eid,AKEYID,valkey)=literal
;;            ^TBDR(aid)      — per-attribute value counter
;;
;;------------------------------------------------------------------
    NEW aid,akey,valkey,result,attrCount

    SET isAidSorted=$GET(isAidSorted,1)

    DO BuildKeysCatalog^sapiBld(ns)    

	; Count only attribute-type entities — %Keys may also include
    ; non-attribute TBox entities sharing the same key prefix (e.g.
    ; composite value types), which must not inflate the header total.
    SET attrCount=0
    SET aid=""
    FOR  SET aid=$ORDER(%Keys(aid)) QUIT:aid=""  DO
    . IF $$IsAttrType^sapiVld(aid) SET attrCount=attrCount+1

	DO PrintNamespaceSection^sapiUtils(ns,attrCount)

	; natural order, sorted by attribute key
    IF 'isAidSorted DO
    . SET aid=""
    . ; walk %Keys by aid 
    . FOR  SET aid=$ORDER(%Keys(aid)) QUIT:aid=""  DO
    . . QUIT:'$$IsAttrType^sapiVld(aid)
    . . SET valkey=$ORDER(%Keys(aid,AKEYID,""))
    . . SET akey=$GET(%Keys(aid,AKEYID,valkey))
    . . DO PrintRow^sapiUtils("^TBDR("_aid_")",akey,$GET(^TBDR(aid),0))

	; sorted by attribute aid
    IF isAidSorted DO
    . SET aid=""
    . ; buffer rows into result(akey)=aid, then walk result alphabetically by key and print
    . FOR  SET aid=$ORDER(%Keys(aid)) QUIT:aid=""  DO
    . . QUIT:'$$IsAttrType^sapiVld(aid)
    . . SET valkey=$ORDER(%Keys(aid,AKEYID,""))
    . . SET akey=$GET(%Keys(aid,AKEYID,valkey))
    . . SET result(akey)=aid
    . SET akey=""
    . FOR  SET akey=$ORDER(result(akey)) QUIT:akey=""  DO
    . . SET aid=result(akey)
    . . DO PrintRow^sapiUtils("^TBDR("_aid_")",akey,$GET(^TBDR(aid),0))

    QUIT


PS(ns) ; short-form alias for PrintSchema
	D PrintSchema(ns)
	QUIT


PrintSchema(ns) ; Prints a formatted table of schema attributes and their metadata
;;------------------------------------------------------------------
;; Routine  : PrintSchema — Procedure
;; Call     : DO PrintSchema^sapi("sandbox.movie")
;;
;; Purpose  : Prints a formatted table of schema attributes and their
;;            metadata for all attributes matching a given prefix.
;;
;; How it works:
;;   1. Call BuildSchemaView to populate %Schema with all resolved metadata
;;      assertions for attributes matching ns
;;   2. Build a secondary index %ByKey(akey,eid)="" so rows can be
;;      visited in akey order rather than eid order
;;   3. Iterate %ByKey by akey, then eid, and print one row per attribute
;;
;; Parameters
;;   ns : (IN) name space label is a schema prefix string used to filter attributes
;;				e.g. "sandbox" or "sandbox.movie" or "sys.attr"
;; Globals
;;   Read   : %Schema    — populated by BuildSchemaView
;;                         %Schema(eid,akey)=val
;;
;; Calls
;;   BuildSchemaView^sapi(ns) — populates %Schema
;;
;; Notice   : PrintSchema uses its own column widths and formatting
;;            independent of PrintW, PrintDIV, and PrintHDR — the schema
;;            table has seven columns while the TBox status table has
;;            three.
;;------------------------------------------------------------------
    NEW eid,akey,range,cardinality,req,unq,doc
    NEW wEID,wKey,wRange,wCardin,wReq,wUnq,wDoc,div,hdr
    NEW %ByKey

    DO BuildSchemaView^sapiBld(ns)

    ; Column widths
    SET wEID=5
    SET wKey=30
    SET wRange=15
    SET wCardin=10
    SET wReq=5
    SET wUnq=10
    SET wDoc=100

    ; Divider
    SET div="  +"_$TRANSLATE($JUSTIFY("",wEID+2)," ","_")
    SET div=div_"+"_$TRANSLATE($JUSTIFY("",wKey+2)," ","_")
    SET div=div_"+"_$TRANSLATE($JUSTIFY("",wRange+2)," ","_")
    SET div=div_"+"_$TRANSLATE($JUSTIFY("",wCardin+2)," ","_")
    SET div=div_"+"_$TRANSLATE($JUSTIFY("",wReq+2)," ","_")
    SET div=div_"+"_$TRANSLATE($JUSTIFY("",wUnq+2)," ","_")
    SET div=div_"+"_$TRANSLATE($JUSTIFY("",wDoc+2)," ","_")_"+"

    ; Header
    SET hdr="  | "_$JUSTIFY("eid",wEID)
    SET hdr=hdr_" | "_$EXTRACT("akey"_$JUSTIFY("",wKey),1,wKey)
    SET hdr=hdr_" | "_$EXTRACT("range"_$JUSTIFY("",wRange),1,wRange)
    SET hdr=hdr_" | "_$EXTRACT("cardin."_$JUSTIFY("",wCardin),1,wCardin)
    SET hdr=hdr_" | "_$EXTRACT("req"_$JUSTIFY("",wReq),1,wReq)
    SET hdr=hdr_" | "_$EXTRACT("unq"_$JUSTIFY("",wUnq),1,wUnq)
    SET hdr=hdr_" | "_$EXTRACT("doc"_$JUSTIFY("",wDoc),1,wDoc)_" |"

    WRITE !,div
    WRITE !,hdr
    WRITE !,div

    ; Build a secondary index sorted by akey, so we can traverse
    ; %Schema in akey order instead of eid order
    SET eid=""
    FOR  SET eid=$ORDER(%Schema(eid)) QUIT:eid=""  DO
    . SET akey=$GET(%Schema(eid,"sys.attr.key"))
    . SET %ByKey(akey,eid)=""

    SET akey=""
    FOR  SET akey=$ORDER(%ByKey(akey)) QUIT:akey=""  DO
    . SET eid=""
    . FOR  SET eid=$ORDER(%ByKey(akey,eid)) QUIT:eid=""  DO
    . . SET range=$GET(%Schema(eid,"sys.attr.range"),"")
    . . SET cardinality=$GET(%Schema(eid,"sys.attr.cardinality"),"")
    . . SET req=$GET(%Schema(eid,"sys.attr.required"),"")
    . . SET unq=$GET(%Schema(eid,"sys.attr.unique"),"")
    . . SET doc=$GET(%Schema(eid,"sys.attr.description"),"")
    . .
    . . ; Strip sys.val. and sys.enum.cardinality. prefixes for compactness
    . . SET range=$PIECE(range,"sys.val.",2)
    . . SET cardinality=$PIECE(cardinality,"sys.enum.cardinality.",2)
    . . ; sys.attr.required is stored as boolean 1/0 — normalise to "true"/"false" for display
    . . SET req=$SELECT(req=1:"true",req="1":"true",1:req)
    . . SET unq=$PIECE(unq,"sys.enum.unique.",2)
    . .
    . . WRITE !,"  | "_$JUSTIFY(eid,wEID)
    . . WRITE " | "_$EXTRACT(akey_$JUSTIFY("",wKey),1,wKey)
    . . WRITE " | "_$EXTRACT(range_$JUSTIFY("",wRange),1,wRange)
    . . WRITE " | "_$EXTRACT(cardinality_$JUSTIFY("",wCardin),1,wCardin)
    . . WRITE " | "_$EXTRACT(req_$JUSTIFY("",wReq),1,wReq)
    . . WRITE " | "_$EXTRACT(unq_$JUSTIFY("",wUnq),1,wUnq)
    . . WRITE " | "_$EXTRACT(doc_$JUSTIFY("",wDoc),1,wDoc)_" |"

    WRITE !,div,!
    QUIT


PrintTBoxState ; Prints a formatted summary table of the current state of TBox
;;-----------------------------------------------------------------------------
;; Routine  : PrintTBoxState — Procedure
;; Call     : DO PrintTBoxState^sapi
;;            X TBS (keyword alias in keywords.m)
;;
;; Purpose  : Prints a formatted summary table of the current TBox
;;            region state, organised into four sections:
;;              1. Counters    — last transaction ID, total terms
;;              2. Assertions  — total triplet facts, last entity ID
;;              3. Attributes  — total attributes and total value keys
;;              4. Values 	   — per-namespace and data type listing of value counts per attribute
;;
;; Globals
;;   Read   : ^TX                   — last transaction ID
;;            ^TBE	                — total terms defined
;;            ^TBEAVT               — total triplet facts
;;            ^TBEAVT("seq")        — last entity ID allocated
;;            ^TBD                  — total attributes
;;            ^TBDR                 — total value keys
;;            ^TBDR(aid)            — per-attribute value counter
;;            %Keys           		— populated by BuildKeysCatalog via
;;                                    PrintAttributes for each namespace
;;
;; Calls
;;   $$PrintDIV						— renders horizontal divider line
;;   $$PrintHDR                    	— renders column header row
;;   PrintRow(akey,desc,val)		— renders a single data row
;;   PrintSection(label)			— renders a section header block
;;   PrintAttributes(ns)      		— renders value counts per attribute for a given namespace prefix
;;
;; Parameters: None
;;
;; Returns  : Nothing (procedure). Output written to current device.
;;------------------------------------------------------------------
    WRITE !,$$PrintDIV^sapiUtils
    WRITE !,$$PrintHDR^sapiUtils
    WRITE !,$$PrintDIV^sapiUtils

    DO PrintRow^sapiUtils("^TX","Last Transaction",$GET(^TX,0))
    DO PrintRow^sapiUtils("^TBE","Total terms defined",$GET(^TBE,0))

    DO PrintSection^sapiUtils("Assertions")
    DO PrintRow^sapiUtils("^TBEAVT","Total triplet facts",$GET(^TBEAVT,0))
    DO PrintRow^sapiUtils("^TBEAVT(""seq"")","Last entity ID",$GET(^TBEAVT("seq"),0))    

    DO PrintSection^sapiUtils("Data Type Values")
    DO PrintRow^sapiUtils("^TBDR","Total value keys",$GET(^TBDR,0))
    DO PrintAttributes("sys.attr")
    DO PrintAttributes("sandbox")
    

    WRITE !,$$PrintDIV^sapiUtils,!
    QUIT


PAD(akv) ; short-form alias for PrintAttributeDictionary
    DO PrintAttributeDictionary(akv)
    QUIT


PrintAttributeDictionary(akv) ; print all attribute values in its dictionary (value domain)
;;------------------------------------------------------------------
;; Routine  : PrintAttributeDictionary
;;
;; Call     : DO PrintAttributeDictionary(key)
;;
;; Usage    : 
;;
;; Purpose  : Resolves an attribute and prints all values in its dictionary (value domain).
;;            The attribute dictionary values are stored in ^TBD(aid,valkey).
;;
;;            The attribute range is defined separately by
;;            sys.attr.range and identifies the value type accepted by
;;            the attribute. Dictionary values are the concrete values
;;            registered for that attribute.
;;
;; Parameters
;;   akv    : (IN) Attribute identifier — numeric aid or attribute key
;;
;; Scope
;;   Reads  : ^TBD
;;
;; Notes   : Numeric attribute IDs are resolved to sys.attr.key for display.
;;            ^TBD provides value-key to value resolution. ^TBDR provides
;;            the reverse lookup and together they form the value dictionary.
;;------------------------------------------------------------------
    NEW aid           ; resolved attribute entity ID
    NEW attrkey       ; attribute key for display
    NEW valkey        ; dictionary value key
    NEW val           ; dictionary value

    IF akv=+akv SET aid=akv
    ELSE  SET aid=$$GetEID^sapiGet(akv)

    IF aid<0 DO  QUIT
    . WRITE !,"Unknown attribute: ",akv,!

    SET attrkey=$$GetKey^sapiGet(aid)
    IF attrkey="" SET attrkey=akv

    IF '$DATA(^TBD(aid)) DO  QUIT
    . WRITE !,"Attribute has no dictionary values: ",attrkey,!

    WRITE !
    WRITE "=============================="
    WRITE !
    WRITE attrkey
    WRITE !
    WRITE "=============================="

    SET valkey=""
    FOR  SET valkey=$ORDER(^TBD(aid,valkey)) QUIT:valkey=""  DO
    . SET val=$GET(^TBD(aid,valkey))
    . WRITE !
    . WRITE $JUSTIFY(aid,4)
    . WRITE "  "
    . WRITE $EXTRACT(valkey_$JUSTIFY("",20),1,20)
    . WRITE "  "
    . WRITE val

    WRITE !
    QUIT


PE(key) ; short-form alias for PrintEntity
	D PrintEntity(key)
	QUIT


PrintEntity(ekv) ; print schema entity facts
;;------------------------------------------------------------------
;; Function or Routine  : PrintEntity ; Routine
;;
;; Call     : DO PrintEntity(key)
;;
;; Usage    : DO PrintEntity(1007)
;;			  DO PrintEntity("sandbox.movie.imdbid")
;;            DO PrintEntity(imdb) ; if attribute alias is loaded as a MUMPS keyword
;;
;; Purpose  : Resolves a TBox entity and prints its assertions.
;;
;; Parameters
;;   ekv    : (IN) TBox entity identifier — numeric eid or natural key
;;
;; Scope
;;   Reads  : ^TBEAVT, ^TBD
;;
;;------------------------------------------------------------------
    NEW eid           ; resolved entity ID
    NEW aid           ; attribute entity ID
    NEW valkey        ; entity value key
    NEW attrName      ; resolved attribute name
    NEW val           ; resolved value
    NEW vk            ; attribute key value key
    NEW entityName    ; entity key for display

    ; TBox entities are schema-level entities stored in ^TBEAVT.
    ; Resolve either a numeric eid or a natural key.
    IF ekv=+ekv SET eid=ekv
    ELSE  SET eid=$$GetEID^sapiGet(ekv)

    IF eid<0 DO  QUIT
    . WRITE !,"Unknown schema entity: ",ekv,!

    IF '$DATA(^TBEAVT(eid)) DO  QUIT
    . WRITE !,"Unknown schema entity EID: ",eid,!

    ; Get TBox entity key label if it is available
    SET entityName=$$GetKey^sapiGet(ekv)
    IF entityName="" SET entityName=ekv

    WRITE !
    WRITE "=============================="
    WRITE !
    WRITE entityName
    WRITE !
    WRITE "=============================="

    ; Iterate entity assertions.
    SET aid=""
    FOR  SET aid=$ORDER(^TBEAVT(eid,aid)) QUIT:aid=""  DO
    . ; Resolve attribute name from the attribute key.
    . SET attrName=""
    . SET vk=$ORDER(%Keys(aid,AKEYID,""))
    . IF vk'="" SET attrName=$GET(%Keys(aid,AKEYID,vk))
    . ; Resolve each stored value.
    . SET valkey=""
    . FOR  SET valkey=$ORDER(^TBEAVT(eid,aid,valkey)) QUIT:valkey=""  DO
    . . SET val=$$GetDictValue^sapiGet(aid,valkey)
    . . WRITE !
    . . WRITE $JUSTIFY(eid,4)
    . . WRITE "  "
    . . WRITE $EXTRACT(attrName_$JUSTIFY("",23),1,23)
    . . WRITE "  "
    . . WRITE val

    WRITE !
    QUIT
    

   
PEs(ns,keys) ; short-form alias for PrintEntities
	SET keys=$GET(keys,0)
	D PrintEntities(ns,keys)
	QUIT

PrintEntities(ns,keys) ; Print all schema entities whose key is matching namespace prefix
;;---------------------------------------------------------------------------------------
;; Routine  : PrintEntities — Procedure
;;
;; Purpose  : Print all entities whose key belongs to the specified
;;            namespace prefix.
;;
;; Examples :
;;   DO PrintEntities^sapi("sys")
;;   DO PrintEntities^sapi("sys.attr")
;;   DO PrintEntities^sapi("sandbox.movie")
;;   DO PrintEntities^sapi("sys.val",1)   ; keys-only, sorted by eid
;;
;; Parameters
;;   ns   : (IN) namespace prefix to match against ^TBDR keys
;;   keys : (IN, optional, default 0) if 1, print only the sys.attr.key
;;              row for each matching entity, with no headers, sorted
;;              numerically by eid rather than alphabetically by key.
;;
;; Notes:
;;   Keys are read from ^TBDR(AKEYID,key) which is alphabetically
;;   ordered by key. Iteration starts at ns and terminates as soon
;;   as the namespace prefix no longer matches.
;;------------------------------------------------------------------
    NEW key
    NEW nslen
    NEW eid,attrName

    SET keys=$GET(keys,0)
    SET nslen=$LENGTH(ns)

    IF 'keys DO
    . WRITE !
    . WRITE !,"=============================="
    . WRITE !,"Namespace: ",ns
    . WRITE !,"=============================="
    . WRITE !

    SET key=ns

    IF 'keys DO
    . FOR  DO  QUIT:key=""
    . . SET key=$ORDER(^TBDR(AKEYID,key))
    . . QUIT:key=""
    . . QUIT:$EXTRACT(key,1,nslen)'=ns
    . . DO PrintEntity(key)

    IF keys DO
    . SET attrName=$EXTRACT("sys.attr.key"_$JUSTIFY("",23),1,23)
    . FOR  DO  QUIT:key=""
    . . SET key=$ORDER(^TBDR(AKEYID,key))
    . . QUIT:key=""
    . . QUIT:$EXTRACT(key,1,nslen)'=ns
    . . NEW eid
    . . SET eid=$$GetEID^sapiGet(key)
    . . QUIT:eid<0
    . . WRITE !,$JUSTIFY(eid,4),"  ",attrName,"  ",key
    . WRITE !

    QUIT


GetTransactions(n) ; populate %Tx with transaction IDs from ^TX, filtered by n
;;------------------------------------------------------------------
;; Function or Routine  : GetTransactions ; Routine (QUIT returns no value)
;;
;; Call     : DO GetTransactions^sapi(n)
;;
;; Usage    : DO GetTransactions^sapi(-5) ; last 5 transactions, then read %Tx
;;
;; Purpose  : Populates %Tx with transaction IDs from ^TX filtered by n.
;;            n=""  : all transactions
;;            n>0   : first n transactions (ascending)
;;            n<0   : last n transactions (descending)
;;
;; Parameters
;;   n : (IN) Filter control value — "" for all, >0 for first n, <0 for last n
;;
;; Scope
;;   Reads  : ^TX(tx)
;;
;; Notes    : Caller reads the %Tx root node for count (%Tx>0 = number returned,
;;            %Tx=0 = none found or ^TX empty), and %Tx(tx)="" for each matching ID.
;;            Assumes transaction IDs are never 0 — the collection loop's QUIT:'tx
;;            would stop early if ^TX(0) existed. Assumes n is a clean integer;
;;            no validation guards against non-numeric input to $TRANSLATE in CASE 3.
;;------------------------------------------------------------------
    NEW tx		; iterates transaction IDs, both in the collection pass and each CASE
    NEW limit	; absolute value of n, used only in CASE 3 to bound the loop
    NEW idx		; counts iterations against n/limit in CASE 2/3
    NEW arr		; local copy of all transaction IDs collected from ^TX, for filtering

    KILL %Tx
    SET %Tx=0

    ; Collect all transaction IDs into local arr for filtering
    SET tx=0
    FOR  SET tx=$ORDER(^TX(tx)) QUIT:'tx  DO
    . SET arr(tx)=""

    ; No transactions in ^TX — leave %Tx=0 and exit
    IF '$DATA(arr) QUIT

    ; CASE 1: return all, in ascending order
    IF $GET(n)="" DO  QUIT
    . SET tx=""
    . FOR  SET tx=$ORDER(arr(tx)) QUIT:tx=""  DO
    . . SET %Tx(tx)=""
    . . SET %Tx=%Tx+1

    ; CASE 2: first n, ascending — stop once idx reaches n
    IF n>0 DO  QUIT
    . SET tx="",idx=0
    . FOR  SET tx=$ORDER(arr(tx)) QUIT:(tx="")!(idx=n)  DO
    . . SET %Tx(tx)=""
    . . SET %Tx=%Tx+1
    . . SET idx=idx+1

    ; CASE 3: last n, descending — stop once idx reaches |n|
    IF n<0 DO  QUIT
    . SET limit=$TRANSLATE(n,"-","")
    . SET tx="",idx=0
    . FOR  SET tx=$ORDER(arr(tx),-1) QUIT:(tx="")!(idx=limit)  DO
    . . SET %Tx(tx)=""
    . . SET %Tx=%Tx+1
    . . SET idx=idx+1

    QUIT

    

EE(ns) ; short-form alias for ExportEntities
	D ExportEntities(ns)
	QUIT


ExportEntities(ns) ; Builds a normalized export structure of entities and their attribute labels/values under the specified namespace.
;;------------------------------------------------------------------
;; Routine  : ExportEntities (Procedure)
;;
;; Call     : DO ExportEntities(ns)
;;
;; Usage    :
;;   Iterates over entity keys in the namespace (ns) and exports
;;   attribute values into the global ^TBEnts, grouped by entity ID,
;;   entity key, and attribute key label.
;;
;; Purpose  :
;;	Builds a normalized export structure of entities and their attribute labels/values under the specified namespace.
;;	It is used to create table `tbents` in YDB OCTO and write SQL queries on it
;;	
;;
;; Scope
;;   Reads  :
;;     ^TBDR(AKEYID,ekey)        - entity attribute key registry
;;     ^TBEAVT(eid,aid,valkey)   - entity attribute value table
;;     %Keys               - attribute metadata catalog
;;
;;   Writes :
;;     ^TBEnts(eid,ekey,akey)    - exported entity attribute values
;;
;; Parameters
;;   ns     : (IN)
;;            Namespace prefix used to filter entity keys.
;;            Default is "sys" if not provided.
;;
;; Returns  :
;;   None (global structure is populated in ^TBEnts)
;;
;;------------------------------------------------------------------
	NEW ekey,nslen,eid,aid,valkey,akey,val,vk
	SET ns=$GET(ns,"sys")
	SET ekey=ns
	SET nslen=$LENGTH(ns)	
	DO BuildKeysCatalog^sapiBld("sys")
	KILL ^TBEnts
	FOR  DO  QUIT:ekey=""	
    . SET ekey=$ORDER(^TBDR(AKEYID,ekey))
    . QUIT:ekey=""
    . QUIT:$EXTRACT(ekey,1,nslen)'=ns
    . SET eid=$$GetEID^sapiGet(ekey)
    . SET aid=""
    . FOR  SET aid=$ORDER(^TBEAVT(eid,aid)) QUIT:aid=""  DO
    . . SET akey=""
    . . SET vk=$ORDER(%Keys(aid,AKEYID,""))
    . . IF vk'="" SET akey=$GET(%Keys(aid,AKEYID,vk))
    . . SET valkey=""
    . . FOR  SET valkey=$ORDER(^TBEAVT(eid,aid,valkey)) QUIT:valkey=""  DO
    . . . SET val=$$GetDictValue^sapiGet(aid,valkey)
    . . . SET ^TBEnts(eid,ekey,akey)=val

	QUIT