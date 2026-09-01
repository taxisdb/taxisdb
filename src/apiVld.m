;; ============================================================================= 
;; ^apiVld - ABox validation Subroutines - This file is part of TaxisDB Platform
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
;;   Public validation API for enforcing schema constraints, entity
;;   existence, and datom integrity before staging or persistence.
;;
;; Description
;;   Provides the validation layer used by the assertion workflow to
;;   verify records before they reach %ABR. Enforces required
;;   attributes for new entities, schema-defined predicate checks,
;;   unique attribute ownership constraints, empty-value rejection,
;;   and low-level existence probes against ^ABE and ^EATV.
;;
;; Responsibilities
;;   • Validate entity existence in ^ABE (IsEntityRegistered)
;;   • Validate datom record existence in ^EATV (IsDatomRecorded)
;;   • Reject empty values and enforce required attributes on create (ValidateRecord)
;;   • Execute schema-defined validation predicates per attribute (ValidateAttrPredVal, ValidateAttrPredicates)
;;   • Enforce insert/upsert uniqueness constraints (ValidateUniqueConstraint)
;;
;; Public API Groups
;;   Existence Checks
;;		IsEntityRegistered
;;		IsDatomRecorded
;;
;;   Record Validation
;;		ValidateRecord
;;
;;   Attribute Validation
;;		ValidateAttrPredVal
;;		ValidateAttrPredicates
;;		ValidateUniqueConstraint
;;
;;==============================================================================

IsDatomRecorded(eid,aid,tx,valkey) ; check whether a datom is recorded
;;----------------------------------------------------------------------------------------------------
;; Function : IsDatomRecorded^apiVld
;;
;; Call     : WRITE $$IsDatomRecorded^apiVld(eid,aid,tx,valkey)
;;
;; Purpose  : Determine whether a datom transaction record exists.
;;
;; Parameters
;;   eid    : (IN) Entity identifier.
;;   aid    : (IN) Attribute identifier.
;;   tx     : (IN) Transaction identifier.
;;   valkey : (IN) Value key.
;;
;; Scope
;;   Reads  : ^EATV(eid,aid,tx,valkey)
;;
;; Returns  : 1 if the datom record exists, otherwise 0.
;;----------------------------------------------------------------------------------------------------
    ; Check the primary datom store.
    QUIT $DATA(^EATV(eid,aid,tx,valkey))>0    ; Return record existence


IsEntityRegistered(eid) ; check whether entity is registered in ^ABE
;;----------------------------------------------------------------------------------------------------
;; Function : IsEntityRegistered^apiVld
;;
;; Call     : WRITE $$IsEntityRegistered^apiVld(eid)
;;
;; Purpose  : Determine whether an ABox entity is registered in ^ABE.
;;
;; Parameters
;;   eid    : (IN) Entity identifier.
;;
;; Scope
;;   Reads  : ^ABE(eid,1)
;;
;; Returns  : 1 if entity is registered in ^ABE, otherwise 0.
;;
;; Notes    : registration is indicated by the existence of the node, not by a non-empty value e.g.
;;			  ^ABE("65825611ba143blkjysi",1)=""
;;			  ^ABE("65825611ba2aemmuqtyi",1)=""
;;
;;	''$DATA(...) double-negation canonicalize $DATA's four-valued return into a strict 0/1 boolean.
;;----------------------------------------------------------------------------------------------------    
    QUIT ''$DATA(^ABE(eid,1))


EscapeQuotes(s)
    ; Double every embedded quote so it's a safe M string literal.
    NEW out,i,c
    SET out=""
    FOR i=1:1:$LENGTH(s) DO
    . SET c=$EXTRACT(s,i)
    . SET out=out_c_$SELECT(c="""":"""",1:"")
    QUIT out


ValidateAttrPredVal(predicate,val)
    ; ------------------------------------------------------------
    ; Procedure : ValidateAttrPredVal^apiVld
    ;
    ; Purpose   : Executes schema-defined validation predicate
    ;             against a single attribute value.
    ;
    ; predicate : fully-qualified predicate, e.g. "$$IsInt^utils"
    ;             (leading "$$" optional — stripped if present)
    ; val       : the attribute value to validate
    ;
    ; NOTE: Indirect call syntax ($$@fn(val), $$@call) does not work
    ;
    ; Returns   : 1 if predicate returned true, 0 otherwise
    ; ------------------------------------------------------------
    NEW result,safeVal

    SET result=0
    IF predicate="" QUIT 1

    ; Escape embedded quotes so val cannot terminate the string
    ; literal early and inject code into the executed command.
    SET safeVal=$$EscapeQuotes(val)

    XECUTE "SET result="_predicate_"("""_safeVal_""")"

    QUIT result



ValidateAttrPredicates(ResolvedRec)
    ; ------------------------------------------------------------
    ; Validate schema-defined attribute predicates.
    ; Returns:
    ;   1 = all predicates passed
    ;   0 = one or more predicates failed
    ; ------------------------------------------------------------

    NEW aid,val,predicate,ok

    SET ok=1
    SET aid=""

	; Iterate every asserted attribute (aid) on this record. For
    ; each one, look up whether the schema defines a validation
    ; predicate for that attribute; if it does, run the predicate
    ; against the attribute's staged value. Stops at the first
    ; failing predicate — remaining attributes are not checked
    FOR  SET aid=$ORDER(ResolvedRec("+",aid)) QUIT:aid=""!'ok  DO
    . NEW predicate,val
    . ; Retrieve the schema predicate for this attribute.
    . SET predicate=$$GetAttrValidFn^sapiGet(aid)
    . ; No predicate defined for this attribute — nothing to enforce.
    . IF predicate="" QUIT
    . SET val=ResolvedRec("+",aid)
    . IF '$$ValidateAttrPredVal(predicate,val) DO
    . . SET ok=0
    . . DO LOGERROR^logger("apiVld","ValidateAttrPredicates: validation failed for aid="_aid_", value="""_val_""", predicate="_predicate)

    QUIT ok


ValidateUniqueConstraint(eid,aid,val,valkey,isNewValKey) ; validate insert/upsert uniqueness
;;------------------------------------------------------------------
;; Function  : ValidateUniqueConstraint^apiVld
;;
;; Call      : SET ok=$$ValidateUniqueConstraint^apiVld
;;
;; Usage     : Called after value resolution and before datom staging
;;
;; Purpose   : Enforce unique attribute ownership
;;
;; Parameters
;;   eid         : (IN) Entity asserting the value
;;   aid         : (IN) Attribute identifier
;;   val         : (IN) Original caller supplied value
;;   valkey      : (IN) Resolved value key
;;   isNewValKey : (IN) Value resolution status
;;
;; Returns  : 1 if uniqueness validation succeeds, otherwise 0
;;
;; Notes    :
;;------------------------------------------------------------------
    NEW uniqueMode     ; Attribute uniqueness mode
    NEW ownereid       ; Existing live owner of valkey, 0/"" if none

    SET ownereid=""
    SET uniqueMode=$$GetUniqueMode^sapiGet(aid)

    ; Live-owner lookup is only required for reused value keys.
    ; ResolveLiveEID already applies liveness — historical (retracted)
    ; ownership alone yields no live owner, matching the "not a violation" rule.
    IF (uniqueMode=UNQINSERTID)!(uniqueMode=UNQUPSERTID),'isNewValKey DO
    . SET ownereid=$$ResolveLiveEID^apiRslv(aid,val)

    ; Reject only when another entity currently owns the value.
    IF ownereid'="",ownereid'=0,(ownereid'=eid) DO  QUIT 0
    . IF uniqueMode=UNQINSERTID DO
    . . DO LOGERROR^logger("apiVld","DatomAssert: insert-unique violation — ("_aid_","_val_":"_valkey_") already owned by ("_ownereid_")")
    . ELSE  DO
    . . DO LOGERROR^logger("apiVld","DatomAssert: upsert-unique collision — ("_aid_","_val_":"_valkey_") already owned by ("_ownereid_")")

    ; Uniqueness constraint satisfied.
    QUIT 1


ValidateRecord(ResolvedRec,ReqAttr,AttrCache,isNewEntity)
;;------------------------------------------------------------------
;; Function : ValidateRecord^apiVld
;; Call     : SET ok=$$ValidateRecord^apiVld(.ResolvedRec,.ReqAttr,.AttrCache,isNewEntity)
;;
;; Purpose  : Validates entity facts in ResolvedRec after control
;;            attributes have been consumed by ResolveTargetEntity.
;;            At this point ResolvedRec contains ONLY entity facts —
;;            no sys.attr.id, sys.attr.key, or sys.attr.resolveby.
;;
;;            Two checks are performed:
;;
;;            CHECK 1 — Empty values
;;              Every assertion must have a non-empty value.
;;              Null subscripts crash ^TBDR and ^EATV globals on YottaDB.
;;              Applied unconditionally — insert or update.
;;
;;            CHECK 2 — Required attributes
;;              Every attribute marked as required in the schema must
;;              be present in ResolvedRec. Applied ONLY when
;;              isNewEntity is true — i.e. only when creating a brand
;;              new entity. Updates to an existing entity may
;;              legitimately assert only a subset of its attributes;
;;              the required-attribute set was already satisfied when
;;              the entity was first created, and re-demanding every
;;              required attribute on every subsequent update would
;;              make partial updates impossible.
;;
;;              When applied, this check is further scoped to records
;;              that contain at least one attribute from the same
;;              sub-namespace as the required attributes — prevents
;;              cross-namespace false failures e.g. a person.* record
;;              must not be checked against sandbox.movie.* required
;;              attributes. Namespace membership is resolved via
;;              AttrCache(aid) reverse map — O(1) lookup, no schema
;;              traversal per attribute.
;;
;;            Both checks concern the entity itself — not the
;;            transaction. This is Phase 2 validation, distinct from
;;            the transaction validation performed inside
;;            ResolveTargetEntity (Phase 1).
;;
;; Parameters
;;   ResolvedRec : (IN) Resolved record — entity facts only
;;   ReqAttr     : (IN) Required attributes map — built by
;;                      BuildAttrsRequired^sapi
;;                      ReqAttr      = total count of required attrs
;;                      ReqAttr(aid) = attrkey string
;;   AttrCache   : (IN) Schema attribute cache — built by
;;                      BuildAttrsCache^sapi
;;                      AttrCache(fullkey) = aid  (forward map)
;;                      AttrCache(aid)     = sub-namespace (reverse map)
;;   isNewEntity : (IN) 1 if this record is creating a brand new
;;                      entity (eid did not previously exist in
;;                      ^EATV), 0 if updating an existing entity.
;;                      CHECK 2 is skipped entirely when 0.
;;                      Defaults to 1 if omitted — preserves strict
;;                      create-time validation for direct callers
;;                      (e.g. standalone tests) that don't supply it.
;;
;; Returns  :
;;   1 — all checks passed
;;   0 — any check failed (error logged)
;;------------------------------------------------------------------
    NEW aid,ok,missingCount,reqns,hasNamespaceAttr
    SET ok=1
    SET isNewEntity=$GET(isNewEntity,1)

    ; ------------------------------------------------------------------
    ; CHECK 1 — Empty values
    ; Null subscripts crash ^TBDR and ^EATV globals on YottaDB.
    ; Check assertions only — retractions allow empty val for
    ; cardinality-one (DatomRetract handles that case itself).
    ; Applied unconditionally regardless of isNewEntity.
    ; ------------------------------------------------------------------
    ; Iterate all assertions — fail fast on first empty value
    SET aid=""    
    FOR  SET aid=$ORDER(ResolvedRec("+",aid)) QUIT:aid=""!'ok  DO
    . IF ResolvedRec("+",aid)="" SET ok=0 DO LOGERROR^logger("apiVld","ValidateRecord: empty value for aid "_aid_" — aborting")
    IF 'ok QUIT 0

	; ------------------------------------------------------------
    ; CHECK 2 — Attribute predicates
    ; ------------------------------------------------------------
    IF '$$ValidateAttrPredicates(.ResolvedRec) QUIT 0

    ; ------------------------------------------------------------------
    ; CHECK 3 — Required attributes
    ; Skipped entirely for updates to an existing entity.
    ; ------------------------------------------------------------------

    ; Short-circuit — no required attrs defined for this namespace
    IF ReqAttr=0 QUIT ok

    ; Short-circuit — updating an existing entity, not creating one
    IF 'isNewEntity QUIT ok

    ; Determine the required sub-namespace from the first ReqAttr entry
    SET aid=$ORDER(ReqAttr(""))
    SET reqns=$PIECE($GET(ReqAttr(aid)),".",1,2)

    ; Check whether the record contains any attribute from the required namespace
    ; Uses AttrCache reverse map — AttrCache(aid) = sub-namespace
    SET hasNamespaceAttr=0
    SET aid=""
    FOR  SET aid=$ORDER(ResolvedRec("+",aid)) QUIT:aid=""!hasNamespaceAttr  DO
    . IF $GET(AttrCache(aid))=reqns SET hasNamespaceAttr=1

    ; Skip required attribute check — record belongs to a different namespace
    IF 'hasNamespaceAttr QUIT ok

    ; Iterate required attributes and verify each is present in the record
    SET missingCount=0
    SET aid=""
    FOR  SET aid=$ORDER(ReqAttr(aid)) QUIT:aid=""  DO
    . IF '$DATA(ResolvedRec("+",aid)) DO
    . . SET missingCount=missingCount+1
    . . DO LOGERROR^logger("apiVld","ValidateRecord: Record is missing required attribute "_$GET(ReqAttr(aid),aid))

    IF missingCount>0 DO
    . SET ok=0
    . DO LOGERROR^logger("apiVld","ValidateRecord: Record is missing "_missingCount_" required attribute(s)")

    QUIT ok
    
