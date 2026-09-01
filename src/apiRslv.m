;; ============================================================================= 
;; ^apiRslv - ABox Resolve Subroutines - This file is part of TaxisDB Platform
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

CountUniqueAttributes(ResolvedRec,count,firstAid)
;;------------------------------------------------------------------
;; Procedure : CountUniqueAttributes^apiRslv
;; Call      : DO CountUniqueAttributes^apiRslv(.ResolvedRec,.count,.firstAid)
;;
;; Purpose   : Scans ResolvedRec in a single pass and counts how many
;;             assertion attributes carry a uniqueness constraint
;;             (UNQINSERT or UNQUPSERT). Returns the count and the
;;             first unique aid found.
;;
;;             This routine only counts — it does not resolve, lookup,
;;             stage, or validate. It exists solely to inform
;;             ResolveByUnique() which resolution path to take.
;;
;; Parameters
;;   ResolvedRec : (IN)  Resolved record — assertions only
;;   count       : (OUT) Number of unique attributes found
;;   firstAid    : (OUT) Aid of first unique attribute found
;;                       "" if count=0
;;
;; Returns  : Nothing (procedure)
;;------------------------------------------------------------------
    NEW aid
    SET count=0
    SET firstAid=""
    SET aid=""
    FOR  SET aid=$ORDER(ResolvedRec("+",aid)) QUIT:aid=""  DO
    . IF $$GetUniqueMode^sapiGet(aid) DO
    . . SET count=count+1
    . . IF firstAid="" SET firstAid=aid
    QUIT


ResolveAttr(ns,akey,AttrCache) ; Resolve a single attribute key to its internal attribute ID
    ;; ----------------------------------------------------------------------------------------------
    ;; Procedure : $$ResolveAttr^apiRslv
    ;;
    ;; Purpose:		Resolve a single attribute name to its internal attribute ID,
    ;;   			trying the namespace prefixed key first, then try with a bear key
    ;;
    ;; Inputs:
    ;;   ns        - Namespace prefix path of arbitrary depth
    ;;   akey      - Attribute name to resolve (e.g. "movie.title").
    ;;   AttrCache - Attributes resolution cache (see ResolveRecAttrs).
    ;;
    ;; Output:
    ;;   Returns aid - internal attribute ID (any number > 0), or 0 if unresolvable.
    ;; ----------------------------------------------------------------------------------------------
    NEW aid
    ; +$GET(...) coersion +""=0
    SET aid=+$GET(AttrCache(ns_"."_akey)) 	; try ns prefixed key 	e.g. sandbox. movie.genre --> 700
    IF aid=0 SET aid=+$GET(AttrCache(akey))	; try with a bear key  	e.g. sys.attr.id    	  --> 277

	; both attribute resolution methods failed
    IF aid=0 DO LOGERROR^logger("apiRslv","ResolveRecAttrs: unresolvable attribute name '"_akey_"' for ns="_ns_" — aborting record resolution")
    QUIT aid


ResolveRecAttrs(ns,dataRef,AttrCache,ResolvedRec) ; Resolve a single record's attribute names into internal attribute IDs building ResolvedRec(op,aid)=value
    ;; ------------------------------------------------------------------------------------------------------------------
    ;; Function : $$ResolveRecAttrs^apiRslv
    ;;
    ;; Purpose:    	Resolve a single record's attribute names into internal attribute IDs
    ;;   			building ResolvedRec(op,aid)=value
    ;;
 	;; Parameters:
    ;;   ns         : (IN)  	Namespace prefix path of arbitrary depth
    ;;
    ;;   dataRef    : (IN)  	Named reference e.g. "Data(17)"
    ;;                      	that gives access to record No.17 in local array Data
    ;;
    ;;   AttrCache  : (IN)  	Attribute resolution cache, read-only here:
    ;;                      	AttrCache("sandbox.movie.title")=700
    ;;                      	AttrCache("sandbox.movie.genre")=701
    ;;
    ;;	ResolvedRec : (IN/OUT)	Starts empty, then nodes are stored - ResolvedRec(op,attributeId)=value
    ;;
    ;; 							Example:
    ;;   							Data(1,"movie.title")="The Reader"
    ;;   							Data(1,"movie.releaseYear")=2008
    ;;   							Data(1,"movie.genre","-")="thriller"
    ;;
    ;;   						becomes
    ;;   							ResolvedRec("+",700)="The Reader"
    ;;   							ResolvedRec("+",702)=2008
    ;;   							ResolvedRec("-",701)="thriller"
    ;;
    ;; Returns:
    ;;		 1 - if every attribute name resolved 
    ;;		 0 - if any attribute could not be resolved
    ;; ------------------------------------------------------------
    NEW akey,aid,ok
    SET akey=""
    SET ok=1

    ; Iterate the attribute-name subscripts of dataRef; resolve each to an aid via $$ResolveAttr
    ; Loop exits when akey is exhausted, or stops immediately on the first unresolvable attribute (ok=0)
    ; remaining attributes are never attempted.
    FOR  SET akey=$ORDER(@dataRef@(akey)) QUIT:(akey="")!(ok=0)  DO
    . SET aid=$$ResolveAttr(ns,akey,.AttrCache)
    . IF aid=0 SET ok=0 QUIT
    . IF $DATA(@dataRef@(akey))#10 SET ResolvedRec("+",aid)=@dataRef@(akey)
    . IF $DATA(@dataRef@(akey,"-")) SET ResolvedRec("-",aid)=$GET(@dataRef@(akey,"-"))

    QUIT ok


ResolveLiveEID(aid,val) ; find the live eid whose current value for aid equals val, via ^TBDR/^AVET
;;------------------------------------------------------------------
;; Function : $$ResolveLiveEID^apiGet
;;
;; Purpose  : Resolve val to its valkey under aid via ^TBDR, then walk ^AVET
;;            candidates for that (aid,valkey) and return the one still live.
;;
;; Parameters
;;   aid : (IN) Attribute ID whose value dictionary/index to search.
;;   val : (IN) Literal value to resolve (natural key or unique attr value).
;;
;; Returns  :
;;   eid — the live candidate entity ID
;;   0   — no valkey registered for aid/val, or no live candidate found
;;------------------------------------------------------------------
    NEW valkey		; resolved dictionary key for val under aid
    NEW candidate	; current eid candidate walked from ^AVET
    NEW eid			; live eid found, or 0

    SET eid=0
    SET valkey=$GET(^TBDR(aid,val))
    IF valkey'="" DO
    . SET candidate=""
    . ; Iterate all eid candidates under (aid,valkey) in order — stop
    . ; at the first one whose claim is still live. Presence in ^AVET
    . ; only means "held this value at some point," not "holds it now."
    . FOR  SET candidate=$ORDER(^AVET(aid,valkey,candidate)) QUIT:(candidate="")!eid  DO
    . . IF $$GetCurrentVK^apiGet(candidate,aid)=valkey SET eid=candidate

    QUIT eid


ResolveOwnership(aid,ResolvedRec) ; resolve target entity for one unique attribute via UNQINSERT/UNQUPSERT semantics
;;------------------------------------------------------------------------------------------------------------------
;; Function : $$ResolveOwnership^apiRslv
;;
;; Purpose  : Resolves the target entity EID for a single unique
;;            attribute by applying UNQINSERT or UNQUPSERT semantics.
;;
;; Parameters
;;   aid         : (IN)  Attribute entity ID (must be unique)
;;   ResolvedRec : (IN)  Resolved record
;;
;; Returns  :
;;   			eid — successfully resolved or generated
;;   			0   — empty value (internal error) or UNQINSERT violation
;;------------------------------------------------------------------
    NEW val			; value supplied for this unique attribute    
    NEW mode		; UNQINSERT or UNQUPSERT
    
    NEW ownereid	; eid currently holding valkey, if any (may be stale)
    NEW ownerIsLive	; whether ownereid's claim on valkey is still active
    ;
    ; ownereid/ownerIsLive: ^AVET keeps a subscript for every eid that ever claimed valkey,
    ; even a dead one — e.g. F23: Carol claims personal@example.com, retracts it, then Erin
    ; claims the same value. Both Carol's and Erin's eids now sit under the same (aid,valkey),
    ; in no guaranteed order, but only Erin's claim is live. Taking whichever eid $ORDER finds
    ; first would risk picking Carol — ResolveLiveEID walks all candidates and returns the one
    ; whose claim is still live (0 if none is), so ownereid is always the true current owner,
    ; not just the first subscript. This distinction changes the outcome by mode:
    ;   - UNQINSERT: no live owner means the value is free again — allow a new entity instead
    ;     of rejecting forever.
    ;   - UNQUPSERT: no live owner means the prior identity released this value — attach a new
    ;     eid instead of silently merging into a dead identity
    ;
    
    NEW eid			; resolved or generated entity ID

    SET eid=0
    SET val=$GET(ResolvedRec("+",aid))
    SET mode=$$GetUniqueMode^sapiGet(aid)

    IF val="" DO  QUIT 0
    . DO LOGERROR^logger("apiRslv","ResolveOwnership: internal error — empty value for unique attribute ("_aid_")")
    
	IF $$IsRangeValue^sapiVld(aid,val) DO
    . SET ownereid=$$ResolveLiveEID(aid,val)
    . SET ownerIsLive=(ownereid'=0)
    .
    . ; UNQINSERT — strict insert, never merges. Violation only while owner is still live.
    . IF mode=UNQINSERTID,ownerIsLive DO  QUIT
    . . SET eid=0
    . . DO LOGERROR^logger("apiRslv","ResolveOwnership: insert-unique violation — ("_aid_","_val_") already owned by ("_ownereid_")")
    .
    . ; UNQINSERT, no live owner — value is free again, treat as a brand-new entity.
    . IF mode=UNQINSERTID,'ownerIsLive DO  QUIT
    . . SET eid=$$GENID^utils
    . . DO LOGDEBUG^logger("apiRslv","ResolveOwnership: insert-unique — value released or new, generated EID "_eid)
    .
    . ; UNQUPSERT, owner still live — this claimant IS that same real-world identity.
    . IF mode=UNQUPSERTID,ownerIsLive DO  QUIT
    . . SET eid=ownereid
    . . DO LOGDEBUG^logger("apiRslv","ResolveOwnership: upsert-unique merge → existing EID ("_eid_")")
    .
    . ; UNQUPSERT, no live owner — a new claimant here is a DIFFERENT identity, so mint
    . ; a fresh eid instead of merging into the dead owner.
    . IF mode=UNQUPSERTID,'ownerIsLive DO  QUIT
    . . SET eid=$$GENID^utils
    . . DO LOGDEBUG^logger("apiRslv","ResolveOwnership: upsert-unique — prior identity released, generated new EID "_eid)

    ; val has never been registered at all — new entity, regardless of mode.
    ELSE  DO
    . SET eid=$$GENID^utils
    . DO LOGDEBUG^logger("apiRslv","ResolveOwnership: new entity — generated EID "_eid)

    QUIT eid


ResolveDesignatedUnique(ResolvedRec) ; resolve target entity via caller-specified unique attribute (sys.attr.resolvedby)
;;------------------------------------------------------------------
;; Function : $$ResolveDesignatedUnique^apiRslv
;;
;; Purpose  : Resolves the target entity when multiple unique
;;            attributes are present and the caller has supplied
;;            sys.attr.resolvedby to identify which one to use.
;;
;;            Performs four validations before delegating to
;;            ResolveOwnership:
;;
;;              1. Attribute key exists in schema
;;              2. Attribute is unique (UNQINSERT or UNQUPSERT)
;;              3. Attribute is present in ResolvedRec
;;              4. Attribute value is non-empty
;;
;;            Only if all four pass does it call ResolveOwnership.
;;
;; Parameters
;;   ResolvedRec : (IN)  Resolved record — sys.attr.resolvedby already
;;                       present; read here, killed by the caller
;;                       (ResolveByUnique) once this returns
;;
;; Returns  :
;;   eid — successfully resolved or generated
;;   0   — any validation failure or UNQINSERT violation
;;------------------------------------------------------------------
    NEW attrkey	; sys.attr.resolvedby value — schema key naming the attribute to resolve by
    NEW aid		; resolved attribute ID for attrkey
    NEW val		; value of that attribute in ResolvedRec
    NEW eid		; resolved or generated entity ID

    SET eid=0
    SET attrkey=$GET(ResolvedRec("+",RESOLVEDBYID))

    ; Validation 1 — attribute key must exist in schema
    SET aid=$$GetEID^sapiGet(attrkey)
    IF aid<1 DO  QUIT 0
    . DO LOGERROR^logger("apiRslv","ResolveDesignatedUnique: resolvedby attribute is not registered in the schema — "_attrkey)

    ; Validation 2 — attribute must be unique
    IF '$$GetUniqueMode^sapiGet(aid) DO  QUIT 0
    . DO LOGERROR^logger("apiRslv","ResolveDesignatedUnique: resolvedby attribute is not unique — "_attrkey)

    ; Validation 3 — attribute must be present in record
    IF '$DATA(ResolvedRec("+",aid)) DO  QUIT 0
    . DO LOGERROR^logger("apiRslv","ResolveDesignatedUnique: resolvedby attribute is missing from record — "_attrkey)

    ; Validation 4 — value must be non-empty
    SET val=$GET(ResolvedRec("+",aid))
    IF val="" DO  QUIT 0
    . DO LOGERROR^logger("apiRslv","ResolveDesignatedUnique: resolvedby attribute has an empty value — "_attrkey)

    QUIT $$ResolveOwnership(aid,.ResolvedRec)


ResolveByEID(ResolvedRec) ; resolves target entity via explicit raw EID reference using sys.attr.id
;;------------------------------------------------------------------------------------------------
;; Function  : $$ResolveByEID^apiRslv
;;
;; Purpose   : ResolveTargeEntity/Path 0 — explicit raw EID reference.
;;             Resolves the target entity using the value of sys.attr.id attribute
;;
;; Parameters
;;   ResolvedRec : (IN/OUT)  Resolved record — sys.attr.id node is killed
;;
;; Returns   	 :
;;             		eid resolved entity ID
;;             		0   failed to resolve
;;------------------------------------------------------------------
    NEW idval	; raw entity ID value from ResolvedRec
    NEW eid		; resolved entity ID, or 0 on failure

    SET idval=$GET(ResolvedRec("+",SYSATTRID))    
    
    ; remove sys.attr.id node ResolvedRec node — it must not reach DatomAssert as entity fact
    KILL ResolvedRec("+",SYSATTRID) 

    ; Validates both format (structurally valid EID) and existence (must exist in ^EATV)
    ; $$GetEID logs both succes and failure messages
    SET eid=$$GetEID^apiGet(idval)    
    
    QUIT eid


ResolveByNaturalKey(ResolvedRec) ; resolve target entity via sys.attr.key. It finds or it creates EID
;;------------------------------------------------------------------
;; Function : ResolveByNaturalKey^apiRslv
;;
;; Purpose  : ResolveTargeEntity/Path 1 — natural key resolution.
;;            Resolves the target entity from sys.attr.key using
;;            find-or-create semantics.
;;
;;            If the key is already registered → return its existing eid.
;;            If the key is not found → call GENID, create new entity that 
;;            is anchored to this sys.attr.key value on all future transactions.
;;
;; Parameters
;;   ResolvedRec : (IN)  Resolved record
;;
;; Returns  	 :
;;   			 	eid — resolved or generated entity ID (find-or-create never fails)
;;------------------------------------------------------------------
    NEW keyval	; sys.attr.key value read from ResolvedRec
    NEW eid		; resolved or generated entity ID

    SET keyval=$GET(ResolvedRec("+",AKEYID)) ; it must reach DatomAssert as entity fact
    SET eid=$$GetEID^apiGet(keyval)
    
    IF eid>0 DO
    . DO LOGDEBUG^logger("apiRslv","ResolveByNaturalKey: resolved via sys.attr.key — "_keyval)
    ELSE  DO
    . SET eid=$$GENID^utils
    . DO LOGDEBUG^logger("apiRslv","ResolveByNaturalKey: new entity — generated EID "_eid)
	
    QUIT eid


ResolveByUnique(ResolvedRec) ; resolves target entity via a unique attribute optionally using sys.attr.resolvedby. It finds or it creates EID
;;--------------------------------------------------------------------------------------------------------------
;; Function : ResolveByUnique^apiRslv
;;
;; Purpose  : ResolveTargeEntity/Path 2 — resolve target entity via a unique attribute optionally using sys.attr.resolvedby. 
;;            It finds or it creates EID. Dispatches to the correct resolution sub-path based
;;            on the count of unique attributes present in ResolvedRec and the presence of sys.attr.resolvedby.
;;
;; Parameters
;;   ResolvedRec : (IN/OUT)  Resolved record — sys.attr.resolvedby node if present is killed
;;
;; Returns  	 :
;;   				eid — resolved or generated entity ID
;;   				0   — any resolution or validation failure
;;----------------------------------------------------------------------------------------------------------------
    NEW count		; number of unique attributes present in ResolvedRec
    NEW firstAid	; aid of the sole unique attribute, when count=1
    NEW eid			; resolved or generated entity ID
    

    SET eid=0 		; initialize eid, assume resolve failed
    DO CountUniqueAttributes(.ResolvedRec,.count,.firstAid)

    ; resolvedby attribute present but no unique attributes — error
    IF count=0,$DATA(ResolvedRec("+",RESOLVEDBYID)) DO  QUIT 0
    . DO LOGERROR^logger("apiRslv","ResolveByUnique: sys.attr.resolvedby specified but no unique attributes were supplied in the transaction record.")

    ; No unique attributes and no resolvedby attribute — anonymous entity
    IF count=0 DO  QUIT eid
    . SET eid=$$GENID^utils
    . DO LOGWARNING^logger("apiRslv","ResolveByUnique: generated EID "_eid)

    ; Exactly one unique attribute — pass firstAid directly to ResolveOwnership
    IF count=1 QUIT $$ResolveOwnership(firstAid,.ResolvedRec)

    ; More than one unique attribute — resolvedby required
    IF '$DATA(ResolvedRec("+",RESOLVEDBYID)) DO  QUIT 0
    . DO LOGERROR^logger("apiRslv","ResolveByUnique: multiple unique attributes require sys.attr.resolvedby")

	SET eid=$$ResolveDesignatedUnique(.ResolvedRec)

    ; remove sys.attr.resolvedby ResolvedRec node — it must not reach DatomAssert as entity fact
    IF $DATA(ResolvedRec("+",RESOLVEDBYID)) DO
    . KILL ResolvedRec("+",RESOLVEDBYID) 

    QUIT eid


ResolveTargetEntity(ResolvedRec) ; Resolve target entity ID for the data record
;;------------------------------------------------------------------
;; Function : ResolveTargetEntity^apiRslv
;;
;; Purpose  : Resolve target entity ID for the data record
;;
;; Parameters
;;   ResolvedRec : (IN/OUT) Resolved record — control attributes consumed
;;
;; Returns  :
;;   			eid  — resolved target entity ID on success
;;   			  0  — any resolution failure
;;------------------------------------------------------------------
    NEW eid		; target entity id

    SET eid=0

    ; Path 0 — sys.attr.id (explicit raw EID)
    IF $DATA(ResolvedRec("+",SYSATTRID)) SET eid=$$ResolveByEID(.ResolvedRec)
    ; Path 1 — sys.attr.key (bare key)
    ELSE  IF $DATA(ResolvedRec("+",AKEYID)) SET eid=$$ResolveByNaturalKey(.ResolvedRec)
    ; Path 2 — unique attribute resolution
    ELSE  SET eid=$$ResolveByUnique(.ResolvedRec)

    QUIT eid


