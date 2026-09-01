;; ===================================================================================== 
;; ^sapiBld - Subroutines for building process shared local arrays - This file is part of TaxisDB Platform
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

BuildKeysCatalog(ns) ; populate %Keys with schema attribute keys, optionally filtered by prefix
;;------------------------------------------------------------------
;; Function or Routine  : BuildKeysCatalog ; Routine (QUIT returns no value)
;;
;; Call     : DO BuildKeysCatalog^sapi("sandbox.movie")
;;
;; Usage    : DO BuildKeysCatalog^sapi("sandbox.movie")
;;            DO BuildKeysCatalog^sapi("sandbox")
;;            DO BuildKeysCatalog^sapi()
;;
;; Purpose  : Populates %Keys with all schema attribute keys, optionally
;;            filtered to those matching a given prefix. When ns is omitted
;;            or empty, all keys are returned.
;;
;; Parameters
;;   ns : (IN, optional) Namespace prefix string, e.g. "sandbox.movie".
;;        When supplied, only literals whose leading segment matches ns
;;        are included. When omitted, no filter is applied.
;;
;; Scope
;;   Reads  : ^TBDR(AKEYID,literal), ^TBAVET(AKEYID,valkey,eid)
;;   Writes : %Keys
;;------------------------------------------------------------------
    ; Output:
    ;   %Keys                     — root node holds total count
    ;   %Keys(eid,AKEYID,valkey)  = literal
    ;
    ; Example output (filtered):
    ;   %Keys=3
    ;   %Keys(700,210,"00A.18710")="sandbox.movie.title"

    NEW literal	; iterates key literals in ^TBDR(AKEYID,*)
    NEW valkey	; value key resolved for each matching literal
    NEW eid		; iterates entities that reference valkey via ^TBAVET

    KILL %Keys
    SET %Keys=0
    SET literal=""
    SET ns=$GET(ns,"")

    ; Walk every key literal, apply the optional prefix filter, resolve to entities
    FOR  SET literal=$ORDER(^TBDR(AKEYID,literal)) QUIT:literal=""  DO
    . IF ns'=""&($EXTRACT(literal,1,$LENGTH(ns))'=ns) QUIT ; prefix mismatch — skip
    . SET valkey=^TBDR(AKEYID,literal) ; valkey is guaranteed non-empty
    . SET eid=""
    . FOR  SET eid=$ORDER(^TBAVET(AKEYID,valkey,eid)) QUIT:eid=""  DO
    . . SET %Keys(eid,AKEYID,valkey)=literal
    . . SET %Keys=%Keys+1

    QUIT



BuildAttrsRequired(ns,ReqAttr) ; collect required attribute IDs for a schema prefix
;;------------------------------------------------------------------
;; Routine  : BuildAttrsRequired^sapiBld
;;
;; Call     : DO BuildAttrsRequired^sapiBld(ns,.ReqAttr)
;;
;; Usage    : Called before staging a record to know which attributes must
;;            be present, then checked against the caller's own data
;;
;; Purpose  : Populates ReqAttr with the attribute IDs of all required
;;            attributes for the given schema prefix.
;;
;; Parameters
;;   ns      : (IN)  Schema prefix string, e.g. "sandbox.movie"
;;   ReqAttr : (OUT) Local array, passed by reference
;;
;; Scope (Indirect Globals Access)
;;   Reads  : %Schema — populated internally via BuildSchemaView
;;------------------------------------------------------------------
    ; Output:
    ;   ReqAttr      = total count of required attributes
    ;   ReqAttr(aid) = attribute's own key string (from sys.attr.key),
    ;                  present only for attributes flagged sys.attr.required=1

    KILL ReqAttr
    NEW aid ; iterates every attribute in %Schema
    SET ReqAttr=0
    DO BuildSchemaView(ns)
    SET aid=""
    ; Keep only attributes flagged required, storing their key string for lookup
    FOR  SET aid=$ORDER(%Schema(aid)) QUIT:aid=""  DO
    . IF $GET(%Schema(aid,"sys.attr.required"))=1 DO
    . . SET ReqAttr(aid)=$GET(%Schema(aid,"sys.attr.key"))
    . . SET ReqAttr=$INCREMENT(ReqAttr)

    QUIT



BuildAttrsCache(ns,AttrsCache) ; build forward/reverse attribute caches for a namespace
;;------------------------------------------------------------------
;; Routine  : BuildAttrsCache^sapiBld
;;
;; Call     : DO BuildAttrsCache^sapiBld(ns,.AttrsCache)
;;
;; Usage    : DO BuildAttrsCache^sapiBld("sandbox",.AttrsCache)
;;
;; Purpose  : Builds a cache of schema attributes belonging to the specified
;;            namespace, always including the shared sys.attr namespace.
;;
;; Parameters
;;   ns         : (IN)  Namespace prefix, e.g. "sandbox" or "sandbox.movie"
;;   AttrsCache : (OUT) Local array, passed by reference
;;
;; Scope
;;   Reads  : ^TBDR(AKEYID,fullkey)
;;------------------------------------------------------------------
    ; Two entries are written per attribute:
    ;   AttrsCache(fullkey) = aid            — forward map, used by ResolveRecAttrs
    ;   AttrsCache(aid)     = sub-namespace  — reverse map, used by ValidateRecord
    ;                                          to check namespace membership without
    ;                                          a schema lookup per attribute
    ;
    ; Example:
    ;   AttrsCache("sandbox.movie.genre")  = 700
    ;   AttrsCache("sandbox.movie.imdbid") = 703
    ;   AttrsCache("sys.attr.key")         = 210
    ;   AttrsCache(700) = "sandbox.movie"
    ;   AttrsCache(703) = "sandbox.movie"
    ;   AttrsCache(210) = "sys.attr"

    NEW fullkey	; iterates registered attribute key strings in ^TBDR(AKEYID,*)
    NEW prefix	; current namespace + "." being matched against fullkey
    NEW nsIdx	; iterates nsList
    NEW nsList	; the two namespaces to scan: ns and the always-included sys.attr
    NEW aid		; resolved attribute entity ID for fullkey
    NEW nsDepth	; number of dot-separated segments in the current namespace,
    		; used so the reverse map keeps exactly that many segments of fullkey

    KILL AttrsCache

    ; Always include sys.attr namespace in addition to the requested namespace
    SET nsList(1)=ns
    SET nsList(2)="sys.attr"

	; Iterate over each namespace in nsList
    SET nsIdx=""
    FOR  SET nsIdx=$ORDER(nsList(nsIdx)) QUIT:nsIdx=""  DO
    . SET prefix=nsList(nsIdx)_"."
    . SET nsDepth=$LENGTH(nsList(nsIdx),".") ; e.g. "sandbox.movie" -> 2, "sandbox" -> 1
    . SET fullkey=""
    . ; Iterate over all registered attribute keys matching this namespace prefix
    . FOR  SET fullkey=$ORDER(^TBDR(AKEYID,fullkey)) QUIT:fullkey=""  DO
    . . IF $EXTRACT(fullkey,1,$LENGTH(prefix))'=prefix QUIT ; outside this namespace — skip
    . . SET aid=$$GetEID^sapiGet(fullkey)
    . . SET AttrsCache(fullkey)=aid                              ; forward map: key -> aid
    . . ; Reverse map: aid -> sub-namespace.
    . . ; sys.attr is flat — attribute names sit directly under sys.attr with
    . . ; no entity-type level in between (e.g. "sys.attr.key"), so nothing
    . . ; is stripped and the full fullkey is kept as-is.
    . . ; Every other namespace (e.g. "sandbox") has an entity-type segment
    . . ; between the namespace and the attribute name (e.g. "sandbox.movie.genre"),
    . . ; so the trailing attribute-name segment is stripped via $PIECE,
    . . ; leaving the entity-type-qualified sub-namespace (e.g. "sandbox.movie").
    . . SET AttrsCache(aid)=$SELECT(nsList(nsIdx)="sys.attr":fullkey,1:$PIECE(fullkey,".",1,nsDepth))

    QUIT


BuildSchemaView(ns) ; populate %Schema with resolved schema attributes under a key prefix
;;------------------------------------------------------------------
;; Routine  : BuildSchemaView^sapiBld
;;
;; Call     : DO BuildSchemaView^sapiBld("sandbox.movie")
;;
;; Usage    : DO BuildSchemaView^sapiBld("sandbox.movie") ; then read %Schema
;;
;; Purpose  : Populates %Schema with all schema attributes whose key matches
;;            a given prefix, with all metadata resolved to human-readable strings.
;;
;; Parameters
;;   ns : (IN) Key prefix string, e.g. "sandbox.movie"
;;
;; Scope
;;   Reads  : ^TBEAVT(eid,aid,valkey)
;;   Writes : %Schema
;;
;; Scope (Indirect Globals Access)
;;   Reads  : %Keys — populated by BuildKeysCatalog
;;------------------------------------------------------------------
    NEW eid		; iterates entities from %Keys
    NEW aid		; iterates attribute IDs under each entity in ^TBEAVT
    NEW valkey	; first value key found under each (eid,aid)
    NEW akey	; human-readable attribute label, resolved from aid
    NEW val		; human-readable value, resolved from (aid,valkey)

    KILL %Schema
    SET %Schema=0

    DO BuildKeysCatalog(ns)
    
    ;   1. BuildKeysCatalog populate %Keys with all eids matching prefix
    ;   2. For each eid iterate all assertions in ^TBEAVT(eid,aid,valkey)
    ;   3. Resolve aid -> akey via $$AttrIDToLabel(aid)
    ;   4. Resolve valkey -> val via $$AttrValKeyToLabel(aid,valkey)
    ;
    ; Output:
    ;   %Schema             — root node holds total count of assertions resolved
    ;   %Schema(eid,akey)   = val
    ;
    ; Example output:
    ;   %Schema=16
    ;   %Schema(700,"sys.attr.cardinality")="sys.enum.cardinality.one"
    ;   %Schema(700,"sys.attr.description")="The title of the movie"
    ;   %Schema(700,"sys.attr.range")="sys.val.string"
    ;   %Schema(700,"sys.attr.key")="sandbox.movie.title"
    
    SET eid=""
    ; Walk every entity that matched the prefix, then every attribute under it
    FOR  SET eid=$ORDER(%Keys(eid)) QUIT:eid=""  DO
    . SET aid=""
    . FOR  SET aid=$ORDER(^TBEAVT(eid,aid)) QUIT:aid=""  DO
    . . SET akey=$$GetKey^sapiGet(aid)
    . . IF akey="" QUIT ; unresolvable attribute — skip to next aid
    . . SET valkey=$ORDER(^TBEAVT(eid,aid,""))
    . . IF valkey="" QUIT ; no value stored under this attribute — skip to next aid
    . . SET val=$$GetDictValue^sapiGet(aid,valkey)
    . . SET %Schema(eid,akey)=val
    . . SET %Schema=$INCREMENT(%Schema)

    QUIT

