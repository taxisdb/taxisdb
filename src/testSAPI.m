;; ================================================================================ 
;; ^testSAPI - TBox Schema Data Access API - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 		— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;; =================================================================================
;;
;; OVERVIEW
;;
;; Full testing suite for sapi.m — the schema transaction engine
;; responsible for creating and updating TBox entities
;; (attributes, entity types, enumerations and metadata).
;;
;; Tests are organised by execution layer, beginning with the
;; primitive lookup routines and progressing through validation,
;; value resolution, record staging and finally full schema
;; transactions.
;;
;; LAYER A — 26 Tests - Primitive SAPI routines
;; LAYER B —  8 Tests - Metadata validation
;; LAYER C —  8 Tests - Record staging
;; LAYER D —  8 Tests - Full Schema Pipeline
;; LAYER X —  8 Tests - Cross-cutting invariants
;; ---------------------------------------------------------------------------------------
;; TOTAL TESTS: 58
;; ---------------------------------------------------------------------------------------
;; Each layer isolates one stage of the schema pipeline so failures
;; can be localized quickly.
;;
;; Every test performs a real runtime check via 
;; AssertTrue, AssertFalse, AssertEqual helper functions 
;; comparing actual state against expected outcomes
;;
;; ------------------------------------------------------------
;; USAGE
;;
;;   D Run^testAPI("B14")     ; run a single numbered test
;;   D RunLayer^testAPI("D")  ; run every test in one layer
;;
;; ------------------------------------------------------------
INIT	
	D ^init
    D ResetCounters    
    QUIT


Run(test)
    NEW label
    SET label="Test"_test
    WRITE !!,">>>>>>>>>>>>>>>> ",label
    IF $TEXT(@label)="" DO  QUIT
    . WRITE !,"ERROR: Test not found: ",label,!
    DO @label
    QUIT


RunLayer(layer)
    NEW routine
    D ResetCounters
    SET routine="Layer"_layer
    WRITE !!,"================ ",routine

    DO @routine
    D PrintSummary
    QUIT

; ====================================================================================================
; TEST RESULT MANAGEMENT
; ====================================================================================================
; Maintains global counters for PASS/FAIL results across all SAPI tests.
; ====================================================================================================
ResetCounters
    SET ^TESTCNT("PASS")=0
    SET ^TESTCNT("FAIL")=0
    KILL ^TESTFAIL
    QUIT


RecordPass
    SET ^TESTCNT("PASS")=$GET(^TESTCNT("PASS"))+1
    QUIT


RecordFail(msg)
    SET ^TESTCNT("FAIL")=$GET(^TESTCNT("FAIL"))+1
    SET ^TESTFAIL($INCREMENT(^TESTFAIL))=msg
    QUIT


PrintSummary
    NEW total,pct,i

    SET total=$GET(^TESTCNT("PASS"))+$GET(^TESTCNT("FAIL"))

    WRITE !!,"=== Test Result Summary ===",!
    WRITE "PASS : ",$GET(^TESTCNT("PASS")),!
    WRITE "FAIL : ",$GET(^TESTCNT("FAIL")),!
    WRITE "TOTAL: ",total,!

    IF total>0 DO
    . SET pct=(^TESTCNT("PASS")/total)*100
    . WRITE "Pass rate: ",$FNUMBER(pct,"",1),"%",!

    IF $GET(^TESTCNT("FAIL"))>0 DO
    . WRITE !,"=== Failed cases ===",!
    . SET i=""
    . FOR  SET i=$ORDER(^TESTFAIL(i)) QUIT:i=""  WRITE "- ",^TESTFAIL(i),!

    QUIT


; ====================================================================================================
; TEST ASSERTION HELPERS
; ====================================================================================================
;
; Generic assertion helpers used by all SAPI test layers.
;
; These helpers:
;   - Standardize PASS / FAIL output
;   - Keep individual tests focused on expected behavior
;   - Allow future aggregation of failures
;
; ====================================================================================================
AssertTrue(msg,value)
    IF value DO
    . WRITE !,"PASS: ",msg,!
    . WRITE !,"=======================================================",!
    . D RecordPass
    ELSE  DO
    . WRITE !,"FAIL: ",msg,!
    . WRITE !,"=======================================================",!
    . D RecordFail(msg)
    QUIT


AssertFalse(msg,value)
    IF 'value DO
    . WRITE !,"PASS: ",msg,!
    . WRITE !,"=======================================================",!
    . D RecordPass
    ELSE  DO
    . WRITE !,"FAIL: ",msg,!
    . WRITE !,"=======================================================",!
    . D RecordFail(msg)
    QUIT


AssertEqual(msg,actual,expected)
    IF actual=expected DO
    . WRITE !,"PASS: ",msg,!
    . WRITE !,"=======================================================",!
    . D RecordPass
    ELSE  DO
    . WRITE !,"FAIL: ",msg," expected <",expected,"> got <",actual,">",!
    . WRITE !,"=======================================================",!
    . D RecordFail(msg_" expected <"_expected_"> got <"_actual_">")
    QUIT


; ====================================================================================================
; TEST SUITES
; ====================================================================================================
;
; LAYER A — Primitive SAPI routines
;
; Purpose:
;   Validate low-level schema dictionary and metadata operations.
;
; Scope:
;   - Schema attribute lookup
;   - Range value resolution
;   - Attribute metadata flags
;   - Reference value handling
;   - Dictionary key generation
;
; No schema staging or transaction persistence tests are performed here.
;
; ====================================================================================================
LayerA
    DO TestA1
    DO TestA2
    DO TestA3
    DO TestA4
    DO TestA5
    DO TestA6
    DO TestA7
    DO TestA8
    DO TestA9
    DO TestA10
    DO TestA11
    DO TestA12
    DO TestA13
    DO TestA14
    DO TestA15
    DO TestA16
    DO TestA17
    DO TestA18
    DO TestA19
    DO TestA20
    DO TestA21
    DO TestA22
    DO TestA23
    DO TestA24
    DO TestA25
    DO TestA26
    QUIT


TestA1 ; GetEID existing attribute
;;------------------------------------------------------------------
;; A1: GetEID existing attribute
;;
;; Purpose : Confirms GetEID resolves a known, already-registered
;;           attribute key to a positive entity ID.
;;
;; Expected final state :
;; eid is greater than 0.
;;------------------------------------------------------------------
    WRITE !,"A1: GetEID existing attribute"
    NEW eid
    SET eid=$$GetEID^sapiGet("sys.attr.key")
    DO AssertTrue("A1: GetEID existing attribute",eid>0)
    QUIT


TestA2 ; GetEID unknown attribute
;;------------------------------------------------------------------
;; A2: GetEID unknown attribute
;;
;; Purpose : Confirms GetEID returns -1 for an attribute key that
;;           does not exist anywhere in the schema.
;;
;; Expected final state :
;; eid equals -1.
;;------------------------------------------------------------------
    WRITE !,"A2: GetEID unknown attribute"
    NEW eid
    SET eid=$$GetEID^sapiGet("sys.attr.foobar")
    DO AssertEqual("A2: GetEID unknown attribute",eid,-1)
    QUIT


TestA3 ; IsRangeValue existing literal
;;------------------------------------------------------------------
;; A3: IsRangeValue existing value
;;
;; Purpose : Confirms IsRangeValue returns true for a value already
;;           registered in ^TBDR under the AKEYID attribute.
;;
;; Expected final state :
;; ok is true.
;;------------------------------------------------------------------
    WRITE !,"A3: IsRangeValue existing value"
    NEW ok
    SET ok=$$IsRangeValue^sapiVld(AKEYID,"sys.attr.key")
    DO AssertTrue("A3: IsRangeValue existing value",ok)
    QUIT


TestA4 ; IsRangeValue unknown literal
;;------------------------------------------------------------------
;; A4: IsRangeValue missing value
;;
;; Purpose : Confirms IsRangeValue returns false for a value that has
;;           never been registered under the AKEYID attribute.
;;
;; Expected final state :
;; ok is false.
;;------------------------------------------------------------------
    WRITE !,"A4: IsRangeValue missing value"
    NEW ok
    SET ok=$$IsRangeValue^sapiVld(AKEYID,"sys.attr.foobar")
    DO AssertFalse("A4: IsRangeValue missing value",ok)
    QUIT


TestA5 ; IsRefValType
;;------------------------------------------------------------------
;; A5: IsRefValType
;;
;; Purpose : Confirms IsRefValType correctly identifies sys.attr.range
;;           as a reference-typed attribute.
;;
;; Expected final state :
;; ok is true.
;;------------------------------------------------------------------
    WRITE !,"A5: IsRefValType"
    NEW ok
    SET ok=$$IsRefValType^sapiVld($$GetEID^sapiGet("sys.attr.range"))
    DO AssertTrue("A5: IsRefValType",ok)
    QUIT


TestA6 ; IsLangStrValType
;;------------------------------------------------------------------
;; A6: IsLangStrValType
;;
;; Purpose : Confirms IsLangStrValType correctly identifies
;;           sys.attr.description as a language-string-typed attribute.
;;
;; Expected final state :
;; ok is true.
;;------------------------------------------------------------------
    WRITE !,"A6: IsLangStrValType"
    NEW ok
    SET ok=$$IsLangStrValType^sapiVld($$GetEID^sapiGet("sys.attr.description"))
    DO AssertTrue("A6: IsLangStrValType",ok)
    QUIT


TestA7 ; IsUniqueInsert
;;------------------------------------------------------------------
;; A7: IsUniqueInsert
;;
;; Purpose : Confirms IsUniqueInsert correctly identifies
;;           sandbox.movie.imdbid as an insert-unique attribute.
;;
;; Expected final state :
;; ok is true.
;;------------------------------------------------------------------
    WRITE !,"A7: IsUniqueInsert"
    NEW ok
    SET ok=$$IsUniqueInsert^sapiVld($$GetEID^sapiGet("sandbox.movie.imdbid"))
    DO AssertTrue("A7: IsUniqueInsert",ok)
    QUIT


TestA8 ; IsUniqueUpsert
;;------------------------------------------------------------------
;; A8: IsUniqueUpsert
;;
;; Purpose : Confirms IsUniqueUpsert correctly identifies
;;           sandbox.movie.tmdbid as an upsert-unique attribute.
;;
;; Expected final state :
;; ok is true.
;;------------------------------------------------------------------
    WRITE !,"A8: IsUniqueUpsert"
    NEW ok
    SET ok=$$IsUniqueUpsert^sapiVld($$GetEID^sapiGet("sandbox.movie.tmdbid"))
    DO AssertTrue("A8: IsUniqueUpsert",ok)
    QUIT


TestA9 ; IsMultiValue
;;------------------------------------------------------------------
;; A9: IsMultiValue
;;
;; Purpose : Confirms IsMultiValue correctly identifies
;;           sandbox.movie.genre as a multi-valued attribute.
;;
;; Expected final state :
;; ok is true.
;;------------------------------------------------------------------
    WRITE !,"A9: IsMultiValue"
    NEW ok
    SET ok=$$IsMultiValue^sapiVld($$GetEID^sapiGet("sandbox.movie.genre"))
    DO AssertTrue("A9: IsMultiValue",ok)
    QUIT


TestA10 ; IsRequired
;;------------------------------------------------------------------
;; A10: IsRequired
;;
;; Purpose : Confirms IsRequired correctly identifies
;;           sandbox.movie.title as a required attribute.
;;
;; Expected final state :
;; ok is true.
;;------------------------------------------------------------------
    WRITE !,"A10: IsRequired"
    NEW ok
    SET ok=$$IsRequired^sapiVld($$GetEID^sapiGet("sandbox.movie.title"))
    DO AssertTrue("A10: IsRequired",ok)
    QUIT


TestA11 ; GetRefValKey
;;------------------------------------------------------------------
;; A11: GetRefValKey
;;
;; Purpose : Confirms GetRefValKey resolves a scoped enum label
;;           ("sys.enum.cardinality.one" under "sys.attr.cardinality")
;;           to a non-empty value key.
;;
;; Expected final state :
;; vk is not empty.
;;------------------------------------------------------------------
    WRITE !,"A11: GetRefValKey"
    NEW vk
    SET vk=$$GetRefValKey^sapiGet("sys.enum.cardinality.one","sys.attr.cardinality")
    DO AssertTrue("A11: GetRefValKey",vk'="")
    QUIT


TestA12 ; GetKey
;;------------------------------------------------------------------
;; A12: GetKey
;;
;; Purpose : Confirms GetKey resolves an attribute eid back to
;;           its original schema key label.
;;
;; Expected final state :
;; lbl equals "sys.attr.cardinality".
;;------------------------------------------------------------------
    WRITE !,"A12: GetKey"
    NEW lbl
    SET lbl=$$GetKey^sapiGet($$GetEID^sapiGet("sys.attr.cardinality"))
    DO AssertEqual("A12: GetKey",lbl,"sys.attr.cardinality")
    QUIT


TestA13 ; GetDictValue
;;------------------------------------------------------------------
;; A13: GetDictValue
;;
;; Purpose : Confirms GetDictValue resolves a valkey back to its
;;           original enum label, scoped to the correct attribute.
;;
;; Expected final state :
;; val equals "sys.enum.cardinality.one".
;;------------------------------------------------------------------
    WRITE !,"A13: GetDictValue"
    NEW aid,vk,val

    SET aid=$$GetEID^sapiGet("sys.attr.cardinality")
    SET vk=$$GetRefValKey^sapiGet("sys.enum.cardinality.one","sys.attr.cardinality")
    SET val=$$GetDictValue^sapiGet(aid,vk)

    DO AssertEqual("A13: GetDictValue",val,"sys.enum.cardinality.one")
    QUIT


TestA14 ; IsNewRangeValue existing value
;;------------------------------------------------------------------
;; A14: IsNewRangeValue existing value
;;
;; Purpose : Confirms IsNewRangeValue returns false for a value that
;;           is already registered under the AKEYID attribute.
;;
;; Expected final state :
;; ok is false.
;;------------------------------------------------------------------
    WRITE !,"A14: IsNewRangeValue existing value"
    NEW ok
    SET ok=$$IsNewRangeValue^sapiVld(AKEYID,"sys.attr.key")
    DO AssertFalse("A14: IsNewRangeValue existing value",ok)
    QUIT


TestA15 ; IsNewRangeValue new value
;;------------------------------------------------------------------
;; A15: IsNewRangeValue new value
;;
;; Purpose : Confirms IsNewRangeValue returns true for a value that
;;           has never been registered under the AKEYID attribute.
;;
;; Expected final state :
;; ok is true.
;;------------------------------------------------------------------
    WRITE !,"A15: IsNewRangeValue new value"
    NEW ok
    SET ok=$$IsNewRangeValue^sapiVld(AKEYID,"sandbox.this.value.does.not.exist")
    DO AssertTrue("A15: IsNewRangeValue new value",ok)
    QUIT


TestA16 ; CreateNewValKey missing parameters
;;------------------------------------------------------------------
;; A16: CreateNewValKey missing parameters
;;
;; Purpose : Confirms CreateNewValKey rejects a call with no
;;           parameters supplied, rather than allocating a key.
;;
;; Expected final state :
;; key equals -1.
;;------------------------------------------------------------------
    WRITE !,"A16: CreateNewValKey missing parameters"
    NEW key
    SET key=$$CreateNewValKey^sapiRslv
    DO AssertEqual("A16: CreateNewValKey missing parameters",key,-1)
    QUIT


TestA17 ; Resolve attribute existing reference
;;------------------------------------------------------------------
;; A17: Resolve attribute existing reference
;;
;; Purpose : Confirms ResolveAttrRef resolves an already-registered
;;           TBox enum label to its existing value key, without
;;           allocating a new one.
;;
;; Expected final state :
;; vk is not empty and isNew is 0.
;;------------------------------------------------------------------
    WRITE !,"A17: Resolve attribute existing reference"
    NEW aid,vk,isNew

    SET aid=$$GetEID^sapiGet("sys.attr.cardinality")    
    SET isNew=$$ResolveAttrRef^sapiRslv(aid,"sys.enum.cardinality.one",.vk,"TBox")

    DO AssertTrue("A17: Resolve attribute existing reference",(vk'="")&(isNew=0))
    QUIT


TestA18 ; Resolve attribute value - new literal
;;------------------------------------------------------------------
;; A18: Resolve attribute value - new literal
;;
;; Purpose : Confirms RegisterAttrVal allocates a new value key for a
;;           literal value that has never been registered before.
;;
;; Expected final state :
;; vk is not empty and isNew is 1.
;;------------------------------------------------------------------
    WRITE !,"A18: Resolve attribute value - new literal"
    NEW aid,vk,isNew,val
    SET aid=$$GetEID^sapiGet("sys.attr.key")
    SET val="sandbox.test."_+$HOROLOG_"_"_$PIECE($HOROLOG,",",2)
    SET isNew=$$RegisterAttrVal^sapiRslv(aid,val,.vk)
    DO AssertTrue("A18: Resolve attribute value - new literal",(vk'="")&(isNew=1))
    QUIT


TestA19 ; Resolve attribute value - existing literal reuse
;;------------------------------------------------------------------
;; A19: Resolve attribute value - existing literal reuse
;;
;; Purpose : Confirms RegisterAttrVal reuses the same value key on
;;           repeated calls for an already-registered literal value.
;;
;; Expected final state :
;; vk1 equals vk2, and both calls report isNew=0.
;;------------------------------------------------------------------
    WRITE !,"A19: Resolve attribute value - existing literal reuse"
    NEW aid,vk1,vk2,isNew1,isNew2

    SET aid=$$GetEID^sapiGet("sys.attr.key")

    SET isNew1=$$RegisterAttrVal^sapiRslv(aid,"sandbox.movie.title",.vk1)
    SET isNew2=$$RegisterAttrVal^sapiRslv(aid,"sandbox.movie.title",.vk2)

    DO AssertTrue("A19: Resolve attribute value - existing literal reuse",(vk1=vk2)&(isNew1=0)&(isNew2=0))
    QUIT


TestA20 ; Resolve attribute value - idempotence
;;------------------------------------------------------------------
;; A20: Resolve attribute value - idempotence
;;
;; Purpose : Confirms RegisterAttrVal allocates a new key on first
;;           registration of a fresh literal value, then reuses that
;;           same key on a second call for the identical value.
;;
;; Expected final state :
;; vk1 equals vk2; isNew1 is 1 (allocated); isNew2 is 0 (reused).
;;------------------------------------------------------------------
    WRITE !,"A20: Resolve attribute value - idempotence"
    NEW aid,val,vk1,vk2,isNew1,isNew2

    SET aid=$$GetEID^sapiGet("sys.attr.range")

    ; Use a synthetic value guaranteed not to collide with pre-seeded schema data
    SET val="testA20."_$HOROLOG

    SET isNew1=$$RegisterAttrVal^sapiRslv(aid,val,.vk1)
    SET isNew2=$$RegisterAttrVal^sapiRslv(aid,val,.vk2)

    ; First call must allocate a new key (isNew1=1); second call must find
    ; and reuse the same key (isNew2=0), with vk1=vk2 both times.
    DO AssertTrue("A20: Resolve attribute value - idempotence",(vk1=vk2)&(isNew1=1)&(isNew2=0))
    QUIT

TestA21 ; IsUniqueInsert non unique
;;------------------------------------------------------------------
;; A21: IsUniqueInsert non unique
;;
;; Purpose : Confirms IsUniqueInsert returns false for an attribute that is not
;;           flagged insert-unique.
;;
;; Expected final state :
;; ok equals 0.
;;------------------------------------------------------------------
    WRITE !,"A21: IsUniqueInsert non unique"
    NEW ok
    SET ok=$$IsUniqueInsert^sapiVld($$GetEID^sapiGet("sandbox.movie.title"))
    DO AssertTrue("A21: IsUniqueInsert non unique",ok=0)
    QUIT

TestA22 ; IsUniqueInsert positive
;;------------------------------------------------------------------
;; A22: IsUniqueInsert positive
;;
;; Purpose : Confirms IsUniqueInsert returns true for an attribute flagged
;;           insert-unique.
;;
;; Expected final state :
;; ok equals 1.
;;------------------------------------------------------------------
    WRITE !,"A22: IsUniqueInsert positive"
    NEW ok
    SET ok=$$IsUniqueInsert^sapiVld($$GetEID^sapiGet("sandbox.movie.imdbid"))
    DO AssertTrue("A22: IsUniqueInsert positive",ok=1)
    QUIT

TestA23 ; IsUniqueUpsert non unique
;;------------------------------------------------------------------
;; A23: IsUniqueUpsert non unique
;;
;; Purpose : Confirms IsUniqueUpsert returns false for an attribute that is not
;;           flagged upsert-unique.
;;
;; Expected final state :
;; ok equals 0.
;;------------------------------------------------------------------
    WRITE !,"A23: IsUniqueUpsert non unique"
    NEW ok
    SET ok=$$IsUniqueUpsert^sapiVld($$GetEID^sapiGet("sandbox.movie.title"))
    DO AssertTrue("A23: IsUniqueUpsert non unique",ok=0)
    QUIT

TestA24 ; IsUniqueUpsert positive
;;------------------------------------------------------------------
;; A24: IsUniqueUpsert positive
;;
;; Purpose : Confirms IsUniqueUpsert returns true for an attribute flagged
;;           upsert-unique.
;;
;; Expected final state :
;; ok equals 1.
;;------------------------------------------------------------------
    WRITE !,"A24: IsUniqueUpsert positive"
    NEW ok
    SET ok=$$IsUniqueUpsert^sapiVld($$GetEID^sapiGet("sandbox.movie.tmdbid"))
    DO AssertTrue("A24: IsUniqueUpsert positive",ok=1)
    QUIT

TestA25 ; IsUniqueInsert invalid aid
;;------------------------------------------------------------------
;; A25: IsUniqueInsert invalid aid
;;
;; Purpose : Confirms IsUniqueInsert returns false for an aid that does not
;;           correspond to any registered attribute.
;;
;; Expected final state :
;; ok equals 0.
;;------------------------------------------------------------------
    WRITE !,"A25: IsUniqueInsert invalid aid"
    NEW ok
    SET ok=$$IsUniqueInsert^sapiVld(999999)
    DO AssertTrue("A25: IsUniqueInsert invalid aid",ok=0)
    QUIT

TestA26 ; IsUniqueUpsert invalid aid
;;------------------------------------------------------------------
;; A26: IsUniqueUpsert invalid aid
;;
;; Purpose : Confirms IsUniqueUpsert returns false for an aid that does not
;;           correspond to any registered attribute.
;;
;; Expected final state :
;; ok equals 0.
;;------------------------------------------------------------------
    WRITE !,"A26: IsUniqueUpsert invalid aid"
    NEW ok
    SET ok=$$IsUniqueUpsert^sapiVld(999999)
    DO AssertTrue("A26: IsUniqueUpsert invalid aid",ok=0)
    QUIT



;==============================================================
; LAYER B — Metadata validation
;
; Tests NotValidMetadata() and the validation stage of Stage().
; No transaction should be committed by these tests.
;==============================================================
LayerB
    DO TestB1
    DO TestB2
    DO TestB3
    DO TestB4
    DO TestB5
    DO TestB6
    DO TestB7
    DO TestB8
    QUIT

TestB1 ; Missing sys.attr.key
;;------------------------------------------------------------------
;; B1: Missing sys.attr.key
;;
;; Purpose : Confirms Stage rejects a record that omits the required sys.attr.key field.
;;
;; Expected final state :
;; %TBR("count") equals 0 — nothing staged.
;;------------------------------------------------------------------
    WRITE !,"B1: Missing sys.attr.key"
    DO INIT^sapi
    KILL Attr

    SET Attr(1,cardin)=ONE
    SET Attr(1,range)=STRING

    DO Stage^sapi(.Attr,"sandbox")

    DO AssertTrue("B1: Missing sys.attr.key rejected",%TBR("count")=0)
    QUIT


TestB2 ; Missing sys.attr.cardinality
;;------------------------------------------------------------------
;; B2: Missing sys.attr.cardinality
;;
;; Purpose : Confirms Stage rejects a record that omits the required sys.attr.cardinality field.
;;
;; Expected final state :
;; %TBR("count") equals 0 — nothing staged.
;;------------------------------------------------------------------
    WRITE !,"B2: Missing sys.attr.cardinality"
    DO INIT^sapi
    KILL Attr

    SET Attr(1,key)="sandbox.movie.director"
    SET Attr(1,range)=STRING
    SET Attr(1,isa)=ATYPE

    DO Stage^sapi(.Attr,"sandbox")

    DO AssertTrue("B2: Missing cardinality rejected",%TBR("count")=0)
    QUIT


TestB3 ; Missing sys.attr.range
;;------------------------------------------------------------------
;; B3: Missing sys.attr.range
;;
;; Purpose : Confirms Stage rejects a record that omits the required sys.attr.range field.
;;
;; Expected final state :
;; %TBR("count") equals 0 — nothing staged.
;;------------------------------------------------------------------
    WRITE !,"B3: Missing sys.attr.range"
    DO INIT^sapi
    KILL Attr

    SET Attr(1,key)="sandbox.movie.director"
    SET Attr(1,cardin)=ONE
    SET Attr(1,isa)=ATYPE

    DO Stage^sapi(.Attr,"sandbox")

    DO AssertTrue("B3: Missing range rejected",%TBR("count")=0)
    QUIT


TestB4 ; Missing sys.attr.isa
;;------------------------------------------------------------------
;; B4: Missing sys.attr.isa
;;
;; Purpose : Confirms Stage rejects a record that omits the required sys.attr.isa field.
;;
;; Expected final state :
;; %TBR("count") equals 0 — nothing staged.
;;------------------------------------------------------------------
    WRITE !,"B4: Missing sys.attr.isa"
    DO INIT^sapi
    KILL Attr

    SET Attr(1,key)="sandbox.movie.director"
    SET Attr(1,cardin)=ONE
    SET Attr(1,range)=STRING

    DO Stage^sapi(.Attr,"sandbox")

    DO AssertTrue("B4: Missing isa rejected",%TBR("count")=0)
    QUIT


TestB5 ; Unknown metadata key
;;------------------------------------------------------------------
;; B5: Unknown metadata key
;;
;; Purpose : Confirms Stage rejects a record containing a metadata key not recognised anywhere in the schema.
;;
;; Expected final state :
;; %TBR("count") equals 0 — nothing staged.
;;------------------------------------------------------------------
    WRITE !,"B5: Unknown metadata key"
    DO INIT^sapi
    KILL Attr

    SET Attr(1,key)="sandbox.movie.title"
    SET Attr(1,cardin)=ONE
    SET Attr(1,range)=STRING
    SET Attr(1,isa)=ATYPE
    SET Attr(1,"sys.foobar.description")="foobar"

    DO Stage^sapi(.Attr,"sandbox")

    DO AssertTrue("B5: Unknown metadata key rejected",%TBR("count")=0)
    QUIT


TestB6 ; Empty metadata value
;;------------------------------------------------------------------
;; B6: Empty metadata value
;;
;; Purpose : Confirms Stage rejects a record whose metadata value is an empty string.
;;
;; Expected final state :
;; %TBR("count") equals 0 — nothing staged.
;;------------------------------------------------------------------
    WRITE !,"B6: Empty metadata value"
    DO INIT^sapi
    KILL Attr

    SET Attr(1,key)="sandbox.movie.title"
    SET Attr(1,cardin)=ONE
    SET Attr(1,range)=STRING
    SET Attr(1,isa)=ATYPE
    SET Attr(1,doc)=""

    DO Stage^sapi(.Attr,"sandbox")

    DO AssertTrue("B6: Empty metadata rejected",%TBR("count")=0)
    QUIT


TestB7 ; Invalid LANGSTR metadata
;;------------------------------------------------------------------
;; B7: Invalid LANGSTR
;;
;; Purpose : Confirms Stage rejects a doc/description value that is not correctly formatted as a language-tagged string.
;;
;; Expected final state :
;; %TBR("count") equals 0 — nothing staged.
;;------------------------------------------------------------------
    WRITE !,"B7: Invalid LANGSTR"
    DO INIT^sapi
    KILL Attr

    SET Attr(1,key)="sandbox.movie.title"
    SET Attr(1,cardin)=ONE
    SET Attr(1,range)=STRING
    SET Attr(1,isa)=ATYPE
    SET Attr(1,doc)="Movie title"

    DO Stage^sapi(.Attr,"sandbox")

    DO AssertTrue("B7: Invalid LANGSTR rejected",%TBR("count")=0)
    QUIT


TestB8 ; Valid minimum metadata
;;------------------------------------------------------------------
;; B8: Valid minimum metadata
;;
;; Purpose : Confirms Stage successfully stages a record containing only the minimum required fields.
;;
;; Expected final state :
;; %TBR("count") equals 1 — record staged.
;;------------------------------------------------------------------
    WRITE !,"B8: Valid minimum metadata"
    DO INIT^sapi
    KILL Attr

    SET Attr(1,key)="sandbox.movie.test"
    SET Attr(1,cardin)=ONE
    SET Attr(1,range)=STRING
    SET Attr(1,isa)=ATYPE

    DO Stage^sapi(.Attr,"sandbox")

    DO AssertTrue("B8: Valid metadata staged",%TBR("count")=1)
    QUIT




;==============================================================
; LAYER C — Record staging
;
; Tests AddDatom() and AddRecord().
;==============================================================

LayerC
    DO TestC1
    DO TestC2
    DO TestC3
    DO TestC4
    DO TestC5
    DO TestC6
    DO TestC7
    DO TestC8
    QUIT


TestC1 ; Stage minimal attribute
;;------------------------------------------------------------------
;; C1: Stage minimal attribute
;;
;; Purpose : Confirms Stage stages a record containing only the minimum required fields.
;;
;; Expected final state :
;; %TBR is populated.
;;------------------------------------------------------------------
    WRITE !,"C1: Stage minimal attribute"

    DO INIT^sapi
    KILL Attr

    SET Attr(1,key)="sandbox.stage.title"
    SET Attr(1,range)=STRING
    SET Attr(1,cardin)=ONE
    SET Attr(1,isa)=ATYPE

    DO Stage^sapi(.Attr,"sandbox")

    DO AssertTrue("C1: Minimal attribute staged",$DATA(%TBR))

    QUIT


TestC2 ; Stage attribute with documentation
;;------------------------------------------------------------------
;; C2: Stage attribute with documentation
;;
;; Purpose : Confirms Stage stages a record that includes a sys.attr.description value.
;;
;; Expected final state :
;; %TBR is populated.
;;------------------------------------------------------------------
    WRITE !,"C2: Stage attribute with documentation"

    DO INIT^sapi
    KILL Attr

    SET Attr(1,key)="sandbox.stage.doc"
    SET Attr(1,range)=STRING
    SET Attr(1,cardin)=ONE
    SET Attr(1,isa)=ATYPE
    SET Attr(1,doc)="Documentation @en"

    DO Stage^sapi(.Attr,"sandbox")

    DO AssertTrue("C2: Attribute documentation staged",$DATA(%TBR))

    QUIT


TestC3 ; Stage attribute with alias
;;------------------------------------------------------------------
;; C3: Stage attribute with alias
;;
;; Purpose : Confirms Stage stages a record that includes a sys.attr.alias value.
;;
;; Expected final state :
;; %TBR is populated.
;;------------------------------------------------------------------
    WRITE !,"C3: Stage attribute with alias"

    DO INIT^sapi
    KILL Attr

    SET Attr(1,key)="sandbox.stage.alias"
    SET Attr(1,range)=STRING
    SET Attr(1,cardin)=ONE
    SET Attr(1,isa)=ATYPE
    SET Attr(1,alias)="title"

    DO Stage^sapi(.Attr,"sandbox")

    DO AssertTrue("C3: Attribute alias staged",$DATA(%TBR))

    QUIT


TestC4 ; Stage attribute with validator
;;------------------------------------------------------------------
;; C4: Stage attribute with validator
;;
;; Purpose : Confirms Stage stages a record that includes a sys.attr.validationfn value.
;;
;; Expected final state :
;; %TBR is populated.
;;------------------------------------------------------------------
    WRITE !,"C4: Stage attribute with validator"

    DO INIT^sapi
    KILL Attr

    SET Attr(1,key)="sandbox.stage.valid"
    SET Attr(1,range)=STRING
    SET Attr(1,cardin)=ONE
    SET Attr(1,isa)=ATYPE
    SET Attr(1,validfn)="$$IsLangStr^utils"

    DO Stage^sapi(.Attr,"sandbox")

    DO AssertTrue("C4: Attribute validator staged",$DATA(%TBR))

    QUIT


TestC5 ; Stage attribute with uniqueness
;;------------------------------------------------------------------
;; C5: Stage attribute with uniqueness
;;
;; Purpose : Confirms Stage stages a record that includes a sys.attr.unique value.
;;
;; Expected final state :
;; %TBR is populated.
;;------------------------------------------------------------------
    WRITE !,"C5: Stage attribute with uniqueness"

    DO INIT^sapi
    KILL Attr

    SET Attr(1,key)="sandbox.stage.unique"
    SET Attr(1,range)=STRING
    SET Attr(1,cardin)=ONE
    SET Attr(1,isa)=ATYPE
    SET Attr(1,unq)=UNQINSERT

    DO Stage^sapi(.Attr,"sandbox")

    DO AssertTrue("C5: Unique attribute staged",$DATA(%TBR))

    QUIT


TestC6 ; Stage multiple attributes
;;------------------------------------------------------------------
;; C6: Stage multiple attributes
;;
;; Purpose : Confirms Stage stages every valid record in a multi-record batch.
;;
;; Expected final state :
;; %TBR("count") equals 2.
;;------------------------------------------------------------------
    WRITE !,"C6: Stage multiple attributes"

    DO INIT^sapi
    KILL Attr

    SET Attr(1,key)="sandbox.stage.one"
    SET Attr(1,range)=STRING
    SET Attr(1,cardin)=ONE
    SET Attr(1,isa)=ATYPE

    SET Attr(2,key)="sandbox.stage.two"
    SET Attr(2,range)=INT
    SET Attr(2,cardin)=ONE
    SET Attr(2,isa)=ATYPE

    DO Stage^sapi(.Attr,"sandbox")

    DO AssertTrue("C6: Multiple attributes staged",$GET(%TBR("count"))=2)

    QUIT


TestC7 ; Invalid attribute should not be staged
;;------------------------------------------------------------------
;; C7: Invalid attribute is not staged
;;
;; Purpose : Confirms Stage leaves %TBR untouched when a record fails validation.
;;
;; Expected final state :
;; %TBR is not populated.
;;------------------------------------------------------------------
    WRITE !,"C7: Invalid attribute is not staged"

    DO INIT^sapi
    KILL Attr

    SET Attr(1,cardin)=ONE
    SET Attr(1,range)=STRING

    DO Stage^sapi(.Attr,"sandbox")

    DO AssertTrue("C7: Invalid attribute rejected",$GET(%TBR("count"))=0)
    QUIT


TestC8 ; Existing attribute update stages one record
;;------------------------------------------------------------------
;; C8: Existing attribute update
;;
;; Purpose : Confirms Stage stages a single-field update against an existing attribute.
;;
;; Expected final state :
;; %TBR("count") equals 1.
;;------------------------------------------------------------------
    WRITE !,"C8: Existing attribute update"

    DO INIT^sapi
    KILL Attr

    SET Attr(1,key)="sandbox.movie.title"
    SET Attr(1,doc)="Updated movie title @en"

    DO Stage^sapi(.Attr,"sandbox")

    DO AssertTrue("C8: Existing attribute update staged",$GET(%TBR("count"))=1)
    QUIT

  
;==============================================================
; LAYER D — Full Schema Pipeline
;
; Tests the complete schema transaction pipeline:
; Verifies create, update, rollback, and atomic commits.
;
;     Stage()
;         ↓
;     StageRecord()
;         ↓
;     DatomAssert()
;         ↓
;     Transact()
;
; These tests verify committed state in:
;
;     ^TBEAVT
;     ^TBAVET
;     ^TBD
;     ^TBDR
;
;==============================================================
LayerD
    DO TestD1
    DO TestD2
    DO TestD3
    DO TestD4
    DO TestD5
    DO TestD6
    DO TestD7
    DO TestD8
    QUIT


TestD1 ; Create attribute
;;------------------------------------------------------------------
;; D1: Create attribute
;;
;; Purpose : Confirms a new attribute is committed and resolvable via GetEID after Transact.
;;
;; Expected final state :
;; eid is greater than 0.
;;------------------------------------------------------------------
    WRITE !,"D1: Create attribute"

    NEW Attr,eid

    DO INIT^sapi
    KILL Attr

    SET Attr(1,"sys.attr.key")="sandbox.test.d1"
    SET Attr(1,"sys.attr.range")="sys.val.string"
    SET Attr(1,"sys.attr.cardinality")="sys.enum.cardinality.one"
    SET Attr(1,"sys.attr.isa")="sys.type.attr"

    DO Stage^sapi(.Attr)
    DO Transact^sapi("Root")

    SET eid=$$GetEID^sapiGet("sandbox.test.d1")

    DO AssertTrue("D1: Create attribute committed",eid>0)

    QUIT



TestD2 ; Update attribute
;;------------------------------------------------------------------
;; D2: Update attribute
;;
;; Purpose : Confirms a metadata update against an existing attribute is committed to ^TBEAVT.
;;
;; Expected final state :
;; ^TBEAVT(eid,aid,vk) exists for the updated description value.
;;------------------------------------------------------------------
    WRITE !,"D2: Update attribute"

    NEW Attr,aid,vk,eid

    DO INIT^sapi
    KILL Attr

    SET Attr(1,"sys.attr.key")="sandbox.test.d1"
    SET Attr(1,"sys.attr.description")="Test attribute @en"

    DO Stage^sapi(.Attr)
    DO Transact^sapi("Root")

    SET eid=$$GetEID^sapiGet("sandbox.test.d1")
    SET aid=$$GetEID^sapiGet("sys.attr.description")
    SET vk=$GET(^TBDR(aid,"Test attribute @en"))

    DO AssertTrue("D2: Update attribute committed",$DATA(^TBEAVT(eid,aid,vk)))

    QUIT



TestD3 ; Create entity type with invalid isa value
;;------------------------------------------------------------------
;; D3: Create entity type with invalid isa value
;;
;; Purpose : Confirms Stage/Transact reject a record whose sys.attr.isa value does not
;;           resolve to any registered schema type, and that nothing is committed.
;;
;; Expected final state :
;; eid is less than 0 — entity was never created.
;;------------------------------------------------------------------
    WRITE !,"D3: Create entity type with invalid isa value"

    NEW Attr,eid

    DO INIT^sapi
    KILL Attr

    SET Attr(1,"sys.attr.key")="sandbox.person"
    SET Attr(1,"sys.attr.isa")="sys.type.foobar"

    DO Stage^sapi(.Attr)
    DO Transact^sapi("Root")

    SET eid=$$GetEID^sapiGet("sandbox.person")

    DO AssertTrue("D3: Invalid isa value rejected",eid<0)

    QUIT



TestD4 ; Create enum type
;;------------------------------------------------------------------
;; D4: Create enum type
;;
;; Purpose : Confirms a new sys.type.enum record is committed and resolvable via GetEID.
;;
;; Expected final state :
;; eid is greater than 0.
;;------------------------------------------------------------------
    WRITE !,"D4: Create enum"

    NEW Attr,eid

    DO INIT^sapi
    KILL Attr

    SET Attr(1,"sys.attr.key")="sandbox.enum.rating.pg13"
    SET Attr(1,"sys.attr.isa")="sys.type.enum"

    DO Stage^sapi(.Attr)
    DO Transact^sapi("Root")

    SET eid=$$GetEID^sapiGet("sandbox.enum.rating.pg13")

    DO AssertTrue("D4: Create enum committed",eid>0)

    QUIT



TestD5 ; Create attribute with alias
;;------------------------------------------------------------------
;; D5: Create attribute with alias
;;
;; Purpose : Confirms an attribute's alias is registered into ^TBKW after commit.
;;
;; Expected final state :
;; ^TBKW("sandbox.test.alias") exists.
;;------------------------------------------------------------------
    WRITE !,"D5: Create attribute with alias"

    NEW Attr

    DO INIT^sapi
    KILL Attr

    SET Attr(1,"sys.attr.key")="sandbox.test.alias"
    SET Attr(1,"sys.attr.range")="sys.val.string"
    SET Attr(1,"sys.attr.cardinality")="sys.enum.cardinality.one"
    SET Attr(1,"sys.attr.isa")="sys.type.attr"
    SET Attr(1,"sys.attr.alias")="alias"

    DO Stage^sapi(.Attr)
    DO Transact^sapi("Root")

    DO AssertTrue("D5: Attribute alias committed",$DATA(^TBKW("sandbox.test.alias")))

    QUIT



TestD6 ; Required metadata
;;------------------------------------------------------------------
;; D6: Required metadata
;;
;; Purpose : Confirms sys.attr.required is committed and correctly reported by IsRequired.
;;
;; Expected final state :
;; IsRequired^sapiVld(eid) returns true.
;;------------------------------------------------------------------
    WRITE !,"D6: Required metadata"

    NEW Attr,eid

    DO INIT^sapi
    KILL Attr

    SET Attr(1,"sys.attr.key")="sandbox.test.required"
    SET Attr(1,"sys.attr.range")="sys.val.string"
    SET Attr(1,"sys.attr.cardinality")="sys.enum.cardinality.one"
    SET Attr(1,"sys.attr.required")=1
    SET Attr(1,"sys.attr.isa")="sys.type.attr"

    DO Stage^sapi(.Attr)
    DO Transact^sapi("Root")

    SET eid=$$GetEID^sapiGet("sandbox.test.required")

    DO AssertTrue("D6: Required metadata committed",$$IsRequired^sapiVld(eid))

    QUIT



TestD7 ; Rollback on invalid metadata
;;------------------------------------------------------------------
;; D7: Rollback on invalid metadata
;;
;; Purpose : Confirms a batch containing an unrecognised metadata key is never committed.
;;
;; Expected final state :
;; eid is less than 0 — attribute was never created.
;;------------------------------------------------------------------
    WRITE !,"D7: Rollback on invalid metadata"

    NEW Attr,eid

    DO INIT^sapi
    KILL Attr

    SET Attr(1,"sys.attr.key")="sandbox.test.rollback"
    SET Attr(1,"sys.attr.range")="sys.val.string"
    SET Attr(1,"sys.attr.invalid")="foobar"
    SET Attr(1,"sys.attr.cardinality")="sys.enum.cardinality.one"
    SET Attr(1,"sys.attr.isa")="sys.type.attr"

    DO Stage^sapi(.Attr)
    DO Transact^sapi("Root")

    SET eid=$$GetEID^sapiGet("sandbox.test.rollback")

    DO AssertTrue("D7: Invalid metadata rolled back",eid<0)

    QUIT



TestD8 ; Multiple attributes committed atomically
;;------------------------------------------------------------------
;; D8: Atomic commit
;;
;; Purpose : Confirms every record in a valid multi-record batch is committed together.
;;
;; Expected final state :
;; Both e1 and e2 are greater than 0.
;;------------------------------------------------------------------
    WRITE !,"D8: Atomic commit"

    NEW Attr,e1,e2

    DO INIT^sapi
    KILL Attr

    SET Attr(1,"sys.attr.key")="sandbox.atomic.one"
    SET Attr(1,"sys.attr.range")=STRING
    SET Attr(1,"sys.attr.cardinality")=ONE
    SET Attr(1,"sys.attr.isa")=ATYPE

    SET Attr(2,"sys.attr.key")="sandbox.atomic.two"
    SET Attr(2,"sys.attr.range")=INT
    SET Attr(2,"sys.attr.cardinality")=ONE
    SET Attr(2,"sys.attr.isa")=ATYPE

    DO Stage^sapi(.Attr)
    DO Transact^sapi("Root")

    SET e1=$$GetEID^sapiGet("sandbox.atomic.one")
    SET e2=$$GetEID^sapiGet("sandbox.atomic.two")

    DO AssertTrue("D8: Multiple attributes atomic commit",(e1>0)&(e2>0))

    QUIT


;==============================================================
; LAYER X — Cross-cutting invariants
;
; Verifies behavioural guarantees across the schema pipeline.
;==============================================================
LayerX
    DO TestX1
    DO TestX2
    DO TestX3
    DO TestX4
    DO TestX5
    DO TestX6
    DO TestX7
    DO TestX8
    QUIT


TestX1 ; Repeated Stage does not duplicate datoms
;;------------------------------------------------------------------
;; X1: Repeated Stage does not duplicate datoms
;;
;; Purpose : Confirms a repeated Stage/Transact of an identical record is
;;           recognised as a no-op — the resulting tx is stamped with the
;;           ^TXE(tx,0) no-op marker rather than asserting any new datom.
;;
;; Expected final state :
;; ^TXE(tx,0) exists for the tx allocated by the second Transact, where tx
;; is the most recently allocated transaction id.
;;------------------------------------------------------------------
    WRITE !,"X1: Repeated Stage does not duplicate datoms"

    NEW Attr,tx

    SET Attr(1,"sys.attr.key")="sandbox.x1.attr"
    SET Attr(1,"sys.attr.range")="sys.val.string"
    SET Attr(1,"sys.attr.cardinality")="sys.enum.cardinality.one"
    SET Attr(1,"sys.attr.isa")="sys.type.attr"

    DO Stage^sapi(.Attr)
    DO Transact^sapi("Root")

    ; First commit is expected to assert real datoms — not itself under test here,
    ; only used to guarantee the record already exists before the repeat below.

    DO Stage^sapi(.Attr)
    DO Transact^sapi("Root")

    DO AssertTrue("X1: Repeated Stage does not duplicate datoms",$$IsNop^tx)
    QUIT


TestX2 ; Redundant metadata skipped
;;------------------------------------------------------------------
;; X2: Redundant metadata skipped
;;
;; Purpose : Follows TestX1. Tests two things against the sandbox.x1.attr
;;           entity established there:
;;             1. Adding a new attribute (sys.attr.description) to the
;;                existing sandbox.x1.attr entity for the first time —
;;                expected to commit as a real transaction.
;;             2. Re-adding that same attribute value a second time —
;;                expected to be recognised as a no-op.
;;
;; Expected final state :
;; The tx from the first Stage/Transact is NOT flagged no-op, AND the tx
;; from the second Stage/Transact IS flagged no-op.
;;------------------------------------------------------------------
    WRITE !,"X2: Redundant metadata skipped"

    NEW Attr,tx1,tx2

    SET Attr(1,"sys.attr.key")="sandbox.x1.attr"
    SET Attr(1,"sys.attr.description")="Repeated metadata @en"

    DO Stage^sapi(.Attr)
    DO Transact^sapi("Root")

    ; First assertion of this description is expected to be a real write
    SET tx1=$$GetLast^tx

    DO Stage^sapi(.Attr)
    DO Transact^sapi("Root")

    ; Repeating the identical metadata is expected to be a no-op
    SET tx2=$$GetLast^tx

    DO AssertTrue("X2: Redundant metadata skipped",('$$IsNop^tx(tx1))&($$IsNop^tx(tx2)))
    QUIT


TestX3 ; Value keys are stable
;;------------------------------------------------------------------
;; X3: Value keys are stable
;;
;; Purpose : Confirms RegisterAttrVal returns the same value key on repeated calls
;;           for an identical literal value.
;;
;; Expected final state :
;; vk1 equals vk2.
;;------------------------------------------------------------------
    WRITE !,"X3: Value keys are stable"

    NEW aid,vk1,vk2,dummy

    SET aid=$$GetEID^sapiGet("sys.attr.description")

    SET dummy=$$RegisterAttrVal^sapiRslv(aid,"Stable key @en",.vk1)
    SET dummy=$$RegisterAttrVal^sapiRslv(aid,"Stable key @en",.vk2)

    DO AssertTrue("X3: Value keys are stable",vk1=vk2)
    QUIT


TestX4 ; Reference values resolve to same key
;;------------------------------------------------------------------
;; X4: Reference values resolve to same key
;;
;; Purpose : Confirms repeated resolution of the same reference-typed attribute value
;;           returns the same value key.
;;
;; Expected final state :
;; vk1 equals vk2.
;;------------------------------------------------------------------
    WRITE !,"X4: Reference values resolve to same key"

    NEW aid,vk1,vk2,dummy

    SET aid=$$GetEID^sapiGet("sys.attr.cardinality")

    SET dummy=$$ResolveAttrRef^sapiRslv(aid,"sys.enum.cardinality.one",.vk1,"TBox")
    SET dummy=$$ResolveAttrRef^sapiRslv(aid,"sys.enum.cardinality.one",.vk2,"TBox")

    DO AssertTrue("X4: Reference values resolve to same key",vk1=vk2)
    QUIT


TestX5 ; Failed transaction leaves globals unchanged
;;------------------------------------------------------------------
;; X5: Failed transaction leaves globals unchanged
;;
;; Purpose : Confirms a record that fails validation (missing sys.attr.key) never
;;           reaches StageRecord and never modifies the underlying globals.
;;
;; Expected final state :
;; ^TBEAVT, ^TBAVET, and ^TBD root values are unchanged before and after Stage.
;;------------------------------------------------------------------
    WRITE !,"X5: Failed transaction leaves globals unchanged"

    NEW before1,before2,before3
    NEW after1,after2,after3
    NEW Attr

    SET before1=$GET(^TBEAVT)
    SET before2=$GET(^TBAVET)
    SET before3=$GET(^TBD)

    SET Attr(1,"sys.attr.range")="sys.val.string"
    SET Attr(1,"sys.attr.cardinality")="sys.enum.cardinality.one"
    SET Attr(1,"sys.attr.isa")="sys.type.attr"

    DO Stage^sapi(.Attr)

    SET after1=$GET(^TBEAVT)
    SET after2=$GET(^TBAVET)
    SET after3=$GET(^TBD)

    DO AssertTrue("X5: Failed transaction leaves globals unchanged",((before1=after1)&(before2=after2)&(before3=after3)))
    QUIT


TestX6 ; Atomic commit across multiple schema records
;;------------------------------------------------------------------
;; X6: Atomic commit across multiple schema records
;;
;; Purpose : Confirms every record in a valid multi-record batch is committed together.
;;
;; Expected final state :
;; Both e1 and e2 are greater than 0.
;;------------------------------------------------------------------
    WRITE !,"X6: Atomic commit across multiple schema records"

    NEW Attr,e1,e2

    SET Attr(1,"sys.attr.key")="sandbox.x6.one"
    SET Attr(1,"sys.attr.range")=STRING
    SET Attr(1,"sys.attr.cardinality")=ONE
    SET Attr(1,"sys.attr.isa")=ATYPE

    SET Attr(2,"sys.attr.key")="sandbox.x6.two"
    SET Attr(2,"sys.attr.range")=INT
    SET Attr(2,"sys.attr.cardinality")=ONE
    SET Attr(2,"sys.attr.isa")=ATYPE

    DO Stage^sapi(.Attr)
    DO Transact^sapi("Root")

    SET e1=$$GetEID^sapiGet("sandbox.x6.one")
    SET e2=$$GetEID^sapiGet("sandbox.x6.two")

    DO AssertTrue("X6: Atomic commit across multiple schema records",(e1>0)&(e2>0))
    QUIT


TestX7 ; Rollback removes staged records
;;------------------------------------------------------------------
;; X7: Rollback removes staged records
;;
;; Purpose : Confirms a batch containing an unrecognised metadata key is discarded
;;           from %TBR entirely, leaving the count at 0.
;;
;; Expected final state :
;; %TBR("count") equals 0.
;;------------------------------------------------------------------
    WRITE !,"X7: Rollback removes staged records"

    NEW Attr

    KILL %TBR
    SET %TBR("count")=0

    SET Attr(1,"sys.attr.key")="sandbox.rollback.test"
    SET Attr(1,"sys.attr.range")="sys.val.string"
    SET Attr(1,"sys.attr.foobar")="invalid"
    SET Attr(1,"sys.attr.cardinality")="sys.enum.cardinality.one"
    SET Attr(1,"sys.attr.isa")="sys.type.attr"

    DO Stage^sapi(.Attr)

    DO AssertTrue("X7: Rollback removes staged records",$GET(%TBR("count"),0)=0)
    QUIT


TestX8 ; Repeated schema update only adds new metadata
;;------------------------------------------------------------------
;; X8: Repeated schema update only adds new metadata
;;
;; Purpose : Confirms new description and alias metadata added to an existing
;;           attribute are both committed.
;;
;; Expected final state :
;; ^TBEAVT(eid,aid1,vk1) and ^TBEAVT(eid,aid2,vk2) both exist.
;;------------------------------------------------------------------
    WRITE !,"X8: Repeated schema update only adds new metadata"

    NEW Attr,eid,aid1,aid2,vk1,vk2

    SET Attr(1,"sys.attr.key")="sandbox.x1.attr"
    SET Attr(1,"sys.attr.description")="Updated description @en"
    SET Attr(1,"sys.attr.alias")="xattr"

    DO Stage^sapi(.Attr)
    DO Transact^sapi("Root")

    SET eid=$$GetEID^sapiGet("sandbox.x1.attr")

    SET aid1=$$GetEID^sapiGet("sys.attr.description")
    SET vk1=^TBDR(aid1,"Updated description @en")

    SET aid2=$$GetEID^sapiGet("sys.attr.alias")
    SET vk2=^TBDR(aid2,"xattr")
	
	D PE^sapi("sandbox.x1.attr")
    DO AssertTrue("X8: Repeated schema update adds new metadata",($DATA(^TBEAVT(eid,aid1,vk1))&$DATA(^TBEAVT(eid,aid2,vk2))))
    QUIT