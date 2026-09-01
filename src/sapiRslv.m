;; ============================================================================= 
;; ^sapiRslv - TBox/Schema resolve sub-routines - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 		— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;;==============================================================================

CreateNewValKey(aid,val) ; allocate and register a new lookup key for a literal value
;;-----------------------------------------------------------------------------------------
;; Function : CreateNewValKey^sapiRslv
;;
;; Call     : SET vk=$$CreateNewValKey^sapiRslv(aid,val)
;;
;; Usage    : SET vk=$$CreateNewValKey^sapiRslv(AKEYID,"sandbox.movie.title")
;;            ^TBD(AKEYID,vk)  = "sandbox.movie.title"
;;            ^TBDR(AKEYID,"sandbox.movie.title") = vk
;;
;; Purpose  : Registers a new literal value in the data type of a given attribute
;;            by allocating a fresh lookup key and persisting a forward and reverse
;;            index entry. The key is a lexicographically sortable string consisting
;;            of a fixed-width hex attribute prefix and a globally monotonic
;;            fixed-width hex sequence suffix, guaranteeing uniqueness and
;;            deterministic ordering independent of M/YottaDB numeric subscript
;;            coercion rules.
;;
;; Parameters
;;   aid : (IN) Attribute entity ID whose data type receives the new value,
;;              e.g. AKEYID for sys.attr.key
;;   val : (IN) Literal value string to register in the data type,
;;              e.g. "sandbox.movie.title"
;;
;; Scope
;;   Reads  : ^TBDR (root), ^TBDR(aid)
;;   Writes : ^TBD(aid,valkey), ^TBDR(aid,val), ^TBDR (root), ^TBDR(aid)
;;
;; Returns  :
;;   valkey : newly allocated lookup key, format "K"<3-char hex aid>.<6-char hex counter>
;;   -1     : aid or val missing
;;
;; Notes    : Does NOT check whether val is already registered — caller must guard
;;            with IsNewRangeValue or IsRangeValue before calling. Duplicate calls
;;            for the same val allocate a second key and overwrite ^TBDR, leaving
;;            the first key orphaned in ^TBD.
;;------------------------------------------------------------------
    ; Defensive parameter validation
    IF '$DATA(aid)!('$DATA(val)) DO  QUIT -1
    . DO LOGERROR^logger("sapiRslv","CreateNewValKey: missing required parameters aid="_$GET(aid,"<undef>")_", val="_$GET(val,"<undef>"))

    NEW valkey	; final assembled key, returned to caller
    NEW hexcnt	; hex-encoded, zero-padded global counter
    NEW attrHex	; hex-encoded, zero-padded aid
    NEW cnt		; decimal global counter value, offset by 100000

    ; --- attribute encoding (fixed width)
    SET attrHex=$ZCONVERT(aid,"DEC","HEX")
    SET attrHex=$TR($JUSTIFY(attrHex,3)," ","0")

    ; --- global monotonic counter starting at 100000
    SET cnt=100000+$INCREMENT(^TBDR)

    SET hexcnt=$ZCONVERT(cnt,"DEC","HEX")
    SET hexcnt=$TR($JUSTIFY(hexcnt,6)," ","0")

    ; --- final key: K + attr + sequence
    SET valkey="K"_attrHex_"."_hexcnt

    ; --- indexes
    SET ^TBD(aid,valkey)=val
    SET ^TBDR(aid,val)=valkey

    ; --- cardinality
    SET ^TBDR(aid)=$INCREMENT(^TBDR(aid))

    QUIT valkey


ResolveIsaRef(aid,refeid,valkey) ; resolve isa attribute values (key label or raw eid) against the TBox entity id
	;;------------------------------------------------------------------
	;; Function : ResolveIsaRef^sapiRslv
	;;
	;; Call     : SET result=$$ResolveIsaRef^sapiRslv(aid,refeid,.valkey)
	;;
	;; Usage    : Private helper for ResolveAttrRef^sapiRslv; not called elsewhere.
	;;
	;; Purpose  : The isa attribute (aid=ISAID) always takes a TBox type as its value,
	;;            arriving as either a key label (e.g. "sys.type.obj") or an
	;;            already-resolved eid (e.g. 900). GetEID^sapiGet normalizes either
	;;            form to an eid; the eid is then registered directly against
	;;            ^TBDR(ISAID,*) rather than going through ResolveRawEid/ResolveKeyLabel,
	;;            since isa values are TBox dictionary literals, not ABox hash references.
	;;
	;; Parameters
	;;   aid    : (IN)  ISAID (299) — passed through for symmetry/logging only
	;;   refeid : (IN)  TBox type as a key label or raw eid (e.g. "sys.type.obj", 1013)
	;;   valkey : (OUT) 1 new / 0 existing value key, or -1 on failure
	;;
	;; Notes    : valkey (by reference) is populated by RegisterAttrVal^sapiRslv
	;;------------------------------------------------------------------
	NEW eid,result,msg
	w "ResolveIsaRef: resolving isa value '"_refeid_"' for aid="_aid,!
	SET eid=$$GetEID^sapiGet(refeid)

	IF eid="" DO  QUIT -1
	. DO LOGERROR^logger("sapiRslv","ResolveIsaRef: could not resolve '"_refeid_"' to an eid — aid="_aid)

	; Defensive: eid must actually be a registered TBox entity, otherwise a
	; typo'd/unresolvable isa value would silently mint a bogus new dictionary
	; entry instead of failing loudly.
	IF '$$IsEntityRegistered^sapiVld(eid) DO  QUIT -1
	. DO LOGERROR^logger("sapiRslv","ResolveIsaRef: refeid '"_refeid_"' (eid="_eid_") is not a known TBox entity — aid="_aid)

	SET msg="ResolveIsaRef: registering isa value eid="_eid_" (from refeid="_refeid_") for aid="_aid
	DO LOGDEBUG^logger("sapiRslv",msg)
	SET result=$$RegisterAttrVal^sapiRslv(aid,eid,.valkey)
	QUIT result


ResolveAttrRef(aid,refeid,valkey,modelType) ; resolve the value key for an ABox reference attribute value
	;;----------------------------------------------------------------------------------------------------
	;; Function : ResolveAttrRef^sapiRslv
	;;
	;; Call     : SET isNewValKey=$$ResolveAttrRef^apiRslv(aid,refeid,.valkey)
	;;
	;; Usage    : ABox counterpart to ResolveAttrRef^sapiRslv. Called by
	;;            DatomAssert^apiWFL and DatomRetract^apiWFL, ONLY for
	;;            attributes where IsRefValType^sapiVld(aid) is true.
	;;
	;; Purpose  : Resolves the lookup key (valkey) for a reference-typed
	;;            attribute (aid). refeid may arrive as any of three forms,
	;;            each resolved by its own function below:
	;;              • isa attribute value (label or eid) -> ResolveIsaRef
	;;              • an ordinary key label              -> ResolveKeyLabel
	;;              • an already-resolved EID            -> ResolveRawEid
	;;
	;; Parameters
	;;   aid    	: (IN)  Reference-typed attribute entity ID
	;;   refeid 	: (IN)  ABox entity ID in one of the three forms above
	;;	 modelType	: (IN)  Model layer containing the entity "ABox" or "TBox"
	;;   valkey 	: (OUT) Lookup value key for refeid within aid's data type
	;;
	;; Returns  :
	;;   1  — new value key allocated
	;;   0  — existing value key reused
	;;  -1  — cannot be resolved; valkey is left ""
	;;----------------------------------------------------------------------------------------------------
	NEW result	
	SET valkey=""       ; final value if resolution fails

	; refeid is handled by exactly one of the two branches below:
	;   isa value  -> ResolveIsaRef (label or raw TBox eid, registered directly)
	;   key label  -> resolved to an eid via GetEID^apiGet
	;   raw EID    -> validated directly (format, then existence)
	; every branch either registers the value (success) or sets result=RFailed;
	; valkey is only ever populated by RegisterAttrVal^sapiRslv, so it stays "" on every failure path.
	IF aid=ISAID SET result=$$ResolveIsaRef(aid,refeid,.valkey)
	ELSE  IF $$IsRangeValue^sapiVld(AKEYID,refeid) SET result=$$ResolveKeyLabel(aid,refeid,.valkey,modelType)
	ELSE  SET result=$$ResolveRawEid(aid,refeid,.valkey,modelType)

	QUIT result


ResolveKeyLabel(aid,refeid,valkey,modelType) ; resolve an ordinary key label to an eid and register
	;;------------------------------------------------------------------
	;; Function : ResolveKeyLabel^sapiRslv
	;;
	;; Call     : SET result=$$ResolveKeyLabel^sapiRslv(aid,refeid,.valkey)
	;;
	;; Usage    : Private helper for ResolveAttrRef^sapiRslv
	;;
	;; Purpose  : Resolves an ordinary key label (e.g. a sys.attr.key alias)
	;;            to an eid via GetEID^apiGet or GetEID^sapiGet and registers the value key.
	;;
	;; Parameters
	;;   aid     	: (IN) Reference-typed attribute entity ID
	;;   refeid  	: (IN) Ordinary key label to resolve
	;;   modelType	: (IN) Model layer containing the entity "ABox" or "TBox"
	;;	 valkey	    : (OUT) 1 new / 0 existing value key, or -1 if refeid is invalid or does not exist
	;;
	;;
	;; Notes    	: valkey (by reference) is populated by RegisterAttrVal^sapiRslv.
	;;------------------------------------------------------------------
	NEW eid 		; eid resolved from refeid, or <=0 if not found
	NEW result 		; status code to return
	NEW msg 		; debug log message text
	NEW RFailed		; flag to return failure
	
	SET RFailed=-1
	IF modelType="ABox" SET eid=$$GetEID^apiGet(refeid)
	ELSE  SET eid=$$GetEID^sapiGet(refeid)
	
	IF eid>0 DO  ; refeid resolved to an existing eid
	. SET msg="ResolveKeyLabel: resolved entity key '"_refeid_"' -> eid="_eid_" for aid="_aid
	. DO LOGDEBUG^logger("sapiRslv",msg)
	. SET result=$$RegisterAttrVal^sapiRslv(aid,eid,.valkey)
	ELSE  SET result=RFailed ; refeid did not resolve to an eid
	QUIT result ; new/existing/failed status


ResolveRawEid(aid,refeid,valkey,modelType) ; validate refeid as an existing eid and register
	;;-------------------------------------------------------------------------------------
	;; Function : ResolveRawEid^sapiRslv
	;;
	;; Call     : SET result=$$ResolveRawEid^sapiRslv(aid,refeid,isEID,.valkey)
	;;
	;; Usage    : Private helper for ResolveAttrRef^apiRslv; not called elsewhere.
	;;
	;; Purpose  : Validates refeid as a well-formed, existing ABox eid,
	;;            then registers the reference value key.
	;;
	;; Parameters
	;;   aid     	: (IN) Reference-typed attribute entity ID
	;;   refeid  	: (IN) Candidate ABox entity EID in raw format
	;;   modelType	: (IN) Model layer containing the entity "ABox" or "TBox"
	;;	 valkey	    : (OUT) 1 new / 0 existing value key, or -1 if refeid is invalid or does not exist
	;;
	;; Notes    	: valkey (by reference) is populated by RegisterAttrVal^sapiRslv
	;;------------------------------------------------------------------
	NEW result 				; status code to return
	NEW msg1,msg2   		; error log message text
	NEW RFailed				; flag to return failure
	NEW isValidEID  		; predicate to apply for a valid raw EID for an entity in ABox or TBox
	NEW isEntityRegistered 	; predicate to check if the entity has been registered in ABox or TBox
	
	SET RFailed=-1
	SET msg1="ResolveRawEID: invalid EID format '"_refeid_"' for aid="_aid
	
	IF modelType="ABox" DO 
	. SET isValidEID=$$IsEID^utils(refeid)
	. SET isEntityRegistered=$$IsEntityRegistered^apiVld(refeid)
	. SET msg2="ResolveRawEID: referenced entity has not been registered in ABox'"_refeid_"' for aid="_aid
	
	IF modelType="TBox" DO
	. SET isValidEID=(refeid=+refeid)
	. SET isEntityRegistered=$$IsEntityRegistered^sapiVld(refeid)
	. SET msg2="ResolveRawEID: referenced entity has not been registered in TBox'"_refeid_"' for aid="_aid

	IF 'isValidEID DO  ; malformed EID
	. SET result=RFailed
	. DO LOGERROR^logger("sapiRslv",msg1)
	ELSE  IF 'isEntityRegistered DO  ; well-formed but not persisted
	. SET result=RFailed
	. DO LOGERROR^logger("sapiRslv",msg2)
	ELSE  DO
	. DO LOGDEBUG^logger("sapiRslv","ResolveRawEID: resolved entity with eid="_refeid_" for aid="_aid) 
	. SET result=$$RegisterAttrVal^sapiRslv(aid,refeid,.valkey) ; refeid valid & exists
	QUIT result ; new/existing/failed status


	
RegisterAttrVal(aid,value,valkey) ; register the value key for (aid,value)
;;----------------------------------------------------------------------------------------------------
;; Function : RegisterAttrVal^sapiRslv
;;
;; Call     : SET isNewValKey=$$RegisterAttrVal^sapiRslv(aid,value,.valkey)
;;
;; Usage    : Shared register allocator for both literal and reference-typed
;;            attribute values. Literal values are passed in as-is; reference values
;;            must already be resolved to an eid by the caller (ResolveKeyLabel^sapiRslv /
;;            ResolveRawEid^sapiRslv) before reaching this routine.
;;
;; Parameters
;;   aid 	: (IN) Attribute entity ID, pre-resolved by caller. Must be a
;;              literal-typed attribute — e.g. 210 for "sandbox.movie.title".
;;
;;   value 	: (IN) Literal value or reference
;;	 valkey	: (OUT)
;;
;;
;; Notice  	:  Common to both TBox and ABox. Called by DatomAssert^sapiWFL,
;;            DatomAssert^apiWFL, and DatomRetract^apiWFL
;;
;; Returns  :
;;   1  : new value key allocated   (CASE 1)
;;   0  : existing value key reused (CASE 2)
;;  -1  : resolution failed valkey is left ""
;;------------------------------------------------------------------
    NEW isNewValKey	; result returned to caller
    NEW RFailed     ; Resolve Failed
    NEW RNew        ; Resolve New
    NEW RExists     ; Resolve Existing

    SET RFailed=-1
    SET RNew=1
    SET RExists=0

    SET valkey="" ; this is the value it takes if the function fails to resolve the reference
    SET isNewValKey=RExists

    ; Is this a new value for this attribute? If so, allocate a new key and register it.
    IF $$IsNewRangeValue^sapiVld(aid,value) DO  QUIT isNewValKey
    . SET valkey=$$CreateNewValKey(aid,value)
    . IF valkey<0 DO
    . . DO LOGERROR^logger("sapiRslv","RegisterAttrVal: failed allocating value key for aid="_aid_", value="_value)
    . . SET isNewValKey=RFailed
    . ELSE  DO
    . . SET isNewValKey=RNew
    . . DO LOGDEBUG^logger("sapiRslv","RegisterAttrVal: (RES)-NEW ^TBDR("_aid_","_value_") -> "_valkey)

    ; Is this value already registered for this attribute? If so, reuse the existing key.
    IF $$IsRangeValue^sapiVld(aid,value) DO  QUIT isNewValKey
    . SET valkey=$$GetValKey^sapiGet(aid,value)
    . IF valkey="" DO
    . . DO LOGERROR^logger("sapiRslv","RegisterAttrVal: ^TBDR index missing aid="_aid_", value="_value)
    . . SET isNewValKey=RFailed
    . ELSE  DO
    . . DO LOGDEBUG^logger("sapiRslv","RegisterAttrVal: (RES)-EXISTS ^TBDR("_aid_","_value_") -> "_valkey)

	; SAFETY NET — should be unreachable now that IsNewRangeValue/IsRangeValue are
    ; exact complements. If this ever fires, that invariant has been broken again;
    ; fail loudly rather than silently returning RExists with an empty valkey.
    DO LOGERROR^logger("sapiRslv","RegisterAttrVal: neither new nor existing — invariant broken, aid="_aid_", value="_value)
    SET isNewValKey=RFailed

    QUIT isNewValKey