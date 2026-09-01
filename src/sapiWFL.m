;; ========================================================================================= 
;; ^sapiWFL - TBox/Schema assertion workflow engine - This file is part of TaxisDB Platform
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
;;=========================================================================================== 

AddKeyword(key,als) ; append an alias to ^TBKW at the next available index for key, skips duplicates
;;------------------------------------------------------------------
;; Function : AddKeyword^sapiWFL
;;
;; Call     : DO AddKeyword^sapiWFL(key,als)
;;
;; Usage    : Called by StageRecord after a schema attribute's key and alias
;;            are both known, to register the alias for lookup
;;
;; Purpose  : Adds an alias to ^TBKW for the given key, appending it at the
;;            next available index subscript. Skips silently if als is already
;;            registered under key.
;;
;; Parameters
;;   key : (IN) Canonical keyword key, e.g. "sys.attr.cardinality"
;;   als : (IN) Alias string, e.g. "cardin"
;;
;; Scope
;;   Reads  : ^TBKW(key,*)
;;   Writes : ^TBKW(key,idx)
;;
;; Notes    : ^TBKW is also used by Load^keywords to bind aliases as local
;;            variable names via indirection — the same alias registered under
;;            two DIFFERENT keys would silently clobber one binding with the
;;            other at Load time, with no error. The duplicate check below
;;            only guards against re-registering als under the SAME key; it
;;            does not detect cross-key alias collisions.
;;------------------------------------------------------------------
    NEW idx		; iterates existing aliases under key, then holds the next free index
    NEW existing	; value at each existing index, checked against als for a duplicate
    NEW isDup		; set to 1 if als is already registered under key
    SET idx=""
    SET isDup=0

    ; Scan existing aliases under key for an exact match before appending
    FOR  SET idx=$ORDER(^TBKW(key,idx)) QUIT:(idx="")!isDup  DO
    . SET existing=$GET(^TBKW(key,idx))
    . IF existing=als SET isDup=1

    IF isDup DO  QUIT
    . DO LOGDEBUG^logger("sapiWFL","AddKeyword: alias `"_als_"` already registered for key `"_key_"` — skipping")

    ; Append at next index
    SET idx=$ORDER(^TBKW(key,""),-1)    ; last used index, "" if none
    SET idx=$SELECT(idx="":0,1:idx+1)
    SET ^TBKW(key,idx)=als
    DO LOGDEBUG^logger("API","AddKeyword: ^TBKW("""_key_""")="""_als_"""")
    QUIT


TxAdd(user)
;;------------------------------------------------------------------
;; Function : TxAdd^sapiWFL
;; Purpose  : Creates and registers a new transaction record in the
;;            ^TX global, returning its unique transaction ID.
;;            Initialises the ^TX counter on first use.
;;
;; Scope
;;   Reads  : ^TX                    — transaction counter
;;   Writes : ^TX                    — incremented transaction counter
;;            ^TX(id,"dt")           — epoch timestamp of transaction
;;            ^TX(id,"user")         — user who initiated the transaction
;;
;; Parameters
;;   user   : (IN) String. The user initiating the transaction.
;;
;; Returns  : id — Integer. The newly assigned transaction ID.
;;
;; Call     : SET tx=$$TxAdd(user)
;;
;; Usage
;;   SET tx=$$TxAdd("Root")
;;
;;------------------------------------------------------------------
    NEW id,epoch
    
    ; Initialize counter if not set, starting counter at 7399
    IF '$DATA(^TX) SET ^TX=7399
    
    SET id=$INCREMENT(^TX)
    SET epoch=$$EPOCH^utils
    
    SET ^TX(id,"dt")=epoch
    SET ^TX(id,"usr")=user
    
    QUIT id
    
   
StageRecord(RecMeta,eid) ; stage one metadata record's datoms into %TBR, transactionally
;;--------------------------------------------------------------------------------------
;; Function  : StageRecord^sapiWFL
;;
;; Call     : DO StageRecord^sapiWFL(.RecMeta,eid)
;;
;; Usage    : Called by Assert^sapi for each validated record, after eid has been resolved.
;;            Return value MUST be checked by the caller — Assert^sapi relies on it to
;;            enforce its all-or-nothing batch guarantee.
;;
;; Purpose  : Resolves a single schema attribute metadata record into a staged
;;            %TBR entry. Uses the supplied eid or creates a new one, then
;;            stages every (aid,valkey) pair as a datom, with record-level
;;            atomicity via TSTART/TCOMMIT/TROLLBACK.
;;
;; Parameters
;;   RecMeta : (IN) holds one record's metadata
;;   eid   : (IN) Entity ID if the attribute already exists in schema (eid>0),
;;                or -1 if this is a new attribute
;;
;; Scope
;;   Reads  : ^TBEAVT("seq"), ^TBE
;;   Writes : ^TBEAVT("seq"), ^TBE
;;
;; Notes    : Mirrors StageRecord^api in structure. DatomAssert stages each
;;            datom indirectly; a failure there triggers TROLLBACK and discards
;;            everything this call staged, including %TBR(eid). eid is
;;            passed by value — a newly created eid is not returned to the caller.
;;------------------------------------------------------------------------------------
    NEW akey	; drives the FOR loop over metadata keys in RecMeta
    NEW val		; holds the value for the current akey
    NEW ok		; tracks whether every datom staged successfully this record
    NEW cnt		; total unique terms in TBox after a new entity is created
    NEW attrkeyval		; captures sys.attr.key value, needed for AddKeyword
    NEW attraliasval	; captures sys.attr.alias value, needed for AddKeyword
    
    SET ok=1
    SET attrkeyval=""
    SET attraliasval=""

    ; TSTART protects ^TBEAVT("seq")/^TBE writes and %TBR staging together —
    ; rollback discards everything from this record in one step
    TSTART ()

    ; Create a new entity in TBox if this metadata attribute does not yet exist
    IF eid<0 DO
    . SET eid=$INCREMENT(^TBEAVT("seq"))    ; get the next entity ID
    . SET ^TBE(eid,1)=""                    ; term is asserted into ^TBE
    . SET cnt=$INCREMENT(^TBE)              ; total unique terms in TBox

    SET akey=""
    ; Stage one datom per attribute key-value pair; stop early if any datom fails
    FOR  SET akey=$ORDER(RecMeta(akey)) QUIT:(akey="")!('ok)  DO
    . SET val=RecMeta(akey)
    . IF akey="sys.attr.key" SET attrkeyval=val
    . IF akey="sys.attr.alias" SET attraliasval=val
    . IF '$$DatomAssert(eid,akey,val) SET ok=0

    ; Register title/alias as a keyword pair once both are known for this record
    IF (attrkeyval'="")&(attraliasval'="") DO AddKeyword^sapiWFL(attrkeyval,attraliasval)

    ; COMMIT PATH — all datoms successfully staged
    IF ok DO
    . TCOMMIT
    . SET %TBR("count")=$INCREMENT(%TBR("count"))
    . DO LOGINFO^logger("sapiWFL","StageRecord: Succeeded — Total Records: "_%TBR("count"))
    ; ROLLBACK PATH — any datom failed, discard globals and staging for this record
    ELSE  DO
    . TROLLBACK
    . KILL %TBR(eid)    
    . DO LOGERROR^logger("sapiWFL","StageRecord: Rolling back — Invalid attribute record")

    QUIT ok
    

DatomAssert(eid,akey,val) ; resolve and stage one schema triplet (eid,akey,val) into the process-local array %TBR
;;---------------------------------------------------------------------------------------------------------
;; Function : DatomAssert^sapiWFL
;;
;; Call     : IF $$DatomAssert^sapiWFL(eid,akey,val)
;;
;; Usage    : Called by StageRecord once per metadata key in a schema attribute record
;;
;; Purpose  : Resolves akey to aid via GetEID, resolves val to valkey via ResolveAV,
;;            then stages (eid,aid,valkey) into %TBR. Mirrors DatomAssert^api
;;            in structure. Supports delimited multi-value expansion using "|" for
;;            attributes flagged as multi-valued. No uniqueness check needed — schema
;;            attributes do not use insert-unique constraints at this resolution stage.
;;
;; Parameters
;;   eid  : (IN) Entity ID of the schema attribute
;;   akey : (IN) Metadata key label, e.g. "sys.attr.key"
;;   val  : (IN) Metadata value, e.g. "sandbox.movie.title", or delimited
;;               e.g. "val1|val2" for multi-valued attributes
;;
;; Returns  :
;;   1 : datom successfully staged into %TBR
;;   0 : %TBR not initialised, unknown akey, or unresolved valkey
;;
;; Notes    : %TBR is a shared local array, not a global.
;;            KNOWN ISSUE — the "|" multi-value split loop below can silently
;;            drop values on double/leading delimiters (empty interior pieces
;;            are indistinguishable from end-of-string). Not yet fixed — see
;;            open discussion on intended empty-piece semantics.
;;------------------------------------------------------------------
    IF '$DATA(%TBR) DO LOGERROR^logger("sapiWFL","DatomAssert: %TBR not initialised") QUIT 0

    NEW aid		; resolved attribute entity ID for akey
    NEW valkey		; resolved value key for val
    NEW isNewVK		; ResolveAV result: 1=new key, 0=existing key, -1=resolution failed
    NEW isAllOk		; accumulated result across recursive multi-value calls
    NEW pIdx		; drives the FOR loop over "|"-delimited pieces of val
    NEW pieceVal	; one individual piece of val during multi-value expansion
    NEW modelType   ; Enumerated flag with values:
    				; "ABox" (assertion/data layer, entities are registered in ^ABE)
					; "TBox" (terminology/schema layer, entities are registered in ^TBE)
    
    SET aid=""
    SET valkey=""
    SET isAllOk=1    

    DO LOGDEBUG^logger("sapiWFL","DatomAssert: (IN) MetaKey: "_akey_",  MetaValue: "_val)

    ; Resolve the attribute entity ID for the metadata key label akey
    SET aid=$$GetEID^sapiGet(akey)
    IF aid<0 DO  QUIT 0
    . DO LOGERROR^logger("sapiWFL","DatomAssert: unknown attribute key: "_akey)

	; Multi-value case: If val contains "|" and the attribute is cardinality-one,
    ; Reject delimiter "|" outright for cardinality-one attributes — never
    ; silently store a pipe-delimited literal as a single value.    
    IF val["|"&('$$IsMultiValue^sapiVld(aid)) DO  QUIT 0
    . DO LOGERROR^logger("apiWFL","DatomAssert: '|' delimiter not allowed for cardinality-one attribute ("_aid_") — val="_val)

    ; Multi-value case: split on "|" and recurse per piece, only when the attribute is
    ; actually flagged multi-valued. DO runs the whole loop below first, then QUIT returns
    ; the accumulated result — both conditional on the IF above.
    IF (val["|")&($$IsMultiValue^sapiVld(aid)) DO  QUIT isAllOk
    . FOR pIdx=1:1 SET pieceVal=$PIECE(val,"|",pIdx) QUIT:pieceVal=""  DO
    . . IF '$$DatomAssert(eid,akey,pieceVal) SET isAllOk=0

 	; Resolve val into valkey — isNewValKey=1 new key allocated, isNewValKey=0 already existed,
    IF $$IsRefValType^sapiVld(aid) DO
    . SET modelType="TBox"
    . SET isNewVK=$$ResolveAttrRef^sapiRslv(aid,val,.valkey,modelType) ; First resolve via ResolveAttrRef then register attribute reference
    ELSE  DO
    . SET isNewVK=$$RegisterAttrVal^sapiRslv(aid,val,.valkey) ; Register attribute literal value
        
    ; isNewVK=-1 resolution failed and valkey is left "" — must not stage on failure
    IF isNewVK=-1 DO  QUIT 0
    . DO LOGERROR^logger("sapiWFL","DatomAssert: failed resolving value key for aid="_aid_", val="_val)

	; isNewVK=1 new value key is registered in the dictionary
	; or
    ; isNewVK=0 value key exists in the dictionary
    ; In both cases stage the datom in %TBR local array
    SET %TBR(eid,aid,valkey)=1
    QUIT 1

