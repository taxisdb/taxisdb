;; ===================================================================================== 
;; ^apiGet - Subroutines for accesing ABox globals - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 		— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;;=======================================================================================


GetDictValue(aid,valkey) ; Get the value for an (aid,valkey) pair from TBD
;;------------------------------------------------------------------------------------------------
;; Function	: GetDictValue^sapiGet
;;
;; Usage    : w $$GetDictValue(210,"00A.18716") --> ???
;;			
;; Purpose  : Resolves a value key to its human-readable value string
;;            Branches on:
;;              Literal   — ^TBD(aid,valkey) = value string directly
;;              Reference — ^TBD(aid,valkey) = eid → ^EATV(eid,AKEYID,vk,*) → ^TBD(AKEYID,vk)
;;
;; Returns  : Value string  
;;            "" if not found

;; Notice   : ^TBD is a shared value dictionary
;; 		it stores literal attribute values for both TBox (schema) and ABox (entity) attributes under a single global. 
;; 		A literal lookup (GetDictValue) resolves directly against ^TBD(aid,valkey) regardless of which model 
;; 		the attribute belongs to.
;; 		Reference-type attributes are the exception. When aid is a reference type (IsRefValType^sapiVld), 
;; 		^TBD(aid,valkey) stores the referenced entity's eid, not a literal string. 
;; 		Resolving that reference to its current value requires an additional lookup into ^EATV or ^TBEAVT.
;; 		Two GetDictValue implementations exist accordingly — 
;; 		GetDictValue^apiGet (ABox, reads ^EATV) and GetDictValue^sapiGet (TBox, reads ^TBEATV)
;; --------------------------------------------------------------------------------------------------------------
    NEW refeid,vk
     
    ;; Attribute accepts literal values
    IF '$$IsRefValType^sapiVld(aid) QUIT $GET(^TBD(aid,valkey))
        
    ;This attribute accepts reference values.
    SET refeid=$GET(^TBD(aid,valkey))
    
    ; For sys.attr.isa that accepts TBox reference values: sys.type.obj, sys.type.assoc....
    IF aid=ISAID QUIT $$GetDictValue^sapiGet(aid,valkey)
    
    ; Other ABox entity references
    IF refeid="" QUIT "" ; Failed to find it
    
    SET vk=$ORDER(^EATV(refeid,AKEYID,""))    
    IF vk="" QUIT "" ; Failed to find it
    
    QUIT $GET(^TBD(AKEYID,vk))


GetCurrentVK(eid,aid)
;;------------------------------------------------------------------
;; Function : GetCurrentVK^apiGet
;;
;; Purpose  : Returns the currently active valkey for a given (eid,aid)
;;            pair by reading ^EATV at the most recent transaction.
;;
;; Parameters
;;   eid     : (IN) Entity ID
;;   aid     : (IN) Attribute ID
;;
;; Returns  :
;;   valkey  — current valkey (fact is currently TRUE)
;;
;;   0       — valkey found but its most recent state is a retraction (fact is currently FALSE)
;;
;;  -1       — valkey not found for an entity with this attribute, i.e. for this (eid,aid) pair
;;------------------------------------------------------------------
    NEW curtx,vk1,vk2

    ; Find the most recent tx for this (eid,aid) — O(1) via descending $ORDER
    SET curtx=$ORDER(^EATV(eid,aid,""),-1)

	; valkey not found for an entity with this attribute, i.e. for this (eid,aid) pair
    IF curtx="" DO  QUIT -1 ; return -1
    . DO LOGDEBUG^logger("apiGet","GetCurrentVK: valkey Not found for ("_eid_","_aid_")")
    
    ; The datom (eid,aid,tx,vk) has been set currently set to TRUE a revision or assertion
    SET vk1=$ORDER(^EATV(eid,aid,curtx,""))    
    IF $GET(^EATV(eid,aid,curtx,vk1))=1 QUIT vk1 ; return the valkey

	; The valkey has been currently retracted, i.e. the datom (eid,aid,tx,vk) has been set to FALSE
    SET vk2=$ORDER(^EATV(eid,aid,curtx,vk1))
    IF vk2="" DO  QUIT 0 ; return 0
    . DO LOGDEBUG^logger("apiGet","GetCurrentVK: retracted, ("_eid_","_aid_") is currently false")

    QUIT vk2


GetKey(eid)
;;------------------------------------------------------------------
;; Function 	: GetKey^apiGet
;;
;; Purpose  	: Fetch a human-readable key for an ABox entity
;;
;; Parameters 	:
;;		eid		: ABox entity ID
;;
;; Returns  	: 
;;					key that has been assigned to entity with the sys.attr.key attribute 
;;            		""  if not found
;;------------------------------------------------------------------
    NEW valkey
    SET valkey=$ORDER(^EATV(eid,AKEYID,$ORDER(^EATV(eid,AKEYID,"")),""))
    IF valkey="" QUIT ""
    QUIT $GET(^TBD(AKEYID,valkey))


GetKeyForRefEID(refeid)
;;------------------------------------------------------------------
;; Function : GetKeyForRefEID^apiGet
;;
;; Purpose  : Given a target entity ID that a reference-typed attribute points to, 
;;			  try to fetch a human-readable key.
;;
;;            Falls back to the raw eid if the target has no live key datom assigned with sys.attr.key
;;
;; Parameters
;;   refeid  : (IN) Target entity ID that a reference attribute points to
;;
;; Returns   : Human-readable key of the referenced entity, 
;;			   or the raw eid as a fallback
;;------------------------------------------------------------------
    NEW vk,label
        
    IF (refeid=+refeid),$$IsEntityRegistered^sapiVld(refeid) DO  QUIT $SELECT(label'="":label,1:refeid)
	. SET label=$$GetKey^sapiGet(refeid)
    
    SET vk=$$GetCurrentVK^apiGet(refeid,AKEYID)
    IF (vk=-1)!(vk=0) QUIT refeid
    SET label=$$GetDictValue^sapiGet(AKEYID,vk)
    
    QUIT $SELECT(label'="":label,1:refeid)


LookupEID(val,akey)
;;------------------------------------------------------------------
;; Function : LookupEID^apiGet
;; Call     : SET eid=$$LookupEID^apiGet(val,akey)
;;
;; Purpose  : Convenience wrapper around GetEID for callers who have
;;            a unique attribute's key STRING (e.g. "sandbox.movie.imdbid")
;;            rather than its numeric aid.
;;
;;            Resolves akey to a numeric aid via GetEID^sapi, then
;;            delegates to GetEID(val,aid) — Path 1 or 2 resolution only.
;;
;;            GetEID itself is intentionally left unchanged and still
;;            requires a numeric aid — this wrapper exists so callers
;;            typing interactively, or scripting against schema by
;;            name, don't need a separate GetEID^sapi call every time.
;;
;; Parameters
;;   val     : (IN) Unique attribute value, e.g. "tt0011100"
;;   akey    : (IN) unique attribute name e.g. "sandbox.movie.imdbid"
;;				    if omitted, will attempt to resolve val for sys.attr.key attribute ($$GetEID Path 1)
;;
;; Returns  :
;;   eid    : resolved entity ID
;;   0      : cannot be resolved
;;------------------------------------------------------------------
    NEW aid
    SET aid=$$GetEID^sapiGet($GET(akey,"sys.attr.key")) ; default to sys.attr.key if akey is omitted

    IF aid<1 DO  QUIT -1
    . DO LOGERROR^logger("apiGet","LookupEID: unresolvable attribute key — "_$GET(akey))

    QUIT $$GetEID(val,aid)


GetEID(val,aid)
;;------------------------------------------------------------------
;; Function : GetEID^apiGet
;;
;; Call     : SET eid=$$GetEID^apiGet(val)
;;            SET eid=$$GetEID^apiGet(val,aid)
;;
;; Purpose  : Resolves any supported entity reference to an internal entity ID (eid).
;;
;;            Three resolution paths are attempted in order:
;;            Path 0 — Strict EID validation + existence check	(aid omitted)
;;            Path 1 — sys.attr.key lookup 						(aid omitted)
;;            Path 2 — UNQINSERT/UNQUPSERT attribute lookup 	(aid supplied)
;;
;; Parameters
;;   val     : (IN) One of:
;;               - persisted eid        e.g. "654f2564f8165hevmhe6"
;;               - sys.attr.key value   e.g. "obj.tom_hanks"
;;               - unique attr value    e.g. "042"
;;
;;   aid 	 : (IN) aid is required only for path 2.
;;
;; Returns  :
;;    eid   : resolved entity ID
;;    0     : cannot be resolved
;;
;; Notice   : LIVENESS
;;            Both Path 1 and Path 2 walk ALL eid candidates under ^AVET(aid,valkey,candidate) 
;; 			  and accept only the one for which GetCurrentVK(candidate,aid)=valkey 
;;            i.e. the one whose most recent tx for `aid` is still asserting this exact `valkey`. 
;;------------------------------------------------------------------
    ; Guard — empty val can never resolve via any path; fail fast before touching globals.
	IF val="" DO  QUIT 0
    . DO LOGERROR^logger("apiGet","GetEID: empty value supplied — cannot resolve")
    
    NEW eid,isEidShaped
    SET eid=0
	SET aid=$GET(aid)
	
	; Guard — aid, if supplied, must be a numeric attribute ID, not a sys.attr.key string.
	IF aid'="",aid'=+aid DO  QUIT 0
    . DO LOGERROR^logger("apiGet","GetEID: aid must be numeric — got '"_aid_"'. Use LookupEID^api if resolving by a sys.attr.key string.")
	
    ; ------------------------------------------------------------------
    ; Path 0 — Strict EID validation + existence check
    ; ------------------------------------------------------------------
    SET isEidShaped=$$IsEID^utils(val)					; performs structural validation
    IF isEidShaped DO  QUIT eid							; if structure is not valid QUIT immediately
    . IF $$IsEntityRegistered^apiVld(val) DO 			; if raw EID exists (val)
    . . SET eid=val
	. . DO LOGDEBUG^logger("apiGet","GetEID: resolved via EID: "_val)
    . ELSE  DO LOGDEBUG^logger("apiGet","GetEID: "_val_" is a valid EID but is not registered")

    ; ------------------------------------------------------------------
    ; Path 1 — sys.attr.key lookup (aid omitted)
    ; Skipped when aid is supplied, also unreachable when val is EID-shaped
    ; ------------------------------------------------------------------
    IF aid="" DO  QUIT eid
    . SET eid=$$ResolveLiveEID^apiRslv(AKEYID,val)
    . IF eid=0 DO LOGDEBUG^logger("apiGet","GetEID: entity cannot be resolved via sys.attr.key: "_val)
    . ELSE  DO LOGDEBUG^logger("apiGet","GetEID: resolved via sys.attr.key: "_val)

    ; ---------------------------------------------------------------------------------
    ; Path 2 — unique attribute lookup (aid must be supplied)
    ; Skipped when aid is omitted, also unreachable when val is EID-shaped
    ; ----------------------------------------------------------------------------------
    SET eid=$$ResolveLiveEID^apiRslv(aid,val)
    IF eid=0 DO LOGDEBUG^logger("apiGet","GetEID: entity cannot be resolved via aid="_aid_" val="_val)
    ELSE  DO LOGDEBUG^logger("apiGet","GetEID: resolved via aid="_aid_" val="_val)


    QUIT eid

