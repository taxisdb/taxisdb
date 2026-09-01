;; ============================================================================= 
;; ^sapiVld - TBox/Schema validation subroutines - This file is part of TaxisDB Platform
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


IsEntityRegistered(eid) ; check whether entity is registered in ^TBE
;;----------------------------------------------------------------------------------------------------
;; Function : IsEntityRegistered^sapiVld
;;
;; Call     : WRITE $$IsEntityRegistered^sapiVld(eid)
;;
;; Purpose  : Determine whether a TBox entity is registered in ^TBE.
;;
;; Parameters
;;   eid    : (IN) Entity identifier.
;;
;; Scope
;;   Reads  : ^TBE(eid,1)
;;
;; Returns  : 1 if entity is registered in ^TBE, otherwise 0.
;;
;; Notes    : registration is indicated by the existence of the node, not by a non-empty value e.g
;;			  ^TBE(1012,1)=""
;;			  ^TBE(1013,1)=""
;;
;;	''$DATA(...) double-negation canonicalize $DATA's four-valued return into a strict 0/1 boolean.
;;----------------------------------------------------------------------------------------------------
	QUIT ''$DATA(^TBE(eid,1))


IsRangeValue(aid,val) ; check if val (literal or reference) is already registered in aid's data type
;;------------------------------------------------------------------
;; Function : IsRangeValue^sapiVld
;;
;; Call     : IF $$IsRangeValue^sapiVld(aid,val)
;;
;; Usage    : Called by IsNewRangeValue to test literal (non-reference) values before insertion
;;
;; Purpose  : Returns 1 if the candidate value (val) is already registered in the data type of attribute (aid)
;;
;; Parameters
;;   aid  : (IN) Attribute entity ID identifying the data type being checked
;;   val  : (IN) Candidate value being checked for existing registration
;;
;; Scope
;;   Reads  : ^TBDR(aid,val)
;;
;; Returns  :
;;   1 : val is already registered
;;   0 : val is not yet registered
;;
;; Notes    : Used by IsNewRangeValue for literal data types only.
;;            ResolveAV handles reference value registration independently in CASE 3.
;;------------------------------------------------------------------
    NEW isReg ; holds the registered/not-registered result returned to caller

    ; val is registered if a ^TBDR node exists for it under this attribute
    SET isReg=($GET(^TBDR(aid,val))'="")

    ; Debug trace, left commented, for tracing why a value was found unregistered
    ; IF 'isReg DO LOGDEBUG^logger("sapiVld","IsRangeValue: not registered — aid="_aid_", val="_val)

    QUIT isReg
   

IsNewRangeValue(aid,val) ; check if val (literal or reference) needs a new key in aid's data type
;;------------------------------------------------------------------
;; Function : IsNewRangeValue^sapiVld
;;
;; Call     : IF $$IsNewRangeValue^sapiVld(aid,val)
;;
;; Usage    : Called before inserting a value into a dictionary-valued attribute's data type
;;
;; Purpose  : Determines whether a NEW value key must be created
;;            for a value within a given attribute data type.
;;
;; Parameters
;;   aid  : (IN) Attribute entity ID identifying the data type being evaluated
;;   val  : (IN) Candidate value being evaluated for data type insertion
;;
;; Returns  :
;;   1 : val is new to the data type and a new key must be allocated
;;   0 : val is already registered
;;
;;------------------------------------------------------------------
    NEW isNew ; holds the new/not-new result returned to caller

    ; New key required whenever val isn't already registered — applies
    ; uniformly to literal and reference-typed attributes.
    SET isNew=('$$IsRangeValue(aid,val))

    ; Debug trace, left commented, for tracing why a value was/wasn't treated as new
    ; IF 'isNew DO LOGDEBUG^logger("sapiVld","IsNewRangeValue: not new — aid="_aid_", val="_val_", IsRefValType="_$$IsRefValType(aid)_", IsRangeValue="_$$IsRangeValue(aid,val))

    QUIT isNew


IsRefValType(aid)
;;------------------------------------------------------------------
;; Function : IsRefValType^sapiVld
;; Call     : IF $$IsRefValType^sapiVld(aid)
;;
;; Purpose  : Returns 1 if the metadata attribute is reference-typed, 0 otherwise. 
;;            A reference data type stores entity IDs as values 
;;
;;
;; Returns  :
;;   1 — reference data type (values are entity IDs)
;;   0 — literal type   	 (values are raw strings)
;;
;; Notes    :
;;			''$DATA(...) double-negation canonicalize $DATA's four-valued return into a strict 0/1 boolean.
;;------------------------------------------------------------------
    NEW isRef
    SET isRef=''$DATA(^TBAVET(RANGEID,REFKEY,aid))
    ;IF 'isRef DO LOGDEBUG^logger("sapiVld","IsRefValType: not reference-typed — aid="_aid)
    QUIT isRef
    

IsUniqueInsert(aid)
;;------------------------------------------------------------------
;; Function : IsUniqueInsert^sapiVld
;; Call     : IF $$IsUniqueInsert^sapiVld(aid)
;;
;; Purpose  : Returns 1 if the metadata attribute enforces uniqueness
;;            semantics, 0 otherwise.
;;
;;            A unique attribute rejects insertion when another entity
;;            already owns the same resolved value.
;;
;; TODO     : sys.enum.unique.upsert
;;
;;
;; Returns  :
;;   1 — attribute enforces uniqueness
;;   0 — attribute allows duplicate values
;;------------------------------------------------------------------
    NEW isUnq
    SET isUnq=''$DATA(^TBAVET(UNIQUEID,INSERTKEY,aid))
    IF 'isUnq DO LOGDEBUG^logger("sapiVld","IsUniqueInsert: not unique-insert — aid="_aid)
    QUIT isUnq


IsUniqueUpsert(aid)
;;------------------------------------------------------------------
;; Function : IsUniqueUpsert^sapiVld
;; Call     : IF $$IsUniqueUpsert^sapiVld(aid)
;;
;; Purpose  : Returns 1 if the attribute enforces upsert-unique
;;            semantics, 0 otherwise.
;;
;;            A unique-upsert attribute merges incoming data into the
;;            existing entity when a matching unique value is found,
;;            implementing identity-based upsert semantics — the
;;            incoming record is redirected to the owner entity rather
;;            than rejected. Mirrors :db.unique/identity in Datomic.
;;
;;
;; Returns  :
;;   1 — attribute enforces upsert-unique (duplicate = merge into owner)
;;   0 — attribute does not enforce upsert-unique
;;
;; Notes    : 
;;			: ''$DATA(...) double-negation canonicalize $DATA's four-valued return into a strict 0/1 boolean.
;;------------------------------------------------------------------
    NEW isUpsert
    SET isUpsert=''$DATA(^TBAVET(UNIQUEID,UPSERTKEY,aid))
    IF 'isUpsert DO LOGDEBUG^logger("sapiVld","IsUniqueUpsert: not unique-upsert — aid="_aid)
    QUIT isUpsert


IsAttrType(aid)
;;------------------------------------------------------------------
;; Function : IsAttrType^sapiVld
;; Call     : IF $$IsAttrType^sapiVld(aid)
;;
;; Purpose  : Returns 1 if the TBox entity is an attribute, 0 otherwise.
;;            Distinguishes attributes from other TBox entity kinds
;;            (e.g. composite value types) that may share the same
;;            key namespace.
;;
;; Returns  :
;;   1 — attribute
;;   0 — non-attribute entity (any other type marker, or unresolved)
;;------------------------------------------------------------------
    NEW isAttr,valkey,etype
    SET isAttr=0
    SET valkey=$ORDER(^TBEAVT(aid,ISAID,""))
    IF valkey'="" DO
    . SET etype=$GET(^TBD(ISAID,valkey))
    . SET isAttr=(etype=ATTRTYPEID)
    ;IF 'isAttr DO LOGDEBUG^logger("sapiVld","IsAttrType: not an attribute — aid="_aid)
    QUIT isAttr
    


IsMultiValue(aid)
;;------------------------------------------------------------------
;; Function : IsMultiValue^sapiVld
;; Call     : IF $$IsMultiValue^sapiVld(aid)
;;
;; Purpose  : To support delimited multi-value expansion using "|" for attributes flagged as multi-valued. (see ^api routines)
;;
;;
;; Returns  :
;;   1 — multi-valued attribute  (cardinality many)
;;   0 — single-valued attribute (any other cardinality)
;;
;; Notes    : 
;;			: ''$DATA(...) double-negation canonicalize $DATA's four-valued return into a strict 0/1 boolean.
;;------------------------------------------------------------------
    NEW isMulti
    SET isMulti=''$DATA(^TBAVET(CARDINID,MANYKEY,aid))
    ;IF 'isMulti DO LOGDEBUG^logger("sapiVld","IsMultiValue: not multi-valued — aid="_aid)
    QUIT isMulti



IsTwoLevelArray(Data)
;;------------------------------------------------------------------
;; Function : IsTwoLevelArray^sapiVld
;; Call     : IF '$$IsTwoLevelArray^sapiVld(.Data)
;;
;; Purpose  : Validates that every leaf node in Data has exactly
;;            two subscript levels, i.e. Data(idx,metaKey)=value.
;;            Returns 0 immediately if any node with depth other
;;            than two is found.
;;
;; Parameters
;;   Data   : (IN) Local array to inspect
;;
;; Returns  :
;;   1 — all leaf nodes have exactly two subscript levels
;;   0 — array is empty or any node has depth other than two
;;------------------------------------------------------------------
    NEW ref,qlength,isValid
    SET ref=$NAME(Data)
    SET isValid=1
    ; Iterate all nodes in Data checking every node has exactly two subscript levels
    FOR  SET ref=$QUERY(@ref) QUIT:(ref="")!'isValid  DO    
    . SET qlength=$QLENGTH(ref)
    . IF qlength'=2 DO
    . . SET isValid=0
    . . DO LOGERROR^logger("sapiVld","IsTwoLevelArray: invalid node "_ref_" — expected 2 subscript levels, got "_qlength)
    QUIT isValid


IsFnType(aid)
;;------------------------------------------------------------------
;; Function : IsFnType^sapiVld
;; Call     : IF $$IsFnType^sapiVld(aid)
;;
;; Purpose  : Returns 1 if the metadata attribute has data type FN
;;            (function reference), 0 otherwise. An FN data type
;;            stores a reference to a MUMPS extrinsic function in
;;            the form $$Tag^Routine (e.g. used by
;;            sys.attr.validationfn).
;;
;; Returns  :
;;   1 — FN data type
;;   0 — other data type
;;
;; Notes    : 
;;			: ''$DATA(...) double-negation canonicalize $DATA's four-valued return into a strict 0/1 boolean.
;;------------------------------------------------------------------
	NEW isFn
	SET isFn=''$DATA(^TBAVET(RANGEID,FNKEY,aid))
	;IF 'isFn DO LOGDEBUG^logger("sapiVld","IsFnType: not FN-typed — aid="_aid)
	QUIT isFn


IsLangStrValType(aid)
;;------------------------------------------------------------------
;; Function : IsLangStrValType^sapiVld
;; Call     : IF $$IsLangStrValType^sapiVld(aid)
;;
;; Purpose  : Returns 1 if the metadata attribute has data type LANGSTR, 0 otherwise. 
;;            A LANGSTR data type stores a language-tagged string distinguished from a plain string by the mandatory @<lang> suffix @en
;;
;; Returns  :
;;   1 — LANGSTR data type 
;;   0 — other data type
;;------------------------------------------------------------------
	NEW isLangStr
	SET isLangStr=''$DATA(^TBAVET(RANGEID,LANGSTRKEY,aid))
	;IF 'isLangStr DO LOGDEBUG^logger("sapiVld","IsLangStrValType: not LANGSTR-typed — aid="_aid)
	QUIT isLangStr


IsRequired(aid)
;;------------------------------------------------------------------
;; Function : IsRequired^sapiVld
;; Call     : IF $$IsRequired^sapiVld(aid)
;;
;; Purpose  : Returns 1 if the metadata attribute is marked as
;;            required, 0 otherwise. A required attribute must be
;;            present in every entity assertion.
;;
;; Returns  :
;;   1 — attribute is required (must be present in every assertion)
;;   0 — attribute is optional (may be omitted from an assertion)
;;
;; Notes    :
;;			: ''$DATA(...) double-negation canonicalize $DATA's four-valued return into a strict 0/1 boolean.
;;------------------------------------------------------------------
    NEW isReq
    SET isReq=''$DATA(^TBAVET(REQID,REQTRUEKEY,aid))
    IF 'isReq DO LOGDEBUG^logger("sapiVld","IsRequired: not required — aid="_aid)
    QUIT isReq


IsNotRedundantTriplet(eid,aid,valkey)
;;------------------------------------------------------------------
;; Function : IsNotRedundantTriplet^sapiVld
;; Call     : IF $$IsNotRedundantTriplet^sapiVld(eid,aid,valkey)
;;
;; Purpose  : Returns 1 if the (eid, aid, valkey) triplet has NOT
;;            yet been asserted in the TBox assertion store, i.e. the assertion is new and should be written.
;;            Returns 0 if the triplet already exists — the caller should skip the write and log a redundancy warning.
;;
;; Parameters
;;   eid    : (IN)  Entity ID of the subject
;;   aid  	: (IN)  Metadata attribute entity ID
;;   valkey : (IN)  DataType lookup key for the value
;;
;; Returns  :
;;   1 — triplet is absent   → safe to assert
;;   0 — triplet is present  → redundant, skip
;;------------------------------------------------------------------
    QUIT '$DATA(^TBEAVT(eid,aid,valkey))


IsNotValidAttrMetadata(AMeta,eid) ; validate attribute metadata before schema write
;;------------------------------------------------------------------
;; Function : IsNotValidAttrMetadata^sapiVld
;;
;; Call     : IF $$IsNotValidAttrMetadata^sapiVld(.AMeta,eid)
;;
;; Usage    : Called before any schema write to check metadata correctness
;;
;; Purpose  : Validates the metadata array AMeta before any schema write.
;;
;; Parameters
;;   AMeta  : (IN) Attribute metadata local array
;;                 AMeta(metakey) = metavalue
;;   eid    : (IN) Entity ID of the attribute if it already exists
;;                 eid < 0 — attribute not yet created
;;                 eid > 0 — attribute already exists in schema
;;
;; Returns  :
;;   1 : validation failed (not valid)
;;   0 : validation passed
;;
;; Notes    : TODO — In check1 cover validation of other metadata attributes 
;;------------------------------------------------------------------
    NEW key,notvalid,missingKey,missingRange,missingCardinality,missingISA,etype
    SET key="",notvalid=0 ; key drives the CHECK 1 iteration; notvalid is the result flag

    ; Precompute presence/absence of each required metadata key, and the attribute's type
    SET missingKey='$DATA(AMeta("sys.attr.key"))
    SET missingRange='$DATA(AMeta("sys.attr.range"))
    SET missingCardinality='$DATA(AMeta("sys.attr.cardinality"))
    SET missingISA='$DATA(AMeta("sys.attr.isa"))
    SET etype=$GET(AMeta("sys.attr.isa"))

    ; CHECK 1 — Metadata vocabulary validation
    ;           (is the metadata attribute known?)
    ;           Every key in AMeta must be registered in the sys.attr.key data type (AKEYID).
    ;           An unrecognised key means the caller passed an invalid metadata attribute name.
    NEW aid,isLangStrType,isFnType
    SET aid=""
    SET isLangStrType=0

    ; Walk every key in AMeta, stop early once any check fails
    FOR  SET key=$ORDER(AMeta(key)) QUIT:key=""  QUIT:notvalid  DO
    . SET aid=$$GetEID^sapiGet(key)
    . SET isLangStrType=$$IsLangStrValType(aid)
    . SET isFnType=$$IsFnType(aid)
    . ; Reject unregistered keys first, before checking any value-level rules
    . IF '$$IsRangeValue(AKEYID,key) DO
    . . SET notvalid=1
    . . DO LOGERROR^logger("sapiVld","IsNotValidAttrMetadata: unknown metadata key: `"_key_"` with value < "_AMeta(key)_" >")
    . ELSE  IF AMeta(key)="" DO
    . . SET notvalid=1
    . . DO LOGERROR^logger("sapiVld","IsNotValidAttrMetadata: empty value for metadata key: `"_key_"` with value < "_AMeta(key)_" >")
    . ELSE  IF isLangStrType IF '$$IsLangStr^utils(AMeta(key)) DO
    . . SET notvalid=1
    . . DO LOGERROR^logger("sapiVld","IsNotValidAttrMetadata: invalid value of type LANGSTR for key: `"_key_"`")
    . ELSE  IF isFnType IF '$$IsFunctionName^utils(AMeta(key)) DO
    . . SET notvalid=1
    . . DO LOGERROR^logger("sapiVld","IsNotValidAttrMetadata: invalid value of type FN for key: `"_key_"`")

    ; CHECK 2 — Structural validation
    ;           (does this metadata record contain the required fields?)
    ;           When the attribute does not yet exist in the schema, sys.attr.key and
    ;           sys.attr.isa are always mandatory; sys.attr.range and sys.attr.cardinality
    ;           are additionally required only when the entity type is sys.type.attr.
    IF eid<0 DO
    . IF missingKey!missingISA DO
    . . SET notvalid=1
    . . DO LOGERROR^logger("sapiVld","IsNotValidAttrMetadata: new attribute or entity type requires `sys.attr.key`, `sys.attr.isa`")
    . ELSE  IF (etype="sys.type.attr")&(missingRange!missingCardinality) DO
    . . SET notvalid=1
    . . DO LOGERROR^logger("sapiVld","IsNotValidAttrMetadata: new attribute requires `sys.attr.range` and `sys.attr.cardinality`")

    ; CHECK 3 — Structural validation
    ;           (does this metadata record contain the required fields?)
    ;           When the attribute already exists, only sys.attr.key is required to identify it.
    IF eid>0 DO
    . IF missingKey DO
    . . SET notvalid=1
    . . DO LOGERROR^logger("sapiVld","IsNotValidAttrMetadata: `sys.attr.key` is required to update an existing attribute")

    QUIT notvalid
