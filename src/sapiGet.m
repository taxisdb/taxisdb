;; ================================================================================================ 
;; ^sapiGet - TBox/Schema subroutines for accesing TBox globals - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 		— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;;==================================================================================================

GetUniqueMode(aid)
;;------------------------------------------------------------------
;; Function : GetUniqueMode^sapiGet
;; Call     : SET mode=$$GetUniqueMode^sapiGet(aid)
;;
;; Purpose  : Returns the uniqueness constraint mode for a given
;;            attribute as a schema enumeration EID.
;;
;;            Replaces the pair $$IsUniqueInsert/$$IsUniqueUpsert
;;            with a single function that returns the mode directly,
;;            allowing callers to compare against schema EIDs rather
;;            than invented string constants.
;;
;; Parameters
;;   aid    : (IN) Attribute entity ID
;;
;; Returns  :
;;   UNQINSERTID — attribute enforces insert-unique (:db.unique/value)
;;   UNQUPSERTID — attribute enforces upsert-unique (:db.unique/identity)
;;   0           — attribute has no uniqueness constraint
;;------------------------------------------------------------------
    IF ''$DATA(^TBAVET(UNIQUEID,INSERTKEY,aid)) QUIT UNQINSERTID
    IF ''$DATA(^TBAVET(UNIQUEID,UPSERTKEY,aid)) QUIT UNQUPSERTID
    QUIT 0


GetAttrValidFn(aid)
;;------------------------------------------------------------------
;; Function : GetAttrValidFn^sapiGet
;; Call     : SET fn=$$GetAttrValidFn^sapiGet(aid)
;;
;; Purpose  : Returns the validation predicate associated with an
;;            attribute, or "" if none has been defined.
;;
;; ^TBEAVT structure: ^TBEAVT(entity,attribute,valuekey,txn)=1
;; entity=aid, attribute=VALIDFNID — direct EAVT lookup, no scan.
;;
;; Returns  :
;;   predicate string (e.g. "$$IsInt^utils")
;;   "" if no validation predicate exists
;;------------------------------------------------------------------
    NEW vk

    IF '$DATA(VALIDFNID) QUIT ""
    IF VALIDFNID'>0 QUIT ""

    SET vk=$ORDER(^TBEAVT(aid,VALIDFNID,""))

    IF vk="" QUIT ""

    QUIT $$GetDictValue(VALIDFNID,vk)


GetKey(eid)
;;------------------------------------------------------------------
;; Function 	: GetKey^sapiGet
;;
;; Purpose  	: Fetch a human-readable key for a TBox entity
;;
;; Parameters 	:
;;		eid		: TBox entity ID
;;
;; Returns  	: 
;;					key that has been assigned to entity with the sys.attr.key attribute 
;;            		""  if not found
;;------------------------------------------------------------------
    NEW valkey
    SET valkey=$ORDER(^TBEAVT(eid,AKEYID,""))
    IF valkey="" QUIT ""
    QUIT $GET(^TBD(AKEYID,valkey))


GetDictValue(aid,valkey) ; Get the value for an (aid,valkey) pair from TBD
;;------------------------------------------------------------------------------------------------
;; Function	: GetDictValue^sapiGet
;;
;; Usage    : w $$GetDictValue(210,"00A.18716") --> sandbox.movie.title
;;			
;; Purpose  : Resolves a lookup key to its human-readable value string
;;            Branches on:
;;              Literal   — ^TBD(aid,valkey) = value string directly
;;              Reference — ^TBD(aid,valkey) = eid → ^TBEAVT(eid,AKEYID,vk,*) → ^TBD(AKEYID,vk)
;;
;; Returns  : Value string  
;;            "" if not found
;;
;; Notice   : ^TBD is a shared value dictionary
;; 		it stores literal attribute values for both TBox (schema) and ABox (entity) attributes under a single global. 
;; 		A literal lookup (GetDictValue) resolves directly against ^TBD(aid,valkey) regardless of which model 
;; 		the attribute belongs to.
;; 		Reference-type attributes are the exception. When aid is a reference type (IsRefValType^sapiVld), 
;; 		^TBD(aid,valkey) stores the referenced entity's eid, not a literal string. 
;; 		Resolving that reference to its current value requires an additional lookup into ^EATV or ^TBEAVT.
;; 		Two GetDictValue implementations exist accordingly — 
;; 		GetDictValue^apiGet (ABox, reads ^EATV) and GetDictValue^sapiGet (TBox, reads ^TBEATV)
;;------------------------------------------------------------------
    NEW eid,vk
    ;; Attribute accepts literal values
    IF '$$IsRefValType^sapiVld(aid) QUIT $GET(^TBD(aid,valkey))
    
    ;This attribute accepts reference values.
    SET eid=$GET(^TBD(aid,valkey))
    IF eid="" QUIT ""
    SET vk=$ORDER(^TBEAVT(eid,AKEYID,""))
    IF vk="" QUIT ""
    QUIT $GET(^TBD(AKEYID,vk))


GetValKey(aid,val) ; Get the Value-Key for an (aid,val) pair from TBDR
;;---------------------------------------------------------------------
;; Function : GetValKey^sapiGet
;; Call     : SET valkey=$$GetValKey^sapiGet(aid,val)
;;
;; Purpose  : Resolves the lookup key (valkey) for a literal attribute value
;;
;; Parameters
;;   aid : (IN)  Attribute entity ID
;;   val : (IN)  Literal value to resolve
;;
;; Scope
;;   Reads  : ^TBDR(aid,val)
;;
;;
;; Returns  :
;;   valkey : lookup key for the literal value, if registered
;;   ""     : not found — either the attribute is not literal-typed, 
;;	          or the value is not registered for the attribute
;;------------------------------------------------------------------
    QUIT $GET(^TBDR(aid,val))


GetRefValKey(refekey,akey) ; resolve the reference value key for a referenced entity
;;------------------------------------------------------------------------------------
;; Function : GetRefValKey^sapiGet
;;
;; Usage    : SET REFKEY    = $$GetRefValKey("sys.val.ref")
;;            SET MANYKEY   = $$GetRefValKey("sys.enum.cardinality.many","sys.attr.cardinality")
;;            SET INSERTKEY = $$GetRefValKey("sys.enum.unique.insert","sys.attr.unique")
;;
;; Purpose  : Resolves the reference value key for a referenced entity identified
;;            by refekey, as stored under the reference index ^TBDR(attrEID,refEID).
;;            Only meaningful for attributes whose range is reference-typed, where
;;            ^TBDR(aid,eid) stores the value key of the referenced entity.
;;
;; Parameters
;;   refekey : (IN)  Key of the referenced entity — 
;;						enumerated value key (e.g. "sys.enum.cardinality.many") or 
;;						data type key        (e.g. "sys.val.ref")
;;
;;   akey    : (IN, optional) Key of the scoping attribute, e.g. "sys.attr.cardinality",
;;                   "sys.attr.unique". Defaults to "sys.attr.range" when omitted.
;;
;; Returns  :
;;   value key : reference value key stored at ^TBDR(attrEID,refEID)
;;   ""        : not found — this covers both a genuinely unregistered reference
;;               AND either akey/refekey failing to resolve to a valid EID via
;;               GetEID (no distinction made between the two cases)
;;------------------------------------------------------------------
    NEW attrEID	; resolved entity ID for the scoping attribute akey
    NEW refEID	; resolved entity ID for the referenced entity refekey
    SET akey=$GET(akey)
    SET:akey="" akey="sys.attr.range"
    SET attrEID=$$GetEID(akey)
    SET refEID=$$GetEID(refekey)
    QUIT $GET(^TBDR(attrEID,refEID))


    
GetEID(akey) ; resolve the entity ID of a schema entity
;;------------------------------------------------------------------
;; Function : GetEID^sapiGet
;;
;; Call     : W $$GetEID^sapiGet("sys.attr.cardinality")
;;
;; Usage    : SET AttrEID=$$GetEID^sapiGet("sys.attr.cardinality")
;;
;; Purpose  : Resolves the entity ID of a schema entity such as an attribute,
;;            value type, enumerated value, or association type — excludes
;;            object instances (keys prefixed "obj").
;;
;; Parameters
;;   akey : (IN) Schema entity key string registered in schema
;;
;; Scope
;;   Reads  : ^TBDR(AKEYID,akey), ^TBAVET(AKEYID,valkey,"")
;;
;; Scope (Indirect Globals Access)
;;   Reads  : ^TBDR — via IsRangeValue
;;
;; Returns  :
;;   >0 : entity ID of the schema entity
;;   -1 : schema entity not found — either akey is an object-instance key
;;        (prefixed "obj"), or unregistered, or registered in the value
;;        dictionary (^TBDR) but its entity assertion has not yet been
;;        committed to ^TBAVET (e.g. Transact^sapi hasn't run yet for a
;;        staged record)
;;------------------------------------------------------------------
    NEW valkey	; value key resolved for akey, reference case only
    NEW eid		; result accumulator, defaults to -1 (not found)
    SET eid=-1

    ; Object-instance keys are out of scope for this function — bail immediately
    QUIT:$EXTRACT(akey,1,3)="obj" eid

    IF $$IsRangeValue^sapiVld(AKEYID,akey) DO
    . SET valkey=^TBDR(AKEYID,akey)
    . SET eid=$ORDER(^TBAVET(AKEYID,valkey,""))
    . ; A key can exist in the value dictionary (^TBDR) before its entity
    . ; assertion is committed to ^TBAVET. Never leak "" to the caller —
    . ; honor the documented contract: -1 = not found.
    . SET:eid="" eid=-1

    QUIT eid


GetEntTypeKey(eid) ; return the entity type key label for a given entity
;;------------------------------------------------------------------
;; Function or Routine  : GetEntTypeKey ; Function if QUIT returns a value, otherwise Routine
;;
;; Call     : W $$GetEntTypeKey^sapiGet(620)
;;
;; Usage    : W $$GetEntTypeKey^sapiGet(620)
;;
;; Purpose  : Returns the entity type key label for a given entity, by scanning
;;            ^TBEAVT(eid,ISAID) to find the value key, then translating it to
;;            a human-readable type label via GetDictValue.
;;
;; Parameters
;;   eid : (IN) Entity ID
;;
;; Scope
;;   Reads  : ^TBEAVT(eid,ISAID,valkey)
;;
;; Scope (Indirect Globals Access)
;;   Reads  : (whatever GetDictValue reads to resolve a value key to a label)
;;
;; Returns  :
;;   type key string : entity has an ISA assertion, resolved to its label
;;   -1               : entity has no ISA assertion under ^TBEAVT(eid,ISAID,*)
;;
;; Notes    : Does not verify that GetDictValue itself succeeded — if it
;;            returns an empty string or failure sentinel for an unresolvable
;;            vkey, that value is passed straight through as the return, not -1.
;;------------------------------------------------------------------
    NEW vkey	; value key found under ^TBEAVT(eid,ISAID,*)
    NEW typekey	; resolved type label, or -1 if no ISA assertion exists
    SET typekey=-1
    SET vkey=$ORDER(^TBEAVT(eid,ISAID,""))
    IF vkey="" QUIT -1
    SET typekey=$$GetDictValue^sapiGet(ISAID,vkey)
    QUIT typekey

