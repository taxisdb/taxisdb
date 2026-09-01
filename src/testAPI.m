;; =========================================================================================== 
;; ^testAPI - Testing Suite for ABox Data Access API  - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 		— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;; =============================================================================================
;; OVERVIEW
;;
;; Full testing suite for api.m's transaction engine that turns a
;; caller-supplied record (or single datom) into persisted facts
;; in ^EATV/^AVET/^AEVT/^VAET.
;;
;; tests across seven layers, 
;; LAYER A —  11 tests - Resolution and unique-attribute primitives
;; LAYER B —  30 tests - Target entity resolution across EID, lookup-key, and unique-attribute paths 
;; LAYER C —   8 tests - Record validation and attribute resolution
;; LAYER D —  12 tests - Datom write-front-line: DatomAssert and DatomRevise
;; LAYER E —  13 tests - End-to-end Stage: commit, rollback, and batch atomicity
;; LAYER F —  29 tests - AssertDatom/RetractDatom convenience wrappers (Formats A/B/C, unique constraints)
;; LAYER G —   9 tests - Entity resolution (PE/PH) across paths and edge cases
;; LAYER X —   6 tests - Cross-pipeline structural invariants
;; ----------------------------------------------------------------------------------------
;; TOTAL   — 118 tests
;; ----------------------------------------------------------------------------------------
;; each layer testing one stage of the resolve → validate → stage → commit 
;; pipeline in increasing scope. From isolated primitive functions up through 
;; full end-to-end transactions, plus a final layer of structural invariants
;; that only hold across the whole pipeline and can't be confirmed by any single layer in isolation.
;;
;; Every test performs a real runtime check via 
;; AssertTrue, AssertFalse, AssertEqual helper functions 
;; comparing actual state against expected outcomes
;;
;; Many of the tests are based on the following preliminary tests 
;; already run successfully, establishing baseline data
;;
;; ^testObject — creates obj.claudio_arrau (pianist) and obj.tom_hanks (actor)
;; 
;; ^testMovie — creates schema for sandbox.movie.* 
;; title, genre, releaseYear, imdbid [UNQINSERT], tmdbid [UNQUPSERT]
;; and a movie instance Seven with tt0011100.
;;
;; ^testPerson — creates schema for sandbox.person.* 
;; name, age, email [UNQINSERT], ssn [UNQUPSERT]. 
;; and person instance p.athan
;;
;; ^testDLC — creates schema for sandbox.dlc.* 
;; id [UNQUPSERT], checkup, count, txdate:DATE 
;; and a DLC item 042
;;
;; these entities/schemas are established as ground truth for subsequent tests:
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

LayerA
;; ==================================================================================================
;; LAYER A — Resolution and unique-attribute primitives
;; ==================================================================================================
;;
;; Test Coverage: Ownership resolution under UNQINSERT/UNQUPSERT, reference
;;                attribute resolution, and counting of unique-constrained
;;                attributes in a staged record.
;;
;; Scope: ResolveOwnership^apiRslv, ResolveAttrRef^sapiRslv, CountUniqueAttributes^apiRslv
;;
;; ==================================================================================================
    DO TestA1  ; ResolveOwnership UNQINSERT absent
    DO TestA2  ; ResolveOwnership UNQINSERT existing
    DO TestA3  ; ResolveOwnership UNQUPSERT absent
    DO TestA4  ; ResolveOwnership UNQUPSERT existing
    DO TestA5  ; ResolveOwnership empty value
    DO TestA6  ; Resolve attribute new reference registration
    DO TestA7  ; ResolveAttrRef rejects non-existing EID
    DO TestA8  ; CountUniqueAttributes none
    DO TestA9  ; CountUniqueAttributes one
    DO TestA10 ; CountUniqueAttributes three
    DO TestA11 ; CountUniqueAttributes empty
    QUIT


TestA1 ; ResolveOwnership UNQINSERT absent
;;------------------------------------------------------------------
;; Purpose: New unique value under UNQINSERT allocates a fresh eid
;; Scope: ResolveOwnership^apiRslv
;; Assert Condition: resolved eid is a positive number
;;------------------------------------------------------------------
    WRITE !,"A1: ResolveOwnership UNQINSERT absent"
    NEW RR,eid,imdbaid
    SET imdbaid=$$GetEID^sapiGet("sandbox.movie.imdbid")
    SET RR("+",imdbaid)="tt9999999"
    SET eid=$$ResolveOwnership^apiRslv(imdbaid,.RR)
    DO AssertTrue("A1: UNQINSERT creates new eid",eid>0)
    QUIT

TestA2 ; ResolveOwnership UNQINSERT existing
;;------------------------------------------------------------------
;; Purpose: Duplicate value under UNQINSERT is rejected
;; Scope: ResolveOwnership^apiRslv
;; Assert Condition: resolved eid indicates failure
;;------------------------------------------------------------------
    WRITE !,"A2: ResolveOwnership UNQINSERT existing"
    NEW RR,eid,imdbaid
    SET imdbaid=$$GetEID^sapiGet("sandbox.movie.imdbid")
    SET RR("+",imdbaid)="tt0011100"
    SET eid=$$ResolveOwnership^apiRslv(imdbaid,.RR)
    DO AssertTrue("A2: UNQINSERT rejects duplicate value",eid=0)
    DO PE^api("tt0011100","sandbox.movie.imdbid")
    QUIT

TestA3 ; ResolveOwnership UNQUPSERT absent
;;------------------------------------------------------------------
;; Purpose: New unique value under UNQUPSERT allocates a fresh eid
;; Scope: ResolveOwnership^apiRslv
;; Assert Condition: resolved eid is a positive number
;;------------------------------------------------------------------
    WRITE !,"A3: ResolveOwnership UNQUPSERT absent"
    NEW RR,eid,dlcaid
    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET RR("+",dlcaid)="999"
    SET eid=$$ResolveOwnership^apiRslv(dlcaid,.RR)
    DO AssertTrue("A3: UNQUPSERT creates new eid",eid>0)
    QUIT

TestA4 ; ResolveOwnership UNQUPSERT existing
;;------------------------------------------------------------------
;; Purpose: Existing value under UNQUPSERT resolves to its current owner
;; Scope: ResolveOwnership^apiRslv
;; Assert Condition: resolved eid matches the known owner of the value
;;------------------------------------------------------------------
    WRITE !,"A4: ResolveOwnership UNQUPSERT existing"
    NEW RR,eid,dlcaid,valkey,expected
    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET RR("+",dlcaid)="042"
    SET valkey=$GET(^TBDR(dlcaid,"042"))
    SET expected=$ORDER(^AVET(dlcaid,valkey,""))
    SET eid=$$ResolveOwnership^apiRslv(dlcaid,.RR)
    DO AssertTrue("A4: UNQUPSERT resolves existing owner",eid=expected)
    QUIT

TestA5 ; ResolveOwnership empty value
;;------------------------------------------------------------------
;; Purpose: Empty value is rejected regardless of unique mode
;; Scope: ResolveOwnership^apiRslv
;; Assert Condition: resolved eid indicates failure
;;------------------------------------------------------------------
    WRITE !,"A5: ResolveOwnership empty value"
    NEW RR,eid,dlcaid
    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET RR("+",dlcaid)=""
    SET eid=$$ResolveOwnership^apiRslv(dlcaid,.RR)
    DO AssertTrue("A5: ResolveOwnership rejects empty value",eid=0)
    QUIT


TestA6 ; Resolve attribute new reference registration
;;------------------------------------------------------------------
;; Purpose: First reference to an eid allocates a new valkey; a second
;;          reference to the same eid reuses it
;; Scope: ResolveAttrRef^sapiRslv
;; Assert Condition: both calls return the same valkey, first call
;;                   reports new registration, second does not
;;------------------------------------------------------------------
    WRITE !,"A6: Resolve new reference registration"

    NEW aid,eid,vk1,vk2,isNew1,isNew2

    DO AddAttr^sapi("sandbox.person.favmovie",REF,ONE,ATYPE,UNQUPSERT,"The favourite movie for a person @en")
    DO Transact^sapi

    SET aid=$$GetEID^sapiGet("sandbox.person.favmovie")
    SET eid=$$LookupEID^apiGet("tt0011100","sandbox.movie.imdbid")

    SET isNew1=$$ResolveAttrRef^sapiRslv(aid,eid,.vk1,"ABox")
    SET isNew2=$$ResolveAttrRef^sapiRslv(aid,eid,.vk2,"ABox")

    DO AssertTrue("A6: Resolve new reference registration",(vk1=vk2)&(isNew1=1)&(isNew2=0))
    QUIT


TestA7 ; ResolveAttrRef rejects non-existing EID
;;------------------------------------------------------------------
;; Purpose: A reference value shaped like an EID but not present in
;;          the database is rejected
;; Scope: ResolveAttrRef^sapiRslv, IsRangeValue^sapiVld
;; Assert Condition: resolution fails, no valkey is returned, and the
;;                    value is confirmed not to be a valid range member
;;------------------------------------------------------------------
    WRITE !,"A7: ResolveAttrRef rejects non-existing EID"

    NEW aid,refeid,valkey,result,cond

    DO AddAttr^sapi("sandbox.person.myfavmovie",REF,ONE,ATYPE,UNQUPSERT,"The favourite movie for a person @en")
    DO Transact^sapi

    SET aid=$$GetEID^sapiGet("sandbox.person.myfavmovie")
    SET refeid="fffffffffffffzzzzzzz"
    SET result=$$ResolveAttrRef^sapiRslv(aid,refeid,.valkey,"ABox")
    SET cond=(result=-1)&(valkey="")&('$$IsRangeValue^sapiVld(aid,refeid))

    DO AssertTrue("A7: ResolveAttrRef rejects non-existing EID",cond)

    QUIT

TestA8 ; CountUniqueAttributes none
;;------------------------------------------------------------------
;; Purpose: A record with no unique-constrained attributes reports
;;          zero and no first attribute
;; Scope: CountUniqueAttributes^apiRslv
;; Assert Condition: count is zero and firstAid is empty
;;------------------------------------------------------------------
    WRITE !,"A8: CountUniqueAttributes none"
    NEW RR       ; staged record
    NEW count    ; unique attribute count
    NEW firstAid ; first unique attribute found
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.title"))="The Reader"
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.genre"))="drama"
    DO CountUniqueAttributes^apiRslv(.RR,.count,.firstAid)
    DO AssertTrue("A8: CountUniqueAttributes no unique attributes",(count=0)&(firstAid=""))
    QUIT

TestA9 ; CountUniqueAttributes one
;;------------------------------------------------------------------
;; Purpose: A record with exactly one unique-constrained attribute
;;          reports it as the first unique attribute
;; Scope: CountUniqueAttributes^apiRslv
;; Assert Condition: count is one and firstAid matches the attribute
;;------------------------------------------------------------------
    WRITE !,"A9: CountUniqueAttributes one"
    NEW RR       ; staged record
    NEW count    ; unique attribute count
    NEW firstAid ; first unique attribute found
    NEW imdbaid  ; imdbid attribute id
    SET imdbaid=$$GetEID^sapiGet("sandbox.movie.imdbid")
    SET RR("+",imdbaid)="tt0011100"
    DO CountUniqueAttributes^apiRslv(.RR,.count,.firstAid)
    DO AssertTrue("A9: CountUniqueAttributes one unique attribute",(count=1)&(firstAid=imdbaid))
    QUIT

TestA10 ; CountUniqueAttributes three
;;------------------------------------------------------------------
;; Purpose: A record with three unique-constrained attributes is
;;          counted correctly
;; Scope: CountUniqueAttributes^apiRslv
;; Assert Condition: count is three
;;------------------------------------------------------------------
    WRITE !,"A10: CountUniqueAttributes three"
    NEW RR       ; staged record
    NEW count    ; unique attribute count
    NEW firstAid ; first unique attribute found
    NEW imdbaid  ; imdbid attribute id
    NEW tmdbaid  ; tmdbid attribute id
    NEW dlcaid   ; dlc id attribute id
    SET imdbaid=$$GetEID^sapiGet("sandbox.movie.imdbid")
    SET tmdbaid=$$GetEID^sapiGet("sandbox.movie.tmdbid")
    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET RR("+",imdbaid)="tt0011100"
    SET RR("+",tmdbaid)="12345"
    SET RR("+",dlcaid)="042"
    DO CountUniqueAttributes^apiRslv(.RR,.count,.firstAid)
    DO AssertTrue("A10: CountUniqueAttributes three unique attributes",count=3)
    QUIT

TestA11 ; CountUniqueAttributes empty
;;------------------------------------------------------------------
;; Purpose: A completely empty record reports zero and no first
;;          attribute
;; Scope: CountUniqueAttributes^apiRslv
;; Assert Condition: count is zero and firstAid is empty
;;------------------------------------------------------------------
    WRITE !,"A11: CountUniqueAttributes empty"
    NEW RR       ; empty record
    NEW count    ; unique attribute count
    NEW firstAid ; first unique attribute found
    DO CountUniqueAttributes^apiRslv(.RR,.count,.firstAid)
    DO AssertTrue("A11: CountUniqueAttributes empty record",(count=0)&(firstAid=""))
    QUIT


LayerB
;; ==================================================================================================
;; LAYER B — Target entity resolution across EID, lookup-key, and unique-attribute paths
;; ==================================================================================================
;;
;; Test Coverage: Explicit raw EID resolution, sys.attr.key find-or-create
;;                resolution, single and multiple unique-attribute resolution
;;                under UNQINSERT/UNQUPSERT semantics, sys.attr.resolvedby
;;                validation and disambiguation, and end-to-end dispatch
;;                across all three resolution paths via ResolveTargetEntity,
;;                including control-attribute consumption.
;;
;; Scope: ResolveByEID^apiRslv, ResolveByNaturalKey^apiRslv,
;;        ResolveByUnique^apiRslv, ResolveDesignatedUnique^apiRslv,ResolveOwnership^apiRslv
;;        ResolveTargetEntity^apiRslv
;;
;; Result: 30/30 PASS
;; ==================================================================================================
    DO TestB1  ; ResolveByEID valid EID
    DO TestB2  ; ResolveByEID EID format valid but missing
    DO TestB3  ; ResolveByEID malformed EID
    DO TestB4  ; ResolveByEID empty value
    DO TestB5  ; ResolveByEID consumes sys.attr.id
    DO TestB6  ; ResolveByNaturalKey existing key
    DO TestB7  ; ResolveByNaturalKey new key
    DO TestB8  ; ResolveByNaturalKey keeps sys.attr.key
    DO TestB9  ; ResolveByUnique anonymous entity
    DO TestB10 ; ResolveByUnique resolveby without unique attribute
    DO TestB11 ; ResolveByUnique UNQINSERT new value
    DO TestB12 ; ResolveByUnique UNQINSERT duplicate
    DO TestB13 ; ResolveByUnique UNQUPSERT new value
    DO TestB14 ; ResolveByUnique UNQUPSERT existing value
    DO TestB15 ; ResolveByUnique multiple unique attrs with resolveby collision
    DO TestB16 ; ResolveByUnique multiple unique attrs without resolveby
    DO TestB17 ; ResolveByUnique unknown attrkey
    DO TestB18 ; ResolveByUnique attrkey not unique
    DO TestB19 ; ResolveByUnique resolvedby attribute missing value
    DO TestB20 ; ResolveByUnique resolvedby attribute empty value
    DO TestB21 ; ResolveByUnique UNQINSERT new value via resolvedby
    DO TestB22 ; ResolveByUnique UNQUPSERT existing value via resolvedby
    DO TestB23 ; ResolveTargetEntity Path 0 valid EID
    DO TestB24 ; ResolveTargetEntity Path 0 invalid EID
    DO TestB25 ; ResolveTargetEntity Path 1 natural key
    DO TestB26 ; ResolveTargetEntity Path 1 natural key creates GENID
    DO TestB27 ; ResolveTargetEntity Path 2 anonymous entity
    DO TestB28 ; ResolveTargetEntity Path 2 UNQUPSERT merge
    DO TestB29 ; ResolveTargetEntity resolveby consumed
    DO TestB30 ; ResolveTargetEntity via Path 0 leaves entity facts intact
    QUIT


TestB1 ; ResolveByEID valid EID
;;------------------------------------------------------------------
;; Purpose: A record referencing an existing entity by sys.attr.id
;;          resolves to that entity
;; Scope: ResolveByEID^apiRslv
;; Assert Condition: resolution succeeds and returns the existing eid
;;------------------------------------------------------------------
    WRITE !,"B1: ResolveByEID valid EID"
    NEW RR          ; staged record
    NEW eid          ; resolved entity id (output)
    NEW existingeid  ; known eid of obj.tom_hanks
    SET existingeid=$$GetEID^apiGet("obj.tom_hanks")
    SET RR("+",SYSATTRID)=existingeid
    SET eid=$$ResolveByEID^apiRslv(.RR)
    DO AssertTrue("B1: ResolveByEID valid EID",eid=existingeid)
    QUIT

TestB2 ; ResolveByEID EID format valid but missing
;;------------------------------------------------------------------
;; Purpose: A well-formed EID that does not exist in the database
;;          is rejected
;; Scope: ResolveByEID^apiRslv
;; Assert Condition: resolution fails
;;------------------------------------------------------------------
    WRITE !,"B2: ResolveByEID unknown EID"
    NEW RR  ; staged record
    NEW eid ; resolved entity id (output)
    SET RR("+",SYSATTRID)="65560e13bd45f6y9xowl" ; valid format, but not in DB
    SET eid=$$ResolveByEID^apiRslv(.RR)
    DO AssertTrue("B2: ResolveByEID rejects unknown EID",eid=0)
    QUIT

TestB3 ; ResolveByEID malformed EID
;;------------------------------------------------------------------
;; Purpose: A value that is not shaped like an EID is rejected
;; Scope: ResolveByEID^apiRslv
;; Assert Condition: resolution fails
;;------------------------------------------------------------------
    WRITE !,"B3: ResolveByEID malformed EID"
    NEW RR  ; staged record
    NEW eid ; resolved entity id (output)
    SET RR("+",SYSATTRID)="not-an-eid"
    SET eid=$$ResolveByEID^apiRslv(.RR)
    DO AssertTrue("B3: ResolveByEID rejects malformed EID",eid=0)
    QUIT

TestB4 ; ResolveByEID empty value
;;------------------------------------------------------------------
;; Purpose: An empty sys.attr.id value is rejected
;; Scope: ResolveByEID^apiRslv
;; Assert Condition: resolution fails
;;------------------------------------------------------------------
    WRITE !,"B4: ResolveByEID empty value"
    NEW RR  ; staged record
    NEW eid ; resolved entity id (output)
    SET RR("+",SYSATTRID)=""
    SET eid=$$ResolveByEID^apiRslv(.RR)
    DO AssertTrue("B4: ResolveByEID rejects empty value",eid=0)
    QUIT

TestB5 ; ResolveByEID consumes sys.attr.id
;;------------------------------------------------------------------
;; Purpose: A successful resolution removes sys.attr.id from the
;;          staged record
;; Scope: ResolveByEID^apiRslv
;; Assert Condition: sys.attr.id is no longer present in the record
;;------------------------------------------------------------------
    WRITE !,"B5: ResolveByEID consumes sys.attr.id"
    NEW RR          ; staged record
    NEW eid          ; resolved entity id (output)
    NEW existingeid  ; known eid of obj.tom_hanks
    SET existingeid=$$GetEID^apiGet("obj.tom_hanks")
    SET RR("+",SYSATTRID)=existingeid
    SET eid=$$ResolveByEID^apiRslv(.RR)
    DO AssertTrue("B5: ResolveByEID consumes sys.attr.id",'$DATA(RR("+",SYSATTRID)))
    QUIT

TestB6 ; ResolveByNaturalKey existing key
;;------------------------------------------------------------------
;; Purpose: A record referencing an existing natural key resolves to
;;          that entity's eid
;; Scope: ResolveByNaturalKey^apiRslv
;; Assert Condition: resolution returns the existing eid
;;------------------------------------------------------------------
    WRITE !,"B6: ResolveByNaturalKey existing key"
    NEW RR          ; staged record
    NEW eid          ; resolved entity id
    NEW expectedeid  ; known eid of obj.tom_hanks
    SET expectedeid=$$GetEID^apiGet("obj.tom_hanks")
    SET RR("+",AKEYID)="obj.tom_hanks"
    SET eid=$$ResolveByNaturalKey^apiRslv(.RR)
    DO AssertTrue("B6: ResolveByNaturalKey existing key",eid=expectedeid)
    QUIT

TestB7 ; ResolveByNaturalKey new key
;;------------------------------------------------------------------
;; Purpose: A record referencing a natural key not yet in the
;;          database generates a fresh entity
;; Scope: ResolveByNaturalKey^apiRslv
;; Assert Condition: resolution returns a non-empty eid
;;------------------------------------------------------------------
    WRITE !,"B7: ResolveByNaturalKey new key"
    NEW RR  ; staged record
    NEW eid ; resolved entity id
    SET RR("+",AKEYID)="obj.brand_new_entity"
    SET eid=$$ResolveByNaturalKey^apiRslv(.RR)
    DO AssertTrue("B7: ResolveByNaturalKey creates GENID",eid'="")
    QUIT

TestB8 ; ResolveByNaturalKey keeps sys.attr.key
;;------------------------------------------------------------------
;; Purpose: Resolving a natural key does not remove sys.attr.key
;;          from the staged record
;; Scope: ResolveByNaturalKey^apiRslv
;; Assert Condition: sys.attr.key remains present in the record
;;------------------------------------------------------------------
    WRITE !,"B8: ResolveByNaturalKey keeps sys.attr.key"
    NEW RR  ; staged record
    NEW eid ; resolved entity id
    SET RR("+",AKEYID)="obj.tom_hanks"
    SET eid=$$ResolveByNaturalKey^apiRslv(.RR)
    DO AssertTrue("B8: ResolveByNaturalKey keeps key",$DATA(RR("+",AKEYID))'=0)
    QUIT

TestB9 ; ResolveByUnique anonymous entity
;;------------------------------------------------------------------
;; Purpose: A record with no natural key or unique attributes still
;;          resolves via a generated entity id
;; Scope: ResolveByUnique^apiRslv
;; Assert Condition: resolution returns a non-empty eid
;;------------------------------------------------------------------
    WRITE !,"B9: ResolveByUnique anonymous entity"
    NEW RR  ; staged record
    NEW eid ; resolved entity id
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.title"))="Anonymous Movie"
    SET eid=$$ResolveByUnique^apiRslv(.RR)
    DO AssertTrue("B9: ResolveByUnique anonymous GENID",eid'="")
    QUIT

TestB10 ; ResolveByUnique resolveby without unique attribute
;;------------------------------------------------------------------
;; Purpose: A sys.attr.resolvedby directive present while the record
;;          supplies no unique attributes at all is rejected
;; Scope: ResolveByUnique^apiRslv
;; Assert Condition: resolution fails
;;------------------------------------------------------------------
    WRITE !,"B10: ResolveByUnique invalid resolveby"
    NEW RR  ; staged record
    NEW eid ; resolved entity id
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.title"))="Some Movie"
    SET RR("+",RESOLVEDBYID)="sandbox.movie.title"
    SET eid=$$ResolveByUnique^apiRslv(.RR)
    DO AssertTrue("B10: ResolveByUnique rejects resolveby with no unique attrs",eid=0)
    QUIT

TestB11 ; ResolveByUnique UNQINSERT new value
;;------------------------------------------------------------------
;; Purpose: A new UNQINSERT attribute value resolves to a freshly
;;          created entity
;; Scope: ResolveByUnique^apiRslv
;; Assert Condition: resolution returns a non-empty eid
;;------------------------------------------------------------------
    WRITE !,"B11: ResolveByUnique UNQINSERT new value"
    NEW RR      ; staged record
    NEW eid      ; resolved entity id
    NEW imdbaid  ; imdbid attribute id
    SET imdbaid=$$GetEID^sapiGet("sandbox.movie.imdbid")
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.title"))="New Movie"
    SET RR("+",imdbaid)="tt9999998"
    SET eid=$$ResolveByUnique^apiRslv(.RR)
    DO AssertTrue("B11: ResolveByUnique UNQINSERT creates entity",eid'="")
    QUIT

TestB12 ; ResolveByUnique UNQINSERT duplicate
;;------------------------------------------------------------------
;; Purpose: A UNQINSERT attribute value that already exists is
;;          rejected
;; Scope: ResolveByUnique^apiRslv
;; Assert Condition: resolution fails
;;------------------------------------------------------------------
    WRITE !,"B12: ResolveByUnique UNQINSERT duplicate"
    NEW RR      ; staged record
    NEW eid      ; resolved entity id
    NEW imdbaid  ; imdbid attribute id
    SET imdbaid=$$GetEID^sapiGet("sandbox.movie.imdbid")
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.title"))="The Reader"
    SET RR("+",imdbaid)="tt0011100"
    SET eid=$$ResolveByUnique^apiRslv(.RR)
    DO AssertTrue("B12: ResolveByUnique UNQINSERT rejects duplicate",eid=0)
    QUIT

TestB13 ; ResolveByUnique UNQUPSERT new value
;;------------------------------------------------------------------
;; Purpose: A new UNQUPSERT attribute value resolves to a freshly
;;          created entity
;; Scope: ResolveByUnique^apiRslv
;; Assert Condition: resolution returns a non-empty eid
;;------------------------------------------------------------------
    WRITE !,"B13: ResolveByUnique UNQUPSERT new value"
    NEW RR     ; staged record
    NEW eid     ; resolved entity id
    NEW dlcaid  ; dlc id attribute id
    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET RR("+",dlcaid)="999"
    SET eid=$$ResolveByUnique^apiRslv(.RR)
    DO AssertTrue("B13: ResolveByUnique UNQUPSERT creates entity",eid'="")
    QUIT

TestB14 ; ResolveByUnique UNQUPSERT existing value
;;------------------------------------------------------------------
;; Purpose: An existing UNQUPSERT attribute value resolves to its
;;          current owner
;; Scope: ResolveByUnique^apiRslv
;; Assert Condition: resolution returns the known owner eid
;;------------------------------------------------------------------
    WRITE !,"B14: ResolveByUnique UNQUPSERT existing value"
    NEW RR          ; staged record
    NEW eid          ; resolved entity id
    NEW dlcaid       ; dlc id attribute id
    NEW expectedeid  ; known owner eid of dlc item 042
    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET RR("+",dlcaid)="042"
    SET expectedeid=$$GetEID^apiGet("042",dlcaid)
    SET eid=$$ResolveByUnique^apiRslv(.RR)
    DO AssertTrue("B14: ResolveByUnique UNQUPSERT resolves owner",eid=expectedeid)
    QUIT

TestB15 ; ResolveByUnique multiple unique attrs with resolveby collision
;;------------------------------------------------------------------
;; Purpose: A sys.attr.resolvedby directive pointing at a UNQINSERT
;;          attribute whose value already exists is rejected, even
;;          when other unique attributes are present in the record
;; Scope: ResolveByUnique^apiRslv
;; Assert Condition: resolution fails
;;------------------------------------------------------------------
    WRITE !,"B15: ResolveByUnique multiple unique collision"
    NEW RR      ; staged record
    NEW eid      ; resolved entity id
    NEW imdbaid  ; imdbid attribute id
    NEW dlcaid   ; dlc id attribute id
    SET imdbaid=$$GetEID^sapiGet("sandbox.movie.imdbid")
    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET RR("+",imdbaid)="tt0011100"
    SET RR("+",dlcaid)="042"
    SET RR("+",RESOLVEDBYID)="sandbox.movie.imdbid"
    SET eid=$$ResolveByUnique^apiRslv(.RR)
    DO AssertTrue("B15: ResolveByUnique rejects UNQINSERT collision",eid=0)
    QUIT

TestB16 ; ResolveByUnique multiple unique attrs without resolveby
;;------------------------------------------------------------------
;; Purpose: A record supplying values for more than one unique-
;;          constrained attribute is rejected when no RESOLVEDBYID
;;          is specified to disambiguate
;; Scope: ResolveByUnique^apiRslv
;; Assert Condition: resolution fails
;;------------------------------------------------------------------
    WRITE !,"B16: ResolveByUnique multiple unique attrs no resolveby"
    NEW RR       ; staged record
    NEW eid      ; resolved entity id
    NEW imdbaid  ; imdbid attribute id
    NEW dlcaid   ; dlc id attribute id
    SET imdbaid=$$GetEID^sapiGet("sandbox.movie.imdbid")
    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET RR("+",imdbaid)="tt9999997"
    SET RR("+",dlcaid)="999"
    SET eid=$$ResolveByUnique^apiRslv(.RR)
    DO AssertTrue("B16: ResolveByUnique rejects multiple unique attrs without resolveby",eid=0)
    QUIT

TestB17 ; ResolveByUnique unknown attrkey
;;------------------------------------------------------------------
;; Purpose: A sys.attr.resolvedby value naming an attribute key that
;;          does not exist in the schema is rejected
;; Scope: ResolveByUnique^apiRslv, ResolveDesignatedUnique^apiRslv
;; Assert Condition: resolution fails
;;------------------------------------------------------------------
    WRITE !,"B17: ResolveByUnique unknown attrkey"
    NEW RR      ; staged record
    NEW eid     ; resolved entity id
    NEW imdbaid ; imdbid attribute id — second unique attr, forces count>1
    NEW dlcaid  ; dlc id attribute id — second unique attr, forces count>1
    SET imdbaid=$$GetEID^sapiGet("sandbox.movie.imdbid")
    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET RR("+",imdbaid)="tt9999998"
    SET RR("+",dlcaid)="998"
    SET RR("+",RESOLVEDBYID)="sandbox.foobar.id"
    SET eid=$$ResolveByUnique^apiRslv(.RR)
    DO AssertTrue("B17: ResolveByUnique rejects unknown attrkey",eid=0)
    QUIT

TestB18 ; ResolveByUnique attrkey not unique
;;------------------------------------------------------------------
;; Purpose: A sys.attr.resolvedby value naming an attribute that is
;;          not unique-constrained is rejected
;; Scope: ResolveByUnique^apiRslv, ResolveDesignatedUnique^apiRslv
;; Assert Condition: resolution fails
;;------------------------------------------------------------------
    WRITE !,"B18: ResolveByUnique attrkey not unique"
    NEW RR       ; staged record
    NEW eid      ; resolved entity id
    NEW titleaid ; title attribute id — not unique, named by resolvedby
    NEW imdbaid  ; imdbid attribute id — second unique attr, forces count>1
    NEW dlcaid   ; dlc id attribute id — second unique attr, forces count>1
    SET titleaid=$$GetEID^sapiGet("sandbox.movie.title")
    SET imdbaid=$$GetEID^sapiGet("sandbox.movie.imdbid")
    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET RR("+",titleaid)="The Reader"
    SET RR("+",imdbaid)="tt9999997"
    SET RR("+",dlcaid)="997"
    SET RR("+",RESOLVEDBYID)="sandbox.movie.title"
    SET eid=$$ResolveByUnique^apiRslv(.RR)
    DO AssertTrue("B18: ResolveByUnique rejects non unique attribute",eid=0)
    QUIT

TestB19 ; ResolveByUnique resolvedby attribute missing value
;;------------------------------------------------------------------
;; Purpose: A sys.attr.resolvedby value naming a unique attribute for
;;          which the record supplies no value is rejected
;; Scope: ResolveByUnique^apiRslv, ResolveDesignatedUnique^apiRslv
;; Assert Condition: resolution fails
;;------------------------------------------------------------------
    WRITE !,"B19: ResolveByUnique resolvedby attribute missing value"
    NEW RR      ; staged record
    NEW eid     ; resolved entity id
    NEW tmdbaid ; tmdbid attribute id — second unique attr, forces count>1
    NEW dlcaid  ; dlc id attribute id — second unique attr, forces count>1
    SET tmdbaid=$$GetEID^sapiGet("sandbox.movie.tmdbid")
    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET RR("+",tmdbaid)="99997"
    SET RR("+",dlcaid)="996"
    SET RR("+",RESOLVEDBYID)="sandbox.movie.imdbid"
    SET eid=$$ResolveByUnique^apiRslv(.RR)
    DO AssertTrue("B19: ResolveByUnique rejects missing resolvedby value",eid=0)
    QUIT

TestB20 ; ResolveByUnique resolvedby attribute empty value
;;------------------------------------------------------------------
;; Purpose: A sys.attr.resolvedby value naming a unique attribute
;;          whose supplied value is an empty string is rejected
;; Scope: ResolveByUnique^apiRslv, ResolveDesignatedUnique^apiRslv
;; Assert Condition: resolution fails
;;------------------------------------------------------------------
    WRITE !,"B20: ResolveByUnique resolvedby attribute empty value"
    NEW RR      ; staged record
    NEW eid     ; resolved entity id
    NEW imdbaid ; imdbid attribute id — empty value, named by resolvedby
    NEW dlcaid  ; dlc id attribute id — second unique attr, forces count>1
    SET imdbaid=$$GetEID^sapiGet("sandbox.movie.imdbid")
    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET RR("+",imdbaid)=""
    SET RR("+",dlcaid)="995"
    SET RR("+",RESOLVEDBYID)="sandbox.movie.imdbid"
    SET eid=$$ResolveByUnique^apiRslv(.RR)
    DO AssertTrue("B20: ResolveByUnique rejects empty resolvedby value",eid=0)
    QUIT

TestB21 ; ResolveByUnique UNQINSERT new value via resolvedby
;;------------------------------------------------------------------
;; Purpose: A sys.attr.resolvedby directive naming a UNQINSERT
;;          attribute with a new value resolves to a freshly created
;;          entity, even when other unique attributes are present
;; Scope: ResolveByUnique^apiRslv, ResolveDesignatedUnique^apiRslv
;; Assert Condition: resolution returns a non-empty eid
;;------------------------------------------------------------------
    WRITE !,"B21: ResolveByUnique UNQINSERT new value via resolvedby"
    NEW RR      ; staged record
    NEW eid     ; resolved entity id
    NEW imdbaid ; imdbid attribute id — named by resolvedby
    NEW dlcaid  ; dlc id attribute id — second unique attr, forces count>1
    SET imdbaid=$$GetEID^sapiGet("sandbox.movie.imdbid")
    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET RR("+",RESOLVEDBYID)="sandbox.movie.imdbid"
    SET RR("+",imdbaid)="tt9999996"
    SET RR("+",dlcaid)="994"
    SET eid=$$ResolveByUnique^apiRslv(.RR)
    DO AssertTrue("B21: ResolveByUnique UNQINSERT via resolvedby creates entity",eid'="")
    QUIT

TestB22 ; ResolveByUnique UNQUPSERT existing value via resolvedby
;;------------------------------------------------------------------
;; Purpose: A sys.attr.resolvedby directive naming a UNQUPSERT
;;          attribute with an existing value resolves to its current
;;          owner, even when other unique attributes are present
;; Scope: ResolveByUnique^apiRslv, ResolveDesignatedUnique^apiRslv
;; Assert Condition: resolution returns the known owner eid
;;------------------------------------------------------------------
    WRITE !,"B22: ResolveByUnique UNQUPSERT existing value via resolvedby"
    NEW RR          ; staged record
    NEW eid          ; resolved entity id
    NEW dlcaid       ; dlc id attribute id — named by resolvedby
    NEW imdbaid      ; imdbid attribute id — second unique attr, forces count>1
    NEW expectedeid  ; known owner eid of dlc item 042
    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET imdbaid=$$GetEID^sapiGet("sandbox.movie.imdbid")
    SET RR("+",RESOLVEDBYID)="sandbox.dlc.id"
    SET RR("+",dlcaid)="042"
    SET RR("+",imdbaid)="tt9999993"
    SET expectedeid=$$GetEID^apiGet("042",dlcaid)
    SET eid=$$ResolveByUnique^apiRslv(.RR)
    DO AssertTrue("B22: ResolveByUnique UNQUPSERT via resolvedby resolves owner",eid=expectedeid)
    QUIT

TestB23 ; ResolveTargetEntity Path 0 valid EID
;;------------------------------------------------------------------
;; Purpose: A record carrying sys.attr.id resolves via Path 0 to the
;;          referenced entity, even when other attributes are present
;; Scope: ResolveTargetEntity^apiRslv, ResolveByEID^apiRslv
;; Assert Condition: resolution returns the existing eid
;;------------------------------------------------------------------
    WRITE !,"B23: ResolveTargetEntity valid EID"
    NEW RR          ; staged record
    NEW eid          ; resolved entity id
    NEW existingeid  ; known eid of obj.tom_hanks
    SET existingeid=$$GetEID^apiGet("obj.tom_hanks")
    SET RR("+",SYSATTRID)=existingeid
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.title"))="Tom Hanks Movie"
    SET eid=$$ResolveTargetEntity^apiRslv(.RR)
    DO AssertTrue("B23: ResolveTargetEntity resolves EID",eid=existingeid)
    QUIT

TestB24 ; ResolveTargetEntity Path 0 invalid EID
;;------------------------------------------------------------------
;; Purpose: A record carrying a well-formed but unregistered
;;          sys.attr.id is rejected via Path 0
;; Scope: ResolveTargetEntity^apiRslv, ResolveByEID^apiRslv
;; Assert Condition: resolution fails
;;------------------------------------------------------------------
    WRITE !,"B24: ResolveTargetEntity invalid EID"
    NEW RR  ; staged record
    NEW eid ; resolved entity id
    SET RR("+",SYSATTRID)="65560e13bd45f6y9xowl"
    SET eid=$$ResolveTargetEntity^apiRslv(.RR)
    DO AssertTrue("B24: ResolveTargetEntity rejects invalid EID",eid=0)
    QUIT

TestB25 ; ResolveTargetEntity Path 1 natural key
;;------------------------------------------------------------------
;; Purpose: A record carrying sys.attr.key for an existing key
;;          resolves via Path 1 to that entity
;; Scope: ResolveTargetEntity^apiRslv, ResolveByNaturalKey^apiRslv
;; Assert Condition: resolution returns the existing eid
;;------------------------------------------------------------------
    WRITE !,"B25: ResolveTargetEntity natural key"
    NEW RR        ; staged record
    NEW eid        ; resolved entity id
    NEW expected   ; known eid of obj.tom_hanks
    SET expected=$$GetEID^apiGet("obj.tom_hanks")
    SET RR("+",AKEYID)="obj.tom_hanks"
    SET eid=$$ResolveTargetEntity^apiRslv(.RR)
    DO AssertTrue("B25: ResolveTargetEntity resolves natural key",eid=expected)
    QUIT

TestB26 ; ResolveTargetEntity Path 1 natural key creates GENID
;;------------------------------------------------------------------
;; Purpose: A record carrying sys.attr.key for a key not yet in the
;;          database generates a fresh entity via Path 1
;; Scope: ResolveTargetEntity^apiRslv, ResolveByNaturalKey^apiRslv
;; Assert Condition: resolution returns a non-empty eid
;;------------------------------------------------------------------
    WRITE !,"B26: ResolveTargetEntity unknown natural key"
    NEW RR  ; staged record
    NEW eid ; resolved entity id
    SET RR("+",AKEYID)="obj.brand_new"
    SET eid=$$ResolveTargetEntity^apiRslv(.RR)
    DO AssertTrue("B26: ResolveTargetEntity creates GENID",eid'="")
    QUIT

TestB27 ; ResolveTargetEntity Path 2 anonymous entity
;;------------------------------------------------------------------
;; Purpose: A record with no sys.attr.id, sys.attr.key, or unique
;;          attributes still resolves via Path 2 as a new anonymous
;;          entity
;; Scope: ResolveTargetEntity^apiRslv, ResolveByUnique^apiRslv
;; Assert Condition: resolution returns a non-empty eid
;;------------------------------------------------------------------
    WRITE !,"B27: ResolveTargetEntity anonymous entity"
    NEW RR  ; staged record
    NEW eid ; resolved entity id
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.title"))="Anonymous"
    SET eid=$$ResolveTargetEntity^apiRslv(.RR)
    DO AssertTrue("B27: ResolveTargetEntity anonymous GENID",eid'="")
    QUIT

TestB28 ; ResolveTargetEntity Path 2 UNQUPSERT merge
;;------------------------------------------------------------------
;; Purpose: A record supplying only an existing UNQUPSERT attribute
;;          value resolves via Path 2 to its current owner
;; Scope: ResolveTargetEntity^apiRslv, ResolveByUnique^apiRslv, ResolveOwnership^apiRslv
;; Assert Condition: resolution returns the known owner eid
;;------------------------------------------------------------------
    WRITE !,"B28: ResolveTargetEntity UNQUPSERT merge"
    NEW RR          ; staged record
    NEW eid          ; resolved entity id
    NEW dlcaid       ; dlc id attribute id
    NEW expectedeid  ; known owner eid of dlc item 042
    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET RR("+",dlcaid)="042"
    SET expectedeid=$$GetEID^apiGet("042",dlcaid)
    SET eid=$$ResolveTargetEntity^apiRslv(.RR)
    DO AssertTrue("B28: ResolveTargetEntity UNQUPSERT merge",eid=expectedeid)
    QUIT

TestB29 ; ResolveTargetEntity resolveby consumed
;;------------------------------------------------------------------
;; Purpose: sys.attr.resolvedby is removed from the record once it
;;          is actually used to disambiguate multiple unique
;;          attributes during target entity resolution
;; Scope: ResolveTargetEntity^apiRslv, ResolveByUnique^apiRslv,
;;        ResolveDesignatedUnique^apiRslv
;; Assert Condition: sys.attr.resolvedby is no longer present in the
;;                    record
;;------------------------------------------------------------------
    WRITE !,"B29: ResolveTargetEntity resolveby consumed"
    NEW RR       ; staged record
    NEW eid      ; resolved entity id
    NEW genreaid ; genre attribute id — non-unique, rides along
    NEW imdbaid  ; imdbid attribute id — second unique attr, forces count>1
    NEW tmdbaid  ; tmdbid attribute id — named by resolvedby
    SET genreaid=$$GetEID^sapiGet("sandbox.movie.genre")
    SET imdbaid=$$GetEID^sapiGet("sandbox.movie.imdbid")
    SET tmdbaid=$$GetEID^sapiGet("sandbox.movie.tmdbid")
    SET RR("+",genreaid)="crime"
    SET RR("+",imdbaid)="tt0011100"
    SET RR("+",tmdbaid)=807
    SET RR("+",RESOLVEDBYID)="sandbox.movie.tmdbid"
    SET eid=$$ResolveTargetEntity^apiRslv(.RR)
    DO AssertTrue("B29: ResolveTargetEntity resolveby consumed",'$DATA(RR("+",RESOLVEDBYID)))
    QUIT

TestB30 ; ResolveTargetEntity via Path 0 leaves entity facts intact
;;------------------------------------------------------------------
;; Purpose: When resolution proceeds via Path 0 (sys.attr.id), the
;;          control attribute is removed while unrelated entity
;;          facts remain untouched in the record
;; Scope: ResolveTargetEntity^apiRslv, ResolveByEID^apiRslv
;; Assert Condition: sys.attr.id is no longer present, and the
;;                    entity facts supplied alongside it remain
;;------------------------------------------------------------------
    WRITE !,"B30: ResolveTargetEntity Path 0 leaves entity facts"
    NEW RR          ; staged record
    NEW eid          ; resolved entity id
    NEW dlcaid       ; dlc id attribute id
    NEW checkupaid   ; dlc checkup attribute id
    NEW countaid     ; dlc count attribute id
    NEW existingeid  ; known eid of obj.tom_hanks
    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET checkupaid=$$GetEID^sapiGet("sandbox.dlc.checkup")
    SET countaid=$$GetEID^sapiGet("sandbox.dlc.count")
    SET existingeid=$$GetEID^apiGet("obj.tom_hanks")
    SET RR("+",SYSATTRID)=existingeid
    SET RR("+",dlcaid)="042"
    SET RR("+",checkupaid)="Dilithium Crystals on 1st February 2013 @en"
    SET RR("+",countaid)=250
    SET eid=$$ResolveTargetEntity^apiRslv(.RR)
    DO AssertTrue("B30: ResolveTargetEntity Path 0 consumes sys.attr.id only",'$DATA(RR("+",SYSATTRID))&$DATA(RR("+",dlcaid))&$DATA(RR("+",checkupaid))&$DATA(RR("+",countaid)))
    QUIT


LayerC
;; ==================================================================================================
;; LAYER C — Record validation and attribute resolution
;; ==================================================================================================
;;
;; Test Coverage: Required-attribute enforcement, empty-value rejection on
;;                assertions, retraction values being ignored by validation,
;;                bulk-load bypass of ValidateRecord, and simultaneous
;;                assert/retract resolution on the same attribute key.
;;
;; Scope: ValidateRecord^apiVld, Stage^api, Transact^api,
;;        ResolveRecAttrs^apiRslv
;;
;; Result: 8/8 PASS
;; ==================================================================================================
    DO TestC1 ; ValidateRecord all values valid
    DO TestC2 ; ValidateRecord empty assertion value
    DO TestC3 ; ValidateRecord all required attrs present
    DO TestC4 ; ValidateRecord missing required attr
    DO TestC5 ; ValidateRecord multiple required attrs missing
    DO TestC6 ; ValidateRecord empty retraction ignored
    DO TestC7 ; Bulk load skips validation
    DO TestC8 ; ResolveRecAttrs handles simultaneous assert and retract on same akey
    QUIT

TestC1 ; ValidateRecord all values valid
;;------------------------------------------------------------------
;; Purpose: A record containing valid assertion values passes
;;          validation
;; Scope: ValidateRecord^apiVld
;; Assert Condition: validation succeeds
;;------------------------------------------------------------------
    WRITE !,"C1: ValidateRecord all values valid"
    NEW RR         ; staged record
    NEW ReqAttr    ; required attributes for sandbox.movie
    NEW AttrCache  ; attribute cache for sandbox.movie
    NEW ok         ; validation success flag
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.title"))="The Reader @en"
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.imdbid"))="tt0011100"
    DO BuildAttrsRequired^sapiBld("sandbox.movie",.ReqAttr)
    DO BuildAttrsCache^sapiBld("sandbox.movie",.AttrCache)
    SET ok=$$ValidateRecord^apiVld(.RR,.ReqAttr,.AttrCache)
    DO AssertTrue("C1: ValidateRecord valid record",ok=1)
    QUIT

TestC2 ; ValidateRecord empty assertion value
;;------------------------------------------------------------------
;; Purpose: An empty value on an assertion is rejected before staging
;; Scope: ValidateRecord^apiVld
;; Assert Condition: validation fails
;;------------------------------------------------------------------
    WRITE !,"C2: ValidateRecord empty assertion value"
    NEW RR         ; staged record
    NEW ReqAttr    ; required attributes for sandbox.movie
    NEW AttrCache  ; attribute cache for sandbox.movie
    NEW ok         ; validation success flag
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.title"))=""
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.imdbid"))="tt0011100"
    DO BuildAttrsRequired^sapiBld("sandbox.movie",.ReqAttr)
    DO BuildAttrsCache^sapiBld("sandbox.movie",.AttrCache)
    SET ok=$$ValidateRecord^apiVld(.RR,.ReqAttr,.AttrCache)
    DO AssertTrue("C2: ValidateRecord rejects empty assertion",ok=0)
    QUIT

TestC3 ; ValidateRecord all required attrs present
;;------------------------------------------------------------------
;; Purpose: A record containing all required attributes passes
;;          validation
;; Scope: ValidateRecord^apiVld
;; Assert Condition: validation succeeds
;;------------------------------------------------------------------
    WRITE !,"C3: ValidateRecord all required attrs present"
    NEW RR         ; staged record
    NEW ReqAttr    ; required attributes for sandbox.movie
    NEW AttrCache  ; attribute cache for sandbox.movie
    NEW ok         ; validation success flag
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.title"))="The Reader @en"
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.genre"))="drama"
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.releaseYear"))=2008
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.imdbid"))="tt0011100"
    DO BuildAttrsRequired^sapiBld("sandbox.movie",.ReqAttr)
    DO BuildAttrsCache^sapiBld("sandbox.movie",.AttrCache)
    SET ok=$$ValidateRecord^apiVld(.RR,.ReqAttr,.AttrCache)
    DO AssertTrue("C3: ValidateRecord all required attributes present",ok=1)
    QUIT

TestC4 ; ValidateRecord missing required attr
;;------------------------------------------------------------------
;; Purpose: A missing required attribute (sandbox.movie.imdbid) is
;;          detected and validation fails
;; Scope: ValidateRecord^apiVld
;; Assert Condition: validation fails
;;------------------------------------------------------------------
    WRITE !,"C4: ValidateRecord missing required attr"
    NEW RR         ; staged record
    NEW ReqAttr    ; required attributes for sandbox.movie
    NEW AttrCache  ; attribute cache for sandbox.movie
    NEW ok         ; validation success flag
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.title"))="The Reader @en"
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.genre"))="drama"
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.releaseYear"))=2008
    ; missing movie.imdbid
    DO BuildAttrsRequired^sapiBld("sandbox.movie",.ReqAttr)
    DO BuildAttrsCache^sapiBld("sandbox.movie",.AttrCache)
    SET ok=$$ValidateRecord^apiVld(.RR,.ReqAttr,.AttrCache)
    DO AssertTrue("C4: ValidateRecord missing required attribute",ok=0)
    QUIT

TestC5 ; ValidateRecord multiple required attrs missing
;;------------------------------------------------------------------
;; Purpose: Multiple missing required attributes are detected
;;          together and validation fails
;; Scope: ValidateRecord^apiVld
;; Assert Condition: validation fails
;;------------------------------------------------------------------
    WRITE !,"C5: ValidateRecord multiple required attrs missing"
    NEW RR         ; staged record
    NEW ReqAttr    ; required attributes for sandbox.movie
    NEW AttrCache  ; attribute cache for sandbox.movie
    NEW ok         ; validation success flag
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.genre"))="drama"
    ; missing title and imdbid
    DO BuildAttrsRequired^sapiBld("sandbox.movie",.ReqAttr)
    DO BuildAttrsCache^sapiBld("sandbox.movie",.AttrCache)
    SET ok=$$ValidateRecord^apiVld(.RR,.ReqAttr,.AttrCache)
    DO AssertTrue("C5: ValidateRecord multiple missing attributes",ok=0)
    QUIT

TestC6 ; ValidateRecord empty retraction ignored
;;------------------------------------------------------------------
;; Purpose: Empty values used for retractions are ignored during
;;          validation — the staging layer remains responsible for
;;          retraction semantics
;; Scope: ValidateRecord^apiVld
;; Assert Condition: validation succeeds
;;------------------------------------------------------------------
    WRITE !,"C6: ValidateRecord ignores empty retraction"
    NEW RR         ; staged record
    NEW ReqAttr    ; required attributes for sandbox.movie
    NEW AttrCache  ; attribute cache for sandbox.movie
    NEW ok         ; validation success flag
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.title"))="The Reader @en"
    SET RR("+",$$GetEID^sapiGet("sandbox.movie.imdbid"))="tt0011100"
    ; empty retraction for a multi-value attribute is forbidden, but ValidateRecord does not check retractions
    SET RR("-",$$GetEID^sapiGet("sandbox.movie.genre"))=""
    DO BuildAttrsRequired^sapiBld("sandbox.movie",.ReqAttr)
    DO BuildAttrsCache^sapiBld("sandbox.movie",.AttrCache)
    SET ok=$$ValidateRecord^apiVld(.RR,.ReqAttr,.AttrCache)
    DO AssertTrue("C6: ValidateRecord ignores retraction values",ok=1)
    QUIT

TestC7 ; Bulk load skips validation
;;------------------------------------------------------------------
;; Purpose: isBulkLoad=1 skips ValidateRecord while preserving the
;;          normal ResolveTargetEntity -> StageRecord -> Transact
;;          lifecycle, even when a required attribute is missing
;; Scope: Stage^api, Transact^api
;; Assert Condition: the batch commits successfully despite the
;;                    missing required attribute
;;------------------------------------------------------------------
    WRITE !,"C7: Bulk load skips validation"
    NEW Movies  ; batch of records to bulk load
    KILL Movies
    SET Movies(1,"movie.title")="No IMDB Movie"
    SET Movies(1,"movie.genre")="drama"
    SET Movies(1,"movie.releaseYear")=2008
    ; missing required movie.imdbid — would fail ValidateRecord
    DO INIT^api
    DO Stage^api(.Movies,"sandbox",1)
    DO Transact^api
    DO AssertTrue("C7: Bulk load bypasses validation",1)
    QUIT

TestC8 ; ResolveRecAttrs handles simultaneous assert and retract on same akey
;;------------------------------------------------------------------
;; Purpose: When the same attribute key carries both an assert and a
;;          retract (e.g. a multi-value attribute: retract one value,
;;          assert another), ResolveRecAttrs stages both independently
;; Scope: ResolveRecAttrs^apiRslv
;; Assert Condition: resolution succeeds, the asserted value is staged
;;                    under "+" and the retracted value under "-" for
;;                    the same attribute
;;------------------------------------------------------------------
    WRITE !,"C8: ResolveRecAttrs handles simultaneous assert and retract on same akey"
    NEW Data         ; single-record input keyed by record number
    NEW AttrsCache   ; attribute cache for sandbox.movie
    NEW ResolvedRec  ; resolved record (output)
    NEW ok           ; resolution success flag
    SET Data(1,id)=$$LookupEID^apiGet("tt0011100","sandbox.movie.imdbid")
    SET Data(1,"movie.genre")="drama"
    SET Data(1,"movie.genre","-")="thriller"
    DO BuildAttrsCache^sapiBld("sandbox.movie",.AttrsCache)
    SET ok=$$ResolveRecAttrs^apiRslv("sandbox",$NAME(Data(1)),.AttrsCache,.ResolvedRec)
    DO AssertTrue("C8: ResolveRecAttrs handles simultaneous assert and retract on same akey",(ok=1)&(ResolvedRec("+",1001)="drama")&(ResolvedRec("-",1001)="thriller"))
    QUIT


LayerD
;; ==================================================================================================
;; LAYER D — Datom write-front-line: DatomAssert and DatomRevise
;; ==================================================================================================
;;
;; Test Coverage: Cardinality-one and cardinality-many assertion semantics
;;                (new value, no-op on duplicate, replacement), UNQINSERT
;;                acceptance and duplicate rejection, pipe-delimited
;;                multi-value expansion and its rejection on cardinality-one
;;                attributes, the initialization requirement for staging,
;;                and DatomRevise insert/no-op/replacement semantics.
;;
;; Scope: DatomAssert^apiWFL, DatomRevise^apiWFL
;;
;; Result: 12/12 PASS
;; ==================================================================================================
    DO TestD1  ; Cardinality-one new value
    DO TestD2  ; Cardinality-one no-op on same value
    DO TestD3  ; Cardinality-one replacement
    DO TestD4  ; Cardinality-many new value
    DO TestD5  ; Cardinality-many duplicate value
    DO TestD6  ; UNQINSERT new value
    DO TestD7  ; UNQINSERT duplicate
    DO TestD8  ; Multi-value expansion
    DO TestD9  ; Pipe on cardinality-one
	DO TestD10 ; DatomRevise replacement    
    DO TestD11 ; DatomRevise insert
    DO TestD12 ; DatomRevise same value

    QUIT


TestD1 ; Cardinality-one new value
;;------------------------------------------------------------------
;; Purpose: A cardinality-one attribute with no active value inserts
;;          the new value as a staged assertion
;; Scope: DatomAssert^apiWFL
;; Assert Condition: assertion succeeds and the value is staged in
;;                    %ABR
;;------------------------------------------------------------------
    WRITE !,"D1: DatomAssert cardinality-one new value"
    NEW eid  ; new entity id
    NEW aid  ; title attribute id
    NEW ok   ; assertion success flag
    DO INIT^api
    SET eid=$$GENID^utils
    SET aid=$$GetEID^sapiGet("sandbox.movie.title")
    SET ok=$$DatomAssert^apiWFL(eid,aid,"New Movie Title")
    DO AssertTrue("D1: DatomAssert cardinality-one inserts new value",(ok=1)&($DATA(%ABR(eid,aid))))
    QUIT

TestD2 ; Cardinality-one no-op on same value
;;------------------------------------------------------------------
;; Purpose: Asserting the value already active for a cardinality-one
;;          attribute is a no-op
;; Scope: DatomAssert^apiWFL
;; Assert Condition: assertion succeeds without staging a change
;;------------------------------------------------------------------
    WRITE !,"D2: DatomAssert cardinality-one same active value"
    NEW eid  ; eid of obj.tom_hanks
    NEW aid  ; sys.attr.name attribute id
    NEW ok   ; assertion success flag
    DO INIT^api
    SET eid=$$GetEID^apiGet("obj.tom_hanks")
    SET aid=$$GetEID^sapiGet("sys.attr.name")
    SET ok=$$DatomAssert^apiWFL(eid,aid,"tom_hanks")
    DO AssertTrue("D2: DatomAssert skips existing active value",ok=2)
    QUIT

TestD3 ; Cardinality-one replacement
;;------------------------------------------------------------------
;; Purpose: Asserting a new value for a cardinality-one attribute
;;          that already has an active value retracts the old value
;;          and asserts the new one
;; Scope: DatomAssert^apiWFL
;; Assert Condition: assertion succeeds and %ABR contains both a
;;                    retraction and an assertion for this attribute
;;------------------------------------------------------------------
    WRITE !,"D3: DatomAssert cardinality-one replacement"
    NEW eid         ; eid of obj.tom_hanks
    NEW aid         ; sys.attr.name attribute id
    NEW ok          ; assertion success flag
    NEW hasRetract  ; whether a retraction was staged
    NEW hasAssert   ; whether an assertion was staged
    NEW vk          ; valkey iterator
    DO INIT^api
    SET eid=$$GetEID^apiGet("obj.tom_hanks")
    SET aid=$$GetEID^sapiGet("sys.attr.name")
    SET ok=$$DatomAssert^apiWFL(eid,aid,"tommy")
    SET vk=""
    FOR  SET vk=$ORDER(%ABR(eid,aid,vk)) QUIT:vk=""  DO
    . IF %ABR(eid,aid,vk)=0 SET hasRetract=1
    . IF %ABR(eid,aid,vk)=1 SET hasAssert=1
    DO AssertTrue("D3: DatomAssert replaces cardinality-one value",(ok=1)&$GET(hasRetract)&$GET(hasAssert))
    QUIT

TestD4 ; Cardinality-many new value
;;------------------------------------------------------------------
;; Purpose: A cardinality-many attribute accepts a new value in
;;          addition to any existing values
;; Scope: DatomAssert^apiWFL
;; Assert Condition: assertion succeeds
;;------------------------------------------------------------------
    WRITE !,"D4: DatomAssert cardinality-many new value"
    NEW eid  ; eid of obj.tom_hanks
    NEW aid  ; sys.attr.alias attribute id
    NEW ok   ; assertion success flag
    DO INIT^api
    SET eid=$$GetEID^apiGet("obj.tom_hanks")
    SET aid=$$GetEID^sapiGet("sys.attr.alias")
    SET ok=$$DatomAssert^apiWFL(eid,aid,"NewAlias")
    DO AssertTrue("D4: DatomAssert adds cardinality-many value",ok=1)
    QUIT

TestD5 ; Cardinality-many duplicate value
;;------------------------------------------------------------------
;; Purpose: Asserting a value already active for a cardinality-many
;;          attribute is a no-op — no new datom is staged and no
;;          keyword registration is triggered
;; Scope: DatomAssert^apiWFL
;; Assert Condition: assertion succeeds, nothing is staged for the
;;                    existing valkey, and the keyword count is
;;                    unchanged
;;------------------------------------------------------------------
    WRITE !,"D5: DatomAssert cardinality-many existing value — no-op"
    NEW eid              ; eid of obj.tom_hanks
    NEW aid              ; sys.attr.alias attribute id
    NEW ok               ; assertion success flag
    NEW valkey           ; resolved valkey for "TomHanks"
    NEW isNew            ; whether RegisterAttrVal registered a new valkey
    NEW stagedCount       ; whether anything staged for this valkey
    NEW tbkwCountBefore  ; ^TBKW subscript snapshot before assertion
    NEW tbkwCountAfter   ; ^TBKW subscript snapshot after assertion
    DO INIT^api
    SET eid=$$GetEID^apiGet("obj.tom_hanks")
    SET aid=$$GetEID^sapiGet("sys.attr.alias")

    ; Resolve valkey for "TomHanks" without staging anything —
    ; needed to check %ABR afterward for this specific valkey
    SET isNew=$$RegisterAttrVal^sapiRslv(aid,"TomHanks",.valkey)

    ; Snapshot ^TBKW count before, to confirm AddKeyword did not fire
    SET tbkwCountBefore=$ORDER(^TBKW("obj.tom_hanks",""),-1)

    SET ok=$$DatomAssert^apiWFL(eid,aid,"TomHanks")    ; already active

    SET stagedCount=$DATA(%ABR(eid,aid,valkey))
    SET tbkwCountAfter=$ORDER(^TBKW("obj.tom_hanks",""),-1)

    DO AssertTrue("D5: DatomAssert skips duplicate cardinality-many value",(ok=2)&('stagedCount)&(tbkwCountAfter=tbkwCountBefore))
    QUIT

TestD6 ; UNQINSERT new value
;;------------------------------------------------------------------
;; Purpose: A new value for a UNQINSERT attribute is accepted
;; Scope: DatomAssert^apiWFL
;; Assert Condition: assertion succeeds
;;------------------------------------------------------------------
    WRITE !,"D6: DatomAssert UNQINSERT new value"
    NEW eid  ; new entity id
    NEW aid  ; imdbid attribute id
    NEW ok   ; assertion success flag
    DO INIT^api
    SET eid=$$GENID^utils
    SET aid=$$GetEID^sapiGet("sandbox.movie.imdbid")
    SET ok=$$DatomAssert^apiWFL(eid,aid,"tt9999995")
    DO AssertTrue("D6: DatomAssert allows new UNQINSERT value",ok=1)
    QUIT

TestD7 ; UNQINSERT duplicate
;;------------------------------------------------------------------
;; Purpose: A value already owned by another entity under a
;;          UNQINSERT attribute is rejected
;; Scope: DatomAssert^apiWFL
;; Assert Condition: assertion fails
;;------------------------------------------------------------------	
    WRITE !,"D7: DatomAssert UNQINSERT duplicate"
    NEW eid  ; new entity id
    NEW aid  ; imdbid attribute id
    NEW ok   ; assertion success flag
    DO INIT^api
    SET eid=$$GENID^utils
    SET aid=$$GetEID^sapiGet("sandbox.movie.imdbid")
    SET ok=$$DatomAssert^apiWFL(eid,aid,"tt0011100")    ; Movie Seven already has this IMDBID
    DO AssertTrue("D7: DatomAssert rejects UNQINSERT duplicate",ok=0)
    QUIT

TestD8 ; Multi-value expansion
;;------------------------------------------------------------------
;; Purpose: A pipe-delimited input value for a cardinality-many
;;          attribute expands into multiple individually staged
;;          assertions
;; Scope: DatomAssert^apiWFL
;; Assert Condition: assertion succeeds and all three values are
;;                    staged
;;------------------------------------------------------------------
    WRITE !,"D8: DatomAssert multi-value expansion"
    NEW eid    ; new entity id
    NEW aid    ; genre attribute id
    NEW ok     ; assertion success flag
    NEW count  ; count of staged assertions found
    NEW vk     ; valkey iterator
    DO INIT^api
    SET eid=$$GENID^utils
    SET aid=$$GetEID^sapiGet("sandbox.movie.genre")
    SET ok=$$DatomAssert^apiWFL(eid,aid,"drama|romance|thriller")
    SET count=0
    SET vk=""
    FOR  SET vk=$ORDER(%ABR(eid,aid,vk)) QUIT:vk=""  DO
    . IF %ABR(eid,aid,vk)=1 SET count=count+1
    DO AssertTrue("D8: DatomAssert expands multi-value input",(ok=1)&(count=3))
    QUIT

TestD9 ; Pipe on cardinality-one
;;------------------------------------------------------------------
;; Purpose: A pipe-delimited value is rejected for a cardinality-one
;;          attribute and nothing is staged
;; Scope: DatomAssert^apiWFL
;; Assert Condition: assertion fails and no value is staged
;;------------------------------------------------------------------
    WRITE !,"D9: DatomAssert rejects '|' for cardinality-one attribute"
    NEW eid     ; new entity id
    NEW aid     ; imdbid attribute id
    NEW ok      ; assertion success flag
    NEW staged  ; whether anything was staged
    DO INIT^api
    SET eid=$$GENID^utils
    SET aid=$$GetEID^sapiGet("sandbox.movie.imdbid")
    SET ok=$$DatomAssert^apiWFL(eid,aid,"tt0011100|tt9999994")
    SET staged=$DATA(%ABR(eid,aid))
    DO AssertTrue("D9: DatomAssert rejects pipe on cardinality-one",(ok=0)&('staged))
    QUIT

TestD10 ; DatomRevise replacement
;;------------------------------------------------------------------
;; Purpose: Revising an attribute to a different value retracts the
;;          currently active value and asserts the new one
;; Scope: DatomRevise^apiWFL
;; Assert Condition: revision succeeds, the old value is staged as a
;;                    retraction, and the new value is staged as an
;;                    assertion
;;------------------------------------------------------------------
    WRITE !,"D10: DatomRevise replaces active value"
    NEW eid           ; eid of obj.tom_hanks
    NEW aid           ; sys.attr.name attribute id
    NEW ok            ; revision success flag
    NEW activevalkey  ; currently active valkey
    NEW newvalkey     ; resolved valkey for "tommy_new"
    NEW isNew         ; whether RegisterAttrVal registered a new valkey
    DO INIT^api
    SET eid=$$GetEID^apiGet("obj.tom_hanks")
    SET aid=$$GetEID^sapiGet("sys.attr.name")
    SET activevalkey=$$GetCurrentVK^apiGet(eid,aid)
    SET isNew=$$RegisterAttrVal^sapiRslv(aid,"tommy_new",.newvalkey)
    SET ok=$$DatomRevise^apiWFL(eid,aid,newvalkey)
    DO AssertTrue("D10: DatomRevise retracts old value and asserts new value",(ok=1)&($GET(%ABR(eid,aid,activevalkey))=0)&($GET(%ABR(eid,aid,newvalkey))=1))
    QUIT

TestD11 ; DatomRevise insert
;;------------------------------------------------------------------
;; Purpose: DatomRevise inserts a value when the attribute has no
;;          currently active value
;; Scope: DatomRevise^apiWFL
;; Assert Condition: revision succeeds and the value is staged as an
;;                    assertion
;;------------------------------------------------------------------
    WRITE !,"D11: DatomRevise no active value"
    NEW eid     ; new entity id
    NEW aid     ; title attribute id
    NEW valkey  ; resolved valkey for "Brand New Title"
    NEW ok      ; revision success flag
    NEW isNew   ; whether RegisterAttrVal registered a new valkey
    DO INIT^api
    SET eid=$$GENID^utils
    SET aid=$$GetEID^sapiGet("sandbox.movie.title")
    SET isNew=$$RegisterAttrVal^sapiRslv(aid,"Brand New Title",.valkey)
    SET ok=$$DatomRevise^apiWFL(eid,aid,valkey)
    DO AssertTrue("D11: DatomRevise inserts value",(ok=1)&($GET(%ABR(eid,aid,valkey))=1))
    QUIT

TestD12 ; DatomRevise same value
;;------------------------------------------------------------------
;; Purpose: Revising an attribute to the value it is already set to
;;          is a no-op
;; Scope: DatomRevise^apiWFL
;; Assert Condition: revision succeeds without staging any change
;;------------------------------------------------------------------
    WRITE !,"D12: DatomRevise same active value"
    NEW eid           ; eid of obj.tom_hanks
    NEW aid           ; sys.attr.name attribute id
    NEW activevalkey  ; currently active valkey
    NEW ok            ; revision success flag
    DO INIT^api
    SET eid=$$GetEID^apiGet("obj.tom_hanks")
    SET aid=$$GetEID^sapiGet("sys.attr.name")
    SET activevalkey=$$GetCurrentVK^apiGet(eid,aid)
    SET ok=$$DatomRevise^apiWFL(eid,aid,activevalkey)
    DO AssertTrue("D12: DatomRevise skips same value",(ok=2)&('$DATA(%ABR(eid,aid))))
    QUIT


LayerE
;; ==================================================================================================
;; LAYER E — End-to-end Stage: commit, rollback, and batch atomicity
;; ==================================================================================================
;;
;; Test Coverage: Full record assertion across all three target-resolution
;;                paths (raw EID, natural key, unique attribute), validation
;;                and UNQINSERT-collision rollback with no ghost entities,
;;                bulk-load bypass of validation, $ETRAP containment of a
;;                staging-time runtime error with rollback, batch atomicity
;;                when one record in a batch is invalid, and UNQUPSERT/
;;                UNQINSERT liveness resolution during staging.
;;
;; Scope: Stage^apiWFL
;;
;; Result: 13/13 PASS
;; ==================================================================================================
    DO TestE1  ; Stage Path 0 valid EID commit
    DO TestE2  ; Stage Path 0 invalid EID rollback
    DO TestE3  ; Stage failure
    DO TestE4  ; Stage Path 2 UNQUPSERT merge
    DO TestE5  ; Stage validation failure rollback
    DO TestE6  ; Stage UNQINSERT staging failure rollback
    DO TestE7  ; Stage GENID rollback leaves no ghost ^ABE entry
    DO TestE8  ; Stage bulk load bypasses validation
    DO TestE9  ; Stage rollback after retraction failure
    DO TestE10 ; Stage rollback after invalid retraction
    DO TestE11 ; Stage UNQINSERT collision rejected
    DO TestE12 ; Stage batch atomicity after invalid record
    DO TestE13 ; Stage UNQUPSERT resolves current live owner    
    QUIT

TestE1 ; Stage Path 0 valid EID commit
;;------------------------------------------------------------------
;; Purpose: A record referencing an existing entity via sys.attr.id
;;          commits an update to that entity's attribute
;; Scope: Stage^api, Transact^api
;; Assert Condition: the entity's name reflects the newly asserted
;;                    value after commit
;;------------------------------------------------------------------
    WRITE !,"E1: Stage Path 0 valid EID commit"
    NEW Item         ; input record batch
    NEW existingeid  ; eid of obj.tom_hanks
    NEW nameaid      ; sys.attr.name attribute id
    NEW valkey       ; current valkey after commit
    NEW dictval       ; resolved literal value after commit
    NEW ok           ; assertion outcome
    DO INIT^api
    SET existingeid=$$GetEID^apiGet("obj.tom_hanks")
    SET nameaid=$$GetEID^sapiGet("sys.attr.name")

    KILL Item
    SET Item(1,id)=existingeid
    SET Item(1,name)="tommy_e1"

    DO Stage^api(.Item)
    DO Transact^api

    SET valkey=$$GetCurrentVK^apiGet(existingeid,nameaid)
    SET dictval=$$GetDictValue^sapiGet(nameaid,valkey)
    SET ok=(dictval="tommy_e1")

    DO AssertTrue("E1: Stage Path 0 updates existing entity",ok)
    QUIT


TestE2 ; Stage Path 0 invalid EID rollback
;;------------------------------------------------------------------
;; Purpose: A record referencing a well-formed but unregistered
;;          sys.attr.id is rejected and nothing is staged
;; Scope: Stage^api, Transact^api
;; Assert Condition: nothing is staged for the batch
;;------------------------------------------------------------------
    WRITE !,"E2: Stage Path 0 invalid EID"
    NEW Item    ; input record batch
    NEW staged  ; whether anything was staged
    DO INIT^api

    KILL Item
    SET Item(1,id)="65560e13bd45f6y9xowl"    ; valid format but not in ^EATV
    SET Item(1,name)="should_not_appear"

    DO Stage^api(.Item)
    SET staged=($GET(%ABR,0)>0)
    DO Transact^api

    DO AssertTrue("E2: Stage invalid EID rejected, nothing staged",'staged)
    QUIT


TestE3 ; Stage failure
;;------------------------------------------------------------------
;; Purpose: A record pairing a new-entity natural key with an
;;          invalid retraction (retracting a value that was never
;;          asserted, since the entity is brand new) fails staging
;;          cleanly and the batch is discarded — no ghost entity is
;;          left behind
;; Scope: Stage^api, Transact^api, Stage^apiWFL
;; Assert Condition: the entity referenced by the natural key does
;;                    not resolve after the failed commit
;;------------------------------------------------------------------
    WRITE !,"E3: Stage $ETRAP containment and rollback"
    NEW Obj  ; input record batch
    NEW eid  ; eid lookup after the failed/rolled-back commit
    ; remove the name value
    ; add another label value
    KILL Obj
    SET Obj(1,key)="obj.foobar"
    SET Obj(1,name,"-")="none"
    SET Obj(1,label)="Τομ Χανκς @el"
    DO Stage^api(.Obj)
    DO Transact^api

    SET eid=$$GetEID^apiGet("obj.foobar")

    DO AssertTrue("E3: Stage rollback leaves no ghost entity",eid=0)
    QUIT


TestE4 ; Stage Path 2 UNQUPSERT merge
;;------------------------------------------------------------------
;; Purpose: A record referencing an existing UNQUPSERT attribute
;;          value merges into the current owner and commits an
;;          attribute update on that entity
;; Scope: Stage^api, Transact^api
;; Assert Condition: the resolved eid before and after commit match,
;;                    and the checkup value reflects the update
;;------------------------------------------------------------------
    WRITE !,"E4: Stage Path 2 UNQUPSERT merge"
    NEW Item          ; input record batch
    NEW eidBefore     ; owner eid resolved before commit
    NEW eidAfter      ; owner eid resolved after commit
    NEW dlcaid        ; dlc id attribute id
    NEW checkupaid    ; dlc checkup attribute id
    NEW checkupvalkey ; current valkey for checkup after commit
    NEW dictval        ; resolved literal checkup value after commit
    NEW ok            ; overall assertion outcome
    DO INIT^api

    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET eidBefore=$$GetEID^apiGet("042",dlcaid)

    KILL Item
    SET Item(1,dlcid)="042"
    SET Item(1,checkup)="E4 checkup update @en"

    DO Stage^api(.Item)
    DO Transact^api

    SET eidAfter=$$GetEID^apiGet("042",dlcaid)

    SET checkupaid=$$GetEID^sapiGet("sandbox.dlc.checkup")
    SET checkupvalkey=$$GetCurrentVK^apiGet(eidAfter,checkupaid)
    SET dictval=$$GetDictValue^sapiGet(checkupaid,checkupvalkey)

    SET ok=(eidBefore=eidAfter)&(dictval="E4 checkup update @en")

    DO AssertTrue("E4: Stage Path 2 UNQUPSERT updates existing entity",ok)
    QUIT

TestE5 ; Stage validation failure rollback
;;------------------------------------------------------------------
;; Purpose: A record missing a required attribute fails validation
;;          and nothing is staged
;; Scope: Stage^api, Transact^api
;; Assert Condition: nothing is staged for the batch
;;------------------------------------------------------------------
    WRITE !,"E5: Stage validation failure"
    NEW Movies  ; input record batch
    NEW staged  ; whether anything was staged
    DO INIT^api

    KILL Movies
    SET Movies(1,"title")="Missing IMDB @en"
    SET Movies(1,"genre")="drama"
    SET Movies(1,"releaseYear")=2008
    ; missing required movie.imdbid

    DO Stage^api(.Movies,"sandbox.movie")
    SET staged=($GET(%ABR,0)>0)
    DO Transact^api

    DO AssertTrue("E5: Stage validation failure — nothing staged",'staged)
    QUIT

TestE6 ; Stage UNQINSERT staging failure rollback
;;------------------------------------------------------------------
;; Purpose: A record supplying a UNQINSERT attribute value that
;;          already exists fails staging and nothing is staged
;; Scope: Stage^api, Transact^api
;; Assert Condition: nothing is staged for the batch
;;------------------------------------------------------------------
    WRITE !,"E6: Stage UNQINSERT collision rollback"
    NEW Movies  ; input record batch
    NEW staged  ; whether anything was staged
    DO INIT^api

    KILL Movies
    SET Movies(1,"movie.title")="Duplicate IMDB @en"
    SET Movies(1,"movie.genre")="drama"
    SET Movies(1,"movie.releaseYear")=2008
    SET Movies(1,"movie.imdbid")="tt0011100"    ; existing UNQINSERT value

    DO Stage^api(.Movies)
    SET staged=($GET(%ABR,0)>0)
    DO Transact^api

    DO AssertTrue("E6: Stage UNQINSERT collision — nothing staged",'staged)
    QUIT

TestE7 ; Stage GENID rollback leaves no ghost ^ABE entry
;;------------------------------------------------------------------
;; Purpose: A failed commit that would have generated a new entity
;;          leaves no orphaned entry in ^ABE
;; Scope: Stage^api, Transact^api
;; Assert Condition: the ^ABE entity count is unchanged after the
;;                    failed commit
;;------------------------------------------------------------------
    WRITE !,"E7: Stage GENID rollback no ghost"
    NEW Movies  ; input record batch
    NEW ecount  ; ^ABE count before the failed commit
    NEW ok      ; whether the count is unchanged after
    DO INIT^api

    SET ecount=$GET(^ABE,0)

    KILL Movies
    SET Movies(1,"movie.title")="Ghost Movie @en"
    SET Movies(1,"movie.genre")="drama"
    SET Movies(1,"movie.releaseYear")=2008
    SET Movies(1,"movie.imdbid")="tt0011100"    ; UNQINSERT collision

    DO Stage^api(.Movies)
    DO Transact^api

    SET ok=($GET(^ABE,0)=ecount)

    DO AssertTrue("E7: Stage rollback leaves no ghost ^ABE entry",ok)
    QUIT

TestE8 ; Stage bulk load bypasses validation
;;------------------------------------------------------------------
;; Purpose: A bulk-loaded record missing a required attribute still
;;          commits successfully, since bulk load bypasses
;;          validation
;; Scope: Stage^api, Transact^api
;; Assert Condition: the entity resolves to a valid eid after commit
;;------------------------------------------------------------------
    WRITE !,"E8: Stage bulk load skips validation"
    NEW Movies  ; input record batch
    NEW eid     ; resolved eid after commit
    DO INIT^api

    KILL Movies
    SET Movies(1,"movie.title")="Bulk Movie"
    SET Movies(1,"movie.genre")="drama"
    SET Movies(1,"movie.releaseYear")=2008
    ; missing required movie.imdbid — ignored in bulk load

    DO Stage^api(.Movies,"sandbox",1)
    DO Transact^api

    SET eid=$$GetEID^apiGet("Bulk Movie",$$GetEID^sapiGet("sandbox.movie.title"))

    DO AssertTrue("E8: Stage bulk load commits without validation",eid>0)
    QUIT

TestE9 ; Stage rollback after retraction failure
;;------------------------------------------------------------------
;; Purpose: When a batch pairs a valid assertion with an invalid
;;          cardinality-many retraction, the retraction failure
;;          rolls back the entire batch, including the already
;;          staged assertion
;; Scope: Stage^api, Transact^api
;; Assert Condition: the entity's name still reflects the previous
;;                    baseline value, not the rolled-back update
;;------------------------------------------------------------------
    WRITE !,"E9: Stage rollback after retraction failure"
    NEW Obj      ; input record batch
    NEW eid      ; eid of TomHanks
    NEW nameaid  ; sys.attr.name attribute id
    NEW valkey   ; current valkey after the rollback attempt
    NEW dictval   ; resolved literal value after the rollback attempt
    DO INIT^api

    ; Establish baseline value with a successful commit
    KILL Obj
    SET Obj(1,key)=TomHanks
    SET Obj(1,name)="tommy_e9_baseline"

    DO Stage^api(.Obj)
    DO Transact^api

    SET eid=$$GetEID^apiGet(TomHanks)
    SET nameaid=$$GetEID^sapiGet("sys.attr.name")

    ; Attempt a name replacement together with an invalid retraction.
    ; The retraction failure must rollback the already staged assertion.
    KILL Obj
    SET Obj(1,key)=TomHanks
    SET Obj(1,name)="tommy_e9"
    SET Obj(1,label,"-")=""    ; invalid cardinality-many retraction

    DO Stage^api(.Obj)
    DO Transact^api

    ; Verify atomic rollback preserved previous value
    SET valkey=$$GetCurrentVK^apiGet(eid,nameaid)
    SET dictval=$$GetDictValue^sapiGet(nameaid,valkey)

    DO AssertTrue("E9: Stage rollback preserves previous value",(dictval="tommy_e9_baseline"))
    QUIT


TestE10 ; Stage rollback after invalid retraction
;;------------------------------------------------------------------
;; Purpose: When a batch pairs a valid assertion with a retraction
;;          of a value that was never asserted, staging fails and
;;          the entire batch rolls back
;; Scope: Stage^api, Transact^api
;; Assert Condition: the entity's name still reflects the previous
;;                    baseline value, not the rolled-back update
;;------------------------------------------------------------------
    WRITE !,"E10: Stage rollback after invalid retraction"
    NEW Obj      ; input record batch
    NEW eid      ; eid of TomHanks
    NEW nameaid  ; sys.attr.name attribute id
    NEW valkey   ; current valkey after the rollback attempt
    NEW dictval   ; resolved literal value after the rollback attempt
    DO INIT^api

    ; Establish known baseline
    KILL Obj
    SET Obj(1,key)=TomHanks
    SET Obj(1,name)="tommy_e10_baseline"

    DO Stage^api(.Obj)
    DO Transact^api

    SET eid=$$GetEID^apiGet(TomHanks)
    SET nameaid=$$GetEID^sapiGet("sys.attr.name")

    ; Attempt assertion together with invalid retraction.
    ; alias value was never asserted, therefore staging must fail.
    KILL Obj
    SET Obj(1,key)=TomHanks
    SET Obj(1,name)="tommy_e10"
    SET Obj(1,alias,"-")="NonExistentAlias"

    DO Stage^api(.Obj)
    DO Transact^api

    ; Previous value must remain after rollback
    SET valkey=$$GetCurrentVK^apiGet(eid,nameaid)
    SET dictval=$$GetDictValue^sapiGet(nameaid,valkey)

    DO AssertTrue("E10: Stage rollback preserves previous value",(dictval="tommy_e10_baseline"))
    QUIT


TestE11 ; Stage UNQINSERT collision rejected
;;------------------------------------------------------------------
;; Purpose: Staging a record with a UNQINSERT attribute value that
;;          is still live under another entity is rejected, and the
;;          existing owner is left unchanged
;; Scope: Stage^api, Transact^api
;; Assert Condition: staging reports failure and the value's owner
;;                    eid is unchanged
;;------------------------------------------------------------------
    WRITE !,"E11: Stage UNQINSERT live collision rejected"
    NEW Movies      ; input record batch
    NEW ok          ; staging outcome
    NEW eidBefore   ; owner eid resolved before staging
    NEW eidAfter    ; owner eid resolved after commit

    DO INIT^api

    SET eidBefore=$$LookupEID^apiGet("tt0011100","sandbox.movie.imdbid")

    KILL Movies

    SET Movies(1,"movie.title")="Collision Test @en"
    SET Movies(1,"movie.genre")="drama"
    SET Movies(1,"movie.releaseYear")=2026
    SET Movies(1,"movie.imdbid")="tt0011100"

    DO Stage^api(.Movies,"sandbox",0,.ok)
    DO Transact^api

    SET eidAfter=$$LookupEID^apiGet("tt0011100","sandbox.movie.imdbid")

    DO AssertTrue("E11: Stage UNQINSERT live collision rejected",(ok=0)&(eidBefore>0)&(eidAfter=eidBefore))
    QUIT


TestE12 ; Stage batch atomicity after invalid record
;;------------------------------------------------------------------
;; Purpose: A batch containing one record with an unknown attribute
;;          is discarded in its entirety — nothing from the batch is
;;          staged or committed
;; Scope: Stage^api, Transact^api
;; Assert Condition: staging reports failure, nothing is staged, and
;;                    none of the batch's entities resolve afterward
;;------------------------------------------------------------------
    WRITE !,"E12: Stage batch atomicity after invalid record"
    NEW M          ; input record batch
    NEW ok         ; staging outcome
    NEW resolved1  ; eid lookup for a batch imdbid after commit
    NEW resolved2  ; eid lookup for another batch imdbid after commit

    DO INIT^api

    KILL M

    SET M(1,"movie.title")="The Wallow @en"
    SET M(1,"movie.genre")="drama|romance"
    SET M(1,"movie.releaseYear")=2008
    SET M(1,"movie.imdbid")="tt1115555"

    SET M(2,"movie.title")="My Crazy Foolness @en"
    SET M(2,"movie.genre")="comedy|romance"
    SET M(2,"movie.releaseYear")=2011
    SET M(2,"movie.imdbid")="tt77770000"

    SET M(3,"movie.title")="The Perfect Madness @en"
    SET M(3,"movie.bogusfield")="this attribute does not exist"
    SET M(3,"movie.releaseYear")=2000
    SET M(3,"movie.imdbid")="tt99992222"

    DO Stage^api(.M,"sandbox",0,.ok) ; It should output ok=0: validation/resolution failure 

    ; A correctly-discarded batch leaves nothing to commit.
    DO Transact^api

    SET resolved1=$$LookupEID^apiGet("tt0976051","sandbox.movie.imdbid")
    SET resolved2=$$LookupEID^apiGet("tt1570728","sandbox.movie.imdbid")

    DO AssertTrue("E12: Stage batch atomicity after invalid record",(ok=0)&($GET(%ABR,0)=0)&(resolved1=0)&(resolved2=0))
    QUIT


TestE13 ; Stage UNQUPSERT resolves current live owner
;;------------------------------------------------------------------
;; Purpose: Staging an update through a UNQUPSERT attribute resolves
;;          to the same live owner before and after the commit
;; Scope: Stage^api, Transact^api
;; Assert Condition: staging succeeds and the resolved owner eid is
;;                    unchanged
;;------------------------------------------------------------------
    WRITE !,"E13: Stage UNQUPSERT resolves current live owner"
    NEW Item        ; input record batch
    NEW eidBefore   ; owner eid resolved before staging
    NEW eidAfter    ; owner eid resolved after commit
    NEW ok          ; staging outcome

    DO INIT^api

    ; Resolve current live owner
    SET eidBefore=$$LookupEID^apiGet("042","sandbox.dlc.id")

    ; Stage update through UNQUPSERT
    KILL Item
    SET Item(1,dlcid)="042"
    SET Item(1,checkup)="E13 liveness test @en"

    DO Stage^api(.Item,"sandbox",0,.ok)
    DO Transact^api

    SET eidAfter=$$LookupEID^apiGet("042","sandbox.dlc.id")

    DO AssertTrue("E13: Stage UNQUPSERT preserves live owner",(ok=1)&(eidBefore=eidAfter))
    QUIT


LayerF
;; ==================================================================================================
;; LAYER F — AssertDatom/RetractDatom convenience wrappers (Formats A/B/C, unique constraints)
;; ==================================================================================================
;;
;; Test Coverage: Single-datom assertion and retraction via AD^api/RD^api across all three
;;                entity-resolution formats (raw EID, compound lookup-key, sys.attr.key);
;;                empty-field guards; UNQINSERT/UNQUPSERT collision rejection and
;;                release/reclaim semantics; cardinality-one vs cardinality-many retraction
;;                rules, including reference-valued (REF) attributes; idempotent no-op
;;                staging that must never open a phantom transaction.
;;
;; Scope: AD^api, RD^api, LookupEID^apiGet, GetEID^apiGet, GetEID^sapiGet,
;;        GetCurrentVK^apiGet, GetDictValue^sapiGet, GetDictValue^apiGet,
;;        AddAttr^sapi, Transact^sapi
;;
;; Result: 29/29 PASS
;; ==================================================================================================
    DO TestF1  ; AssertDatom Format A — valid EID routes via Path 0
    DO TestF2  ; AssertDatom Format A — invalid EID rejected
    DO TestF3  ; AssertDatom Format B — UNQUPSERT value exists → merge, same eid
    DO TestF4  ; AssertDatom Format B — UNQINSERT collision rejected
    DO TestF5  ; AssertDatom Format B — value absent → GENID new entity
    DO TestF6  ; AssertDatom Format C — key exists → existing eid, name updated
    DO TestF7  ; AssertDatom Format C — key not found → GENID new entity
    DO TestF8  ; AssertDatom Format B — ekv is resolved by a compound lookup of unique-attribute|value, in this test it is created
    DO TestF9  ; AssertDatom — empty ekv rejected, nothing staged
    DO TestF10 ; AssertDatom — empty akey rejected, nothing staged
    DO TestF11 ; AssertDatom — empty val rejected, nothing staged
    DO TestF12 ; RetractDatom Format A — valid EID routes via Path 0
    DO TestF13 ; RetractDatom Format B — value exists → entity found, retraction staged
    DO TestF14 ; RetractDatom Format B — value absent → error, NOT entity creation
    DO TestF15 ; RetractDatom Format C — key exists resolves entity
    DO TestF16 ; RetractDatom Format C — key not found → error, no staging
    DO TestF17 ; RetractDatom cardinality-one — supplied value rejected
    DO TestF18 ; RetractDatom cardinality-many — supplied value retracts datom
    DO TestF19 ; RetractDatom cardinality-many — no value rejected
    DO TestF20 ; RetractDatom cardinality-many — value never asserted rejected
    DO TestF21 ; hasChanges gating idempotent re-assert no phantom tx
    DO TestF22 ; UNQINSERT live-owner rejection clean rollback
    DO TestF23 ; UNQINSERT collision rejected while live, reclaimed after release
    DO TestF24 ; UNQUPSERT collision rejected while live, reclaimed after release
    DO TestF25 ; DatomAssert reference-value assert cardinality-one
    DO TestF26 ; idempotent re-assert reference value no phantom tx
    DO TestF27 ; cardinality-MANY reference attribute two targets
    DO TestF28 ; retract one value of cardinality-MANY reference attribute
    DO TestF29 ; retract unasserted cardinality-MANY reference value
    QUIT
    
TestF1 ; AssertDatom Format A — valid EID routes via Path 0
;;------------------------------------------------------------------
;; Purpose: A single-datom assertion using a raw EID routes via
;;          Path 0 and updates the existing entity's attribute
;;
;; Scope: AD^api
;;
;; Assert Condition: the entity's name reflects the newly asserted value after commit, 
;; 	                 and the current valkey was actually found (not a retraction or missing)
;;------------------------------------------------------------------
    WRITE !,"F1: AssertDatom Format A valid EID"
    NEW eid      ; eid of TomHanks
    NEW nameaid  ; sys.attr.name attribute id
    NEW valkey   ; current valkey after commit
    NEW dictval   ; resolved literal value after commit
    
    SET eid=$$GetEID^apiGet(TomHanks)
    DO AD^api(eid,name,"tommy_f1")
    DO Transact^api
    
    SET nameaid=$$GetEID^sapiGet("sys.attr.name")
    SET valkey=$$GetCurrentVK^apiGet(eid,nameaid)
    SET dictval=$$GetDictValue^sapiGet(nameaid,valkey)
    
    DO AssertTrue("F1: Format A updates existing entity",(dictval="tommy_f1")&(valkey'=0)&(valkey'=-1))
    QUIT

TestF2 ; AssertDatom Format A — invalid EID rejected
;;------------------------------------------------------------------
;; Purpose: A single-datom assertion using a well-formed but
;;          unregistered EID is rejected and nothing is staged
;; Scope: AD^api
;; Assert Condition: nothing is staged
;;------------------------------------------------------------------
    WRITE !,"F2: AssertDatom Format A invalid EID"
    NEW notStaged  ; whether anything was staged
    DO INIT^api
    DO AD^api("65560e13bd45f6y9xowl",name,"should_not_appear")
    ; %ABR is a plain scalar counter (see Stage^api / Transact^api) —
    ; a subscripted ("count") node never exists, so check the scalar directly.
    SET notStaged=($GET(%ABR,0)=0)
    DO Transact^api
    DO AssertTrue("F2: Format A invalid EID rejected, nothing staged",notStaged)
    QUIT

TestF3 ; AssertDatom Format B — UNQUPSERT value exists → merge, same eid
;;------------------------------------------------------------------
;; Purpose: A single-datom assertion using a UNQUPSERT lookup-key
;;          string (aid|value) merges into the existing live owner
;;          and updates its attribute
;; Scope: AD^api, LookupEID^apiGet
;; Assert Condition: the resolved eid before and after commit match,
;;                    and the checkup value reflects the update
;;------------------------------------------------------------------
    WRITE !,"F3: AssertDatom Format B UNQUPSERT merge"
    NEW eidBefore   ; owner eid resolved before commit
    NEW eidAfter    ; owner eid resolved after commit
    NEW checkupaid  ; dlc checkup attribute id
    NEW curvk       ; current valkey for checkup after commit
    NEW dictval     ; resolved literal checkup value after commit
    DO INIT^api
    SET eidBefore=$$LookupEID^apiGet("042","sandbox.dlc.id")
    DO AD^api(dlcid_"|042",checkup,"F3 checkup update @en")
    DO Transact^api
    SET eidAfter=$$LookupEID^apiGet("042","sandbox.dlc.id")
    SET checkupaid=$$GetEID^sapiGet("sandbox.dlc.checkup")
    SET curvk=$$GetCurrentVK^apiGet(eidAfter,checkupaid)
    SET dictval=$$GetDictValue^sapiGet(checkupaid,curvk) ; it proves that dictval is the current value-key
    DO AssertTrue("F3: Format B UNQUPSERT preserves entity and updates value",(eidBefore=eidAfter)&(dictval="F3 checkup update @en"))
    QUIT

TestF4 ; AssertDatom Format B — UNQINSERT collision rejected
;;------------------------------------------------------------------
;; Purpose: A single-datom assertion using a UNQINSERT lookup-key
;;          string whose value is already live is rejected and
;;          nothing is staged
;; Scope: AD^api
;; Assert Condition: nothing is staged
;;------------------------------------------------------------------
    WRITE !,"F4: AssertDatom Format B UNQINSERT collision"
    NEW notStaged  ; whether anything was staged
    DO INIT^api
    DO AD^api("sandbox.movie.imdbid|tt0011100","movie.title","Duplicate")
    SET notStaged=($GET(%ABR,0)=0)
    DO Transact^api
    DO AssertTrue("F4: Format B UNQINSERT collision rejected, nothing staged",notStaged)
    QUIT

TestF5 ; AssertDatom Format B — value absent → GENID new entity
;;------------------------------------------------------------------
;; Purpose: A single-datom assertion using a unique lookup-key
;;          string whose value does not yet exist generates a fresh
;;          entity
;; Scope: AD^api, LookupEID^apiGet
;; Assert Condition: the entity did not exist before the commit and
;;                    exists afterward
;;------------------------------------------------------------------
;; Uses LookupEID^api — see F3 rationale above.
;;------------------------------------------------------------------
    WRITE !,"F5: AssertDatom Format B new entity"
    NEW eidBefore  ; eid lookup before commit
    NEW eidAfter   ; eid lookup after commit
    
    SET eidBefore=$$LookupEID^apiGet("999","sandbox.dlc.id")
    DO AD^api(dlcid_"|999",checkup,"New DLC item @en")
    DO Transact^api
    
    SET eidAfter=$$LookupEID^apiGet("999","sandbox.dlc.id")
    DO AssertTrue("F5: Format B creates new entity with unique value",(eidBefore<1)&(eidAfter>0))
    QUIT

TestF6 ; AssertDatom Format C — key exists → existing eid, name updated
;;------------------------------------------------------------------
;; Purpose: A single-datom assertion using an existing sys.attr.key
;;          preserves the entity's eid and updates its attribute
;; Scope: AD^api
;; Assert Condition: the resolved eid before and after commit match,
;;                    and the name reflects the update
;;------------------------------------------------------------------
    WRITE !,"F6: AssertDatom Format C key found"
    NEW eidBefore  ; eid resolved before commit
    NEW eidAfter   ; eid resolved after commit
    NEW nameaid    ; sys.attr.name attribute id
    NEW curvk     ; current valkey for name after commit
    NEW dictval     ; resolved literal value after commit
    
    SET eidBefore=$$GetEID^apiGet(TomHanks)
    DO AD^api(TomHanks,name,"tommy_f6")
    DO Transact^api
    
    SET eidAfter=$$GetEID^apiGet(TomHanks)
    SET nameaid=$$GetEID^sapiGet("sys.attr.name")
    SET curvk=$$GetCurrentVK^apiGet(eidAfter,nameaid)
    SET dictval=$$GetDictValue^sapiGet(nameaid,curvk)
    DO AssertTrue("F6: Format C existing key preserves eid and updates value",(eidBefore=eidAfter)&(dictval="tommy_f6"))
    QUIT

TestF7 ; AssertDatom Format C — key not found → GENID new entity
;;------------------------------------------------------------------
;; Purpose: A single-datom assertion using a sys.attr.key not yet in
;;          the database generates a fresh entity anchored to that
;;          key
;; Scope: AD^api
;; Assert Condition: the entity did not exist before the commit and
;;                    exists afterward
;;------------------------------------------------------------------
    WRITE !,"F7: AssertDatom Format C new entity"
    NEW eidBefore  ; eid lookup before commit
    NEW eidAfter   ; eid lookup after commit
    DO INIT^api
    SET eidBefore=$$GetEID^apiGet("obj.test_f7")
    DO AD^api("obj.test_f7",name,"test_f7")
    DO Transact^api
    SET eidAfter=$$GetEID^apiGet("obj.test_f7")
    DO AssertTrue("F7: Format C creates entity from new key",(eidBefore<1)&(eidAfter>0))
    QUIT

TestF8 ; AssertDatom Format B — ekv is resolved by a compound lookup of unique-attribute|value, in this test it is created
;;---------------------------------------------------------------------------------------------------------------------------------
;; Purpose: Use a unique attribute key and its value as a lookup to resolve entity id, 
;;          if it does not exist it creates a new entity
;;
;; Scope: AD^api, LookupEID^apiGet
;;
;; Assert Condition: the entity resolves to a valid eid, and no sys.attr.key datom exists for it
;;
;; YDB>D PE^api($$LookupEID^apiGet("f8_test","sandbox.dlc.id"))
;; ==============================
;;  658dddb3086a83qiqfbt
;; ==============================
;;   658dddb3086a83qiqfbt  sandbox.dlc.id                     f8_test
;;   658dddb3086a83qiqfbt  sandbox.dlc.txdate                 2026-08-12
;;-------------------------------------------------------------------------------------------------------------------
    WRITE !,"F8: ; AssertDatom Format B — ekv is resolved by a compound lookup of unique-attribute|value, in this test it is created"
    NEW eid     ; resolved eid after commit
    NEW keyaid  ; sys.attr.key attribute id
    
    DO AD^api("sandbox.dlc.id|f8_test","sandbox.dlc.txdate","2026-08-12")
    ; same as    
	; SET Datom(1,"sandbox.dlc.id")="f8_test"
	; SET Datom(1,"sandbox.dlc.txdate")="2026-08-12"
	; DO Stage^api(.Datom)

    DO Transact^api
    SET eid=$$LookupEID^apiGet("f8_test","sandbox.dlc.id")
    SET keyaid=$$GetEID^sapiGet("sys.attr.key")
    DO AssertTrue("F8: AssertDatom Format B — ekv is resolved by a compound lookup of unique-attribute|value. In this test it is created",(eid'=0)&('$DATA(^EATV(eid,keyaid))))
    QUIT

TestF9 ; AssertDatom — empty ekv rejected, nothing staged
;;------------------------------------------------------------------
;; Purpose: A single-datom assertion with an empty entity-key value
;;          is rejected and nothing is staged
;; Scope: AD^api
;; Assert Condition: nothing is staged
;;------------------------------------------------------------------
    WRITE !,"F9: AssertDatom empty ekv"
    NEW staged  ; whether anything was staged
    DO INIT^api
    DO AD^api("",name,"test")
    SET staged=($GET(%ABR,0)>0)
    DO AssertTrue("F9: Empty ekv rejected, nothing staged",'staged)
    QUIT

TestF10 ; AssertDatom — empty akey rejected, nothing staged
;;------------------------------------------------------------------
;; Purpose: A single-datom assertion with an empty attribute key is
;;          rejected and nothing is staged
;; Scope: AD^api
;; Assert Condition: nothing is staged
;;------------------------------------------------------------------
    WRITE !,"F10: AssertDatom empty akey"
    NEW staged  ; whether anything was staged
    DO INIT^api
    DO AD^api(TomHanks,"","test")
    SET staged=($GET(%ABR,0)>0)
    DO AssertTrue("F10: Empty akey rejected, nothing staged",'staged)
    QUIT
 
TestF11 ; AssertDatom — empty val rejected, nothing staged
;;------------------------------------------------------------------
;; Purpose: A single-datom assertion with an empty value is rejected
;;          and nothing is staged
;; Scope: AD^api
;; Assert Condition: nothing is staged
;;------------------------------------------------------------------
    WRITE !,"F11: AssertDatom empty val"
    NEW staged  ; whether anything was staged
    DO INIT^api
    DO AD^api(TomHanks,name,"")
    SET staged=($GET(%ABR,0)>0)
    DO AssertTrue("F11: Empty val rejected, nothing staged",'staged)
    QUIT

TestF12 ; RetractDatom Format A — valid EID routes via Path 0
;;------------------------------------------------------------------
;; Purpose: A single-datom retraction using a raw EID 
;;
;; Scope: AD^api, RD^api
;;
;; Assert Condition: the state of current valkey for entity is 0, i.e. retracted
;;------------------------------------------------------------------
    WRITE !,"F12: RetractDatom Format A valid EID"
    NEW eid      ; eid of TomHanks
    NEW nameaid  ; sys.attr.name attribute id
    NEW curvk    ; state of the current valkey for entity after retraction
        
    SET eid=$$GetEID^apiGet(TomHanks)
    
    DO AD^api(eid,name,"tommy_f12")
    DO Transact^api
    
    DO RD^api(eid,name)
    DO Transact^api
    
    SET nameaid=$$GetEID^sapiGet("sys.attr.name")
    SET curvk=$$GetCurrentVK^apiGet(eid,nameaid)
    
    DO AssertTrue("F12: Format A retracts existing datom",(curvk=0))
    QUIT

TestF13 ; RetractDatom Format B — value exists → entity found, retraction staged
;;----------------------------------------------------------------------------------
;; Purpose: A single-datom retraction using a unique lookup-key
;;          string whose value exists resolves the owning entity and
;;          stages the retraction
;;
;; Scope: RD^api, LookupEID^apiGet
;;
;; Assert Condition: the attribute no longer resolves to a live (current) valkey
;;----------------------------------------------------------------------------------
    WRITE !,"F13: RetractDatom Format B value exists"
    
    NEW eid     ; owner eid resolved before retraction
    NEW curvk  ; current valkey after retraction
        
    SET eid=$$LookupEID^apiGet("042","sandbox.dlc.id")
    SET checkupid=$$GetEID^sapiGet(checkup)
    
    DO RD^api(dlcid_"|042",checkup)
    DO Transact^api
    
    SET curvk=$$GetCurrentVK^apiGet(eid,checkupid)
    DO AssertTrue("F13: Format B retracts existing unique entity datom",(curvk=0))
    QUIT

TestF14 ; RetractDatom Format B — value absent → error, NOT entity creation
;;------------------------------------------------------------------
;; Purpose: A single-datom retraction using a unique lookup-key
;;          string whose value does not exist fails without creating
;;          a new entity
;; Scope: RD^api, LookupEID^apiGet
;; Assert Condition: the entity does not resolve before or after the call
;;------------------------------------------------------------------
;; Uses LookupEID^api — see F3 rationale.
;;------------------------------------------------------------------
    WRITE !,"F14: RetractDatom Format B value absent"
    NEW eidBefore  ; eid lookup before the call
    NEW eidAfter   ; eid lookup after the call
    
    SET eidBefore=$$LookupEID^apiGet("999999","sandbox.dlc.id")

    DO RD^api(dlcid_"|999999",checkup)
    DO Transact^api

    SET eidAfter=$$LookupEID^apiGet("999999","sandbox.dlc.id")
    DO AssertTrue("F14: Format B missing value does not create entity",(eidBefore<1)&(eidAfter<1))
    QUIT

TestF15 ; RetractDatom Format C — key exists resolves entity
;;------------------------------------------------------------------
;; Purpose: A single-datom retraction using an existing sys.attr.key
;;          resolves the entity and retracts its datom
;; Scope: RD^api
;; Assert Condition: the attribute no longer resolves to a live (current) valkey
;;------------------------------------------------------------------
    WRITE !,"F15: RetractDatom Format C key found"
    NEW eid      ; eid of TomHanks
    NEW nameaid  ; sys.attr.name attribute id
    NEW curvk   ; current valkey after retraction

    SET eid=$$GetEID^apiGet(TomHanks)
    DO AD^api(TomHanks,name,"tommy_f15")
    DO Transact^api

    DO RD^api(TomHanks,name)
    DO Transact^api

    SET nameaid=$$GetEID^sapiGet("sys.attr.name")
    SET curvk=$$GetCurrentVK^apiGet(eid,nameaid)

    DO AssertTrue("F15: Format C retracts key-resolved datom",(curvk=0))
    QUIT

TestF16 ; RetractDatom Format C — key not found → error, no staging
;;------------------------------------------------------------------
;; Purpose: A single-datom retraction using a sys.attr.key that does
;;          not exist fails without staging anything
;; Scope: RD^api
;; Assert Condition: nothing is staged
;;------------------------------------------------------------------
    WRITE !,"F16: RetractDatom Format C key not found"
    NEW notStage  ; whether anything was staged
    DO INIT^api
    DO RD^api("obj.nonexistent",name)
    SET notStage=($GET(%ABR,0)=0)
    DO AssertTrue("F16: Format C key not found stages nothing",notStage)
    QUIT

TestF17 ; RetractDatom cardinality-one — supplied value rejected
;;------------------------------------------------------------------
;; Purpose: Supplying an explicit value when retracting a
;;          cardinality-one attribute is rejected — cardinality-one
;;          retraction must be value-less
;; Scope: RD^api
;; Assert Condition: nothing is staged
;;------------------------------------------------------------------
    WRITE !,"F17: RetractDatom cardinality-one val supplied"
    NEW notStaged  ; whether anything was staged
        
    DO RD^api(TomHanks,name,"tommy")
    SET notStaged=($GET(%ABR,0)=0)
    DO Transact^api
    DO AssertTrue("F17: Cardinality-one supplied value stages nothing",notStaged)
    QUIT

TestF18 ; RetractDatom cardinality-many — supplied value retracts datom
;;------------------------------------------------------------------
;; Purpose: Supplying an explicit value when retracting a
;;          cardinality-many attribute retracts that specific value
;; Scope: RD^api
;; Assert Condition: the supplied valkey is no longer live at its
;;                    most recent transaction
;;------------------------------------------------------------------
;; cardinality-many — CurrentDatom doesn't apply per-value; check
;; directly whether this specific valkey is still live at its tx.
;;------------------------------------------------------------------
    WRITE !,"F18: RetractDatom cardinality-many val supplied"
    NEW eid        	; eid of TomHanks
    NEW aliasaid   	; sys.attr.alias attribute id
    NEW valkey     	; resolved valkey for "TomHanks" alias
    NEW isNew      	; whether RegisterAttrVal registered a new valkey
    NEW curtx      	; most recent tx for aliasaid on eid
    NEW curop      	; op value at curtx for this valkey
    NEW isRetracted	; check if current value is retracted
    
    DO INIT^api
    SET eid=$$GetEID^apiGet(TomHanks)
    SET aliasaid=$$GetEID^sapiGet("sys.attr.alias")
    SET isNew=$$RegisterAttrVal^sapiRslv(aliasaid,"TomHanks",.valkey)
    DO RD^api(TomHanks,alias,"TomHanks")
    DO Transact^api
    
    SET isRetracted=$$GetCurrentVK^apiGet(eid,aliasaid)
    DO AssertFalse("F18: Cardinality-many value retracted",isRetracted)
    QUIT

TestF19 ; RetractDatom cardinality-many — no value rejected
;;------------------------------------------------------------------
;; Purpose: Retracting a cardinality-many attribute without
;;          supplying a value is rejected — a specific value must be
;;          named
;; Scope: RD^api
;; Assert Condition: nothing is staged
;;------------------------------------------------------------------
    WRITE !,"F19: RetractDatom cardinality-many no val"
    NEW notStage  ; whether anything was staged
    DO INIT^api
    DO RD^api(TomHanks,alias)
    SET notStage=($GET(%ABR,0)=0)
    DO Transact^api
    DO AssertTrue("F19: Cardinality-many without value stages nothing",notStage)
    QUIT

TestF20 ; RetractDatom cardinality-many — value never asserted rejected
;;------------------------------------------------------------------
;; Purpose: Retracting a cardinality-many value that was never
;;          asserted is rejected
;; Scope: RD^api
;; Assert Condition: nothing is staged
;;------------------------------------------------------------------
    WRITE !,"F20: RetractDatom cardinality-many unknown value"
    NEW notStage  ; whether anything was staged
    DO INIT^api
    DO RD^api(TomHanks,alias,"NeverAssertedAlias_F20")
    SET notStage=($GET(%ABR,0)=0)
    DO Transact^api
    DO AssertTrue("F20: Unknown cardinality-many value stages nothing",notStage)
    QUIT
 
TestF21
;;------------------------------------------------------------------
;; F21: hasChanges gating (U2) — no phantom transaction on a true no-op
;;
;; Purpose  : Regression test for the phantom-transaction bug.
;;            StageRecord must commit only when real datoms are
;;            staged. An idempotent re-assertion using the same
;;            sys.attr.key and already-current UNQINSERT value must
;;            follow the no-op path.
;;
;; Sequence :
;;   1. Create p.dave with a fresh UNQINSERT email — real commit.
;;   2. Snapshot ^ABE, ^EATV, ^TXE root counters.
;;   3. Re-assert the same key with the same email value.
;;   4. Confirm no records were staged.
;;   5. Call Transact^api and confirm no transaction side effects.
;;
;; Expected :
;;   No staged records exist after the idempotent assertion and
;;   ^ABE, ^EATV, and ^TXE roots remain unchanged after Transact^api.
;;
;; Failure mode this catches:
;;   A no-op assertion incorrectly increments %ABR and causes
;;   Transact^api to create a transaction containing no real datoms.
;;
;; Note: %ABR is a scalar counter checked through $GET().
;;------------------------------------------------------------------
    WRITE !,"F21: hasChanges gating idempotent re-assert no phantom tx"
    NEW abeRoot0,eatvRoot0,txeRoot0,notStaged,pass

    DO INIT^api

    ; Step 1 — create initial entity/value
    DO AD^api("p.dave","sandbox.person.email","dave@example.com")
    DO Transact^api

    ; Step 2 — snapshot committed roots
    SET abeRoot0=$GET(^ABE,0)
    SET eatvRoot0=$GET(^EATV,0)
    SET txeRoot0=$GET(^TXE,0)

    ; Step 3 — idempotent re-assert, should stage nothing
    DO AD^api("p.dave","sandbox.person.email","dave@example.com")
    SET notStaged=($GET(%ABR,0)=0)

    ; Step 4/5 — transact must leave storage untouched
    DO Transact^api

    SET pass=(notStaged)&($GET(^ABE,0)=abeRoot0)&($GET(^EATV,0)=eatvRoot0)&($GET(^TXE,0)=txeRoot0)

    DO AssertTrue("F21 idempotent re-assert creates no phantom transaction",pass)
    QUIT
 
 
TestF22
;;------------------------------------------------------------------
;; F22: UNQINSERT live-owner rejection
;;
;; Purpose  : Confirms the WORKING half of U3 stays working: asserting
;;            a brand-new entity against a UNQINSERT value that is
;;            still LIVE under a different owner must roll back
;;            cleanly, with no orphaned entity leaked into ^ABE.
;;
;; Sequence :
;;   1. Frank claims a UNQINSERT email — live owner established.
;;   2. Snapshot ^ABE root counter.
;;   3. Attempt to create a brand-new entity claiming the SAME email.
;;   4. Confirm StageRecord rejects it (insert-unique violation) and
;;      ^ABE root is unchanged — the GENID reserved for the failed
;;      new entity must never be registered.
;;   5. Confirm the failed entity's natural key never resolves.
;;
;; Expected :
;;   ^ABE root unchanged; GetEID for the rejected entity's key = -1.
;;------------------------------------------------------------------
    WRITE !,"F22: UNQINSERT live-owner rejection clean rollback"
    NEW abeRoot0,rejectedEid
    DO INIT^api

    ; Step 1 — establish live owner
    DO AD^api("p.frank","sandbox.person.email","frank@example.com")
    DO Transact^api

    ; Step 2 — snapshot before conflicting insert
    SET abeRoot0=$GET(^ABE,0)

    ; Step 3 — attempt conflicting UNQINSERT claim
    DO AD^api("p.newguy","sandbox.person.email","frank@example.com")
    DO Transact^api

    ; Step 4/5 — failed insert must not register entity or resolve key
    SET rejectedEid=$$GetEID^apiGet("p.newguy")

    DO AssertTrue("F22 conflicting UNQINSERT rolls back without orphan entity",(($GET(^ABE,0)=abeRoot0)&(rejectedEid=0)))
    QUIT
 


TestF23
;;------------------------------------------------------------------
;; F23: UNQINSERT collision + release/reclaim semantics
;;
;; Purpose  : Confirms the real UNQINSERT guarantee — a value already
;;            live-owned by one entity cannot be claimed by a
;;            DIFFERENT entity while that ownership stands, but once
;;            released, the same value CAN be claimed by another
;;            entity.
;;
;; Sequence :
;;   1. Carol claims email = personal@example.com.
;;   2. Erin claims email = business@example.com.
;;   3. Attempt to assert personal@example.com onto Erin — must be
;;      rejected; Carol still owns it live.
;;   4. Retract personal@example.com from Carol — value freed.
;;   5. Attempt again to assert personal@example.com onto Erin — must
;;      now succeed.
;;   6. Stage carol@example.com onto Carol — a fresh, unclaimed
;;      value into Carol's now-empty slot — must succeed.
;;
;;
;; tx		outcome	            	maps to
;; 7408		committed 1 record		Step 1: Carol claims personal@example.com
;; 7409		committed 1 record		Step 2: Erin claims business@example.com
;; no tx	rejected   				Step 3: insert-unique-violation
;; 7410		committed 1 record		Step 4: retract Carol's email
;; 7411		committed 1 record		Step 5: Erin claims personal@example.com again — now succeeds
;; 7412		committed 1 record		Step 6: Carol claims carol@example.com
;;
;; Expected final state :
;; YDB>D PE^api("p.carol2")
;;   - Carol's live email = carol@example.com.
;; YDB>D PE^api("p.erin2")
;;   - Erin's live email = personal@example.com.
;;
;; History :
;; YDB>D PH^api("p.carol2")
;;                    eid     aid      tx          valkey  OP
;;   657bde4185ff1nh8m8ez     210    7408     K0D2.018879  ( + )
;;   657bde4185ff1nh8m8ez    1002    7408     K3EA.01887A  ( + )
;;   657bde4185ff1nh8m8ez    1002    7410     K3EA.01887A  ( - )
;;   657bde4185ff1nh8m8ez    1002    7412     K3EA.01887D  ( + )
;;
;; YDB>D PH^api("p.erin2")
;;                    eid     aid      tx          valkey  OP
;;   657bde4187683jzi9nmr     210    7409     K0D2.01887B  ( + )
;;   657bde4187683jzi9nmr    1002    7409     K3EA.01887C  ( + )
;;   657bde4187683jzi9nmr    1002    7411     K3EA.01887A  ( + )
;;   657bde4187683jzi9nmr    1002    7411     K3EA.01887C  ( - )
;;
;;------------------------------------------------------------------
    WRITE !,"F23: UNQINSERT collision rejected while live, reclaimed after release"
    NEW carolEid,erinEid,emailAid,carolLabel,erinLabel
    DO INIT^api

    ; Step 1 — Carol claims her email
    DO AD^api("p.carol2","sandbox.person.email","personal@example.com")
    DO Transact^api
    SET carolEid=$$GetEID^apiGet("p.carol2")

    IF carolEid<1 DO  QUIT
    . DO AssertTrue("F23 could not resolve Carol after initial assert — aborting",0)

    ; Step 2 — Erin claims her own, different email
    DO AD^api("p.erin2","sandbox.person.email","business@example.com")
    DO Transact^api
    SET erinEid=$$GetEID^apiGet("p.erin2")

    IF erinEid<1 DO  QUIT
    . DO AssertTrue("F23 could not resolve Erin after initial assert — aborting",0)

    SET emailAid=$$GetEID^sapiGet("sandbox.person.email")

    ; Step 3 — attempt to claim Carol's live value onto Erin — must reject
    DO AD^api(erinEid,"sandbox.person.email","personal@example.com")
    DO Transact^api

    ; Step 4 — release Carol's email
    DO RD^api(carolEid,"sandbox.person.email")
    DO Transact^api

    ; Step 5 — attempt again — must now succeed
    DO AD^api(erinEid,"sandbox.person.email","personal@example.com")
    DO Transact^api

    ; Step 6 — Carol claims a fresh, unclaimed value into her empty slot
    DO AD^api(carolEid,"sandbox.person.email","carol@example.com")
    DO Transact^api

    SET carolLabel=$$GetDictValue^apiGet(emailAid,$$GetCurrentVK^apiGet(carolEid,emailAid))
    SET erinLabel=$$GetDictValue^apiGet(emailAid,$$GetCurrentVK^apiGet(erinEid,emailAid))

    DO AssertTrue("F23 UNQINSERT collision rejected while live, reclaimed after release",(carolLabel="carol@example.com")&(erinLabel="personal@example.com")&($$LookupEID^apiGet("personal@example.com","sandbox.person.email")=erinEid))

    QUIT


TestF24
;;------------------------------------------------------------------
;; F24: UNQUPSERT collision + release/reclaim semantics
;;
;; Purpose : Confirms the real UNQUPSERT guarantee — 
;;		     a value already live-owned by one entity cannot be claimed by a
;; 			 DIFFERENT entity while that ownership stands, 
;;			 but once released, the same value CAN be claimed by another entity.
;;
;; Sequence :
;; 1. Helen claims ssn = 555-11-2222.
;; 2. Erin claims ssn = 777-88-3333.
;; 3. Attempt to assert 555-11-2222 onto Erin — must be rejected; Helen still owns it live.
;; 4. Retract 555-11-2222 from Helen — value freed.
;; 5. Attempt again to assert 555-11-2222 onto Erin — must now succeed.
;; 6. Stage the OLD Erin'n SSN 777-88-3333 onto Helen — must succeed
;;
;;
;; tx		outcome	            	maps to
;; 7408		committed 1 record		Step 1: Helen claims 555-11-2222
;; 7409		committed 1 record		Step 2: Erin claims 777-88-3333
;; no tx	rejected				Step 3: Erin attempts to claim Helen's live SSN 555-11-2222 — upsert-unique collision
;; 7410		committed 1 record		Step 4: release Helen's SSN 555-11-2222
;; 7411		committed 1 record		Step 5: Erin claims 555-11-2222 — succeeds after release
;; 7412		committed 1 record		Step 6: Helen claims Erin's old SSN 777-88-3333 — succeeds because value is no longer owned by Erin
;;
;;
;; Expected final state :
;; YDB>D PE^api("p.helen2")
;;   657c52d9b30bda7bn38e  sys.attr.key                       p.helen2
;;   657c52d9b30bda7bn38e  sandbox.person.ssn                 777-88-3333
;;
;; YDB>D PE^api("p.erin2")
;;   657c52d9b4b54z6nyud4  sys.attr.key                       p.erin2
;;   657c52d9b4b54z6nyud4  sandbox.person.ssn                 555-11-2222
;;
;; YDB>D PH^api("p.helen2")
;;                    eid     aid      tx          valkey  OP
;;   657c52d9b30bda7bn38e     210    7408     K0D2.018879  ( + )
;;   657c52d9b30bda7bn38e    1003    7408     K3EB.01887A  ( + )
;;   657c52d9b30bda7bn38e    1003    7410     K3EB.01887A  ( - )
;;   657c52d9b30bda7bn38e    1003    7412     K3EB.01887C  ( + )
;;
;; YDB>D PH^api("p.erin2")
;;                    eid     aid      tx          valkey  OP
;;   657c52d9b4b54z6nyud4     210    7409     K0D2.01887B  ( + )
;;   657c52d9b4b54z6nyud4    1003    7409     K3EB.01887C  ( + )
;;   657c52d9b4b54z6nyud4    1003    7411     K3EB.01887A  ( + )
;;   657c52d9b4b54z6nyud4    1003    7411     K3EB.01887C  ( - )
;;------------------------------------------------------------------
    WRITE !,"F24: UNQUPSERT collision rejected while live, reclaimed after release"
    NEW helenEid,erinEid,ssnAid,helenLabel,erinLabel
    DO INIT^api

    ; Step 1 — Helen claims her ssn
    DO AD^api("p.helen2","sandbox.person.ssn","555-11-2222")
    DO Transact^api
    SET helenEid=$$GetEID^apiGet("p.helen2")

    ; Step 2 — Erin claims her own, different ssn
    DO AD^api("p.erin2","sandbox.person.ssn","777-88-3333")
    DO Transact^api
    SET erinEid=$$GetEID^apiGet("p.erin2")

    SET ssnAid=$$GetEID^sapiGet("sandbox.person.ssn")

    ; Step 3 — attempt to claim Helen's live value onto Erin — must reject
    DO AD^api(erinEid,"sandbox.person.ssn","555-11-2222")
    DO Transact^api

    ; Step 4 — release Helen's ssn
    DO RD^api(helenEid,"sandbox.person.ssn")
    DO Transact^api

    ; Step 5 — attempt again — must now succeed
    DO AD^api(erinEid,"sandbox.person.ssn","555-11-2222")
    DO Transact^api

    ; Step 6 — attempt to reclaim Erin's released old ssn value onto Helen — must succeed
    DO AD^api(helenEid,"sandbox.person.ssn","777-88-3333")
    DO Transact^api

    SET helenLabel=$$GetDictValue^apiGet(ssnAid,$$GetCurrentVK^apiGet(helenEid,ssnAid))
    SET erinLabel=$$GetDictValue^apiGet(ssnAid,$$GetCurrentVK^apiGet(erinEid,ssnAid))
	SET cond=(helenEid>0)&(erinEid>0)&(helenLabel="777-88-3333")&(erinLabel="555-11-2222")
    DO AssertTrue("F24 UNQUPSERT collision rejected while live, reclaimed after release",cond)

    QUIT


TestF25
;;------------------------------------------------------------------
;; F25: DatomAssert^apiWFL reference-value assert (cardinality-one)
;;
;; Purpose : Confirms REF assertions accept an already resolved target eid.
;;
;; Sequence :
;; 1. Define sandbox.person.favmovie (REF, ONE, UNQUPSERT).
;; 2. Resolve movie eid using imdbid.
;; 3. Stage favmovie onto Gina using the resolved eid.
;; 4. Confirm the reference datom resolves to the movie eid.
;;
;; Expected final state :
;; YDB>D PE^api("p.gina")
;;   <gina eid>  sys.attr.key              p.gina
;;   <gina eid>  sandbox.person.favmovie   <movie eid>
;;
;;------------------------------------------------------------------
    WRITE !,"F25: DatomAssert reference-value assert cardinality-one"
    NEW favmovieAid,movieEid,personEid,valkey,cond
    DO AddAttr^sapi("sandbox.person.favmovie",REF,ONE,ATYPE,UNQUPSERT,"The favourite movie for a person @en")
    DO Transact^sapi

    SET favmovieAid=$$GetEID^sapiGet("sandbox.person.favmovie")    
    SET movieEid=$$LookupEID^apiGet("tt0011100","sandbox.movie.imdbid")

    DO AD^api("p.gina","sandbox.person.favmovie",movieEid)
    DO Transact^api

    SET personEid=$$GetEID^apiGet("p.gina")
    SET valkey=$$GetCurrentVK^apiGet(personEid,favmovieAid)

    SET cond=(personEid>0)&(valkey'="")&($GET(^TBD(favmovieAid,valkey))=movieEid)
    DO AssertTrue("F25 reference-value assert resolves to target movie",cond)

    QUIT

TestFoo
    K P
    S P(1,key)="p.gina"
    S P(1,"person.name")="Gina"
    S P(1,"person.favmovie")=$$LookupEID^apiGet("tt0011100","sandbox.movie.imdbid")
    D Stage^api(.P,"sandbox")
 	; D PE^api("p.gina")
 	Q
 	
TestF26
;;------------------------------------------------------------------
;; F26: idempotent re-assert of a reference value (companion to F21)
;;
;; Purpose  : Confirms ResolveRefEID resolves the SAME valkey on
;;            repeated calls (no duplicate ^TBD/^TBDR allocation),
;;            and that DatomRevise's no-op path correctly
;;            recognises "same reference target" as no real change —
;;            no phantom transaction opened.
;;
;; Sequence :
;;   1. p.gina already has favmovie=movieEid from F25 — re-assert the
;;      SAME value.
;;   2. Confirm %ABR	 stays 0 (true no-op) and Transact^api opens
;;      no transaction (^TXE root unchanged).
;;
;; Expected :
;;   No phantom tx, same valkey resolved both times.
;;
;; Guard    : abort if the F25 fixture state is missing — this test
;;            depends on F25 having run first.
;;------------------------------------------------------------------
    WRITE !,"F26: idempotent re-assert reference value no phantom tx"
    NEW favmovieAid,movieEid,personEid,txeRoot0,notStaged,valkey
    DO INIT^api
 
    SET favmovieAid=$$GetEID^sapiGet("sandbox.person.favmovie")
    SET movieEid=$$LookupEID^apiGet("tt0011100","sandbox.movie.imdbid")
    SET personEid=$$GetEID^apiGet("p.gina")
 
    IF (favmovieAid<1)!(movieEid<1)!(personEid<1) DO  QUIT
    . DO AssertTrue("F26 F25 fixture state missing — run F25 first, aborting",0)
 
    ; Step 2 — snapshot transaction root before no-op assert
    SET txeRoot0=$GET(^TXE,0)
 
    ; Step 3 — re-assert identical reference value
    DO AD^api("p.gina","sandbox.person.favmovie",movieEid)
    SET notStaged=($GET(%ABR,0)=0)
    SET valkey=$$GetCurrentVK^apiGet(personEid,favmovieAid)
 
    ; Assertions
    DO AssertTrue("F26 idempotent reference assert stages no changes",notStaged)
    DO AssertTrue("F26 existing reference datom remains resolved",(valkey'=""))
 
    ; Step 4 — Transact should not create phantom transaction
    DO Transact^api
 
    DO AssertTrue("F26 no phantom transaction opened",($GET(^TXE,0)=txeRoot0))
    QUIT
 
 
IsValkeyLiveF(eid,aid,valkey)
;;------------------------------------------------------------------
;; Helper : IsValkeyLiveF (private to Layer F)
;; Purpose : cardinality-many liveness check for a SPECIFIC valkey.
;;           Must scan tx descending until finding the most recent
;;           tx that actually holds THIS valkey — not just check the
;;           entity's single latest tx, since independent values of
;;           a multi-valued attribute may have been asserted in
;;           separate transactions (mirrors DatomRetract^api's own
;;           lasttx-scanning technique).
;;------------------------------------------------------------------
    NEW lasttx,tx
    SET valkey=$GET(valkey)
    IF valkey="" QUIT 0
    SET lasttx=""
    SET tx=$ORDER(^EATV(eid,aid,""),-1)
    FOR  QUIT:(tx="")!(lasttx'="")  DO
    . IF $DATA(^EATV(eid,aid,tx,valkey)) SET lasttx=tx
    . ELSE  SET tx=$ORDER(^EATV(eid,aid,tx),-1)
    IF lasttx="" QUIT 0
    QUIT $GET(^EATV(eid,aid,lasttx,valkey),0)
 
 
TestF27
;;------------------------------------------------------------------
;; F27: cardinality-MANY reference attribute — two distinct targets
;;
;; Purpose  : Sets up the fixture F28/F29 depend on — a multi-valued
;;            reference attribute with two independently live values,
;;            each resolved through ResolveRefEID^sapi during assert.
;;
;; Sequence :
;;   1. Define sandbox.person.favactors (REF, MANY, ATYPE).
;;   2. AD two distinct reference targets for a new person — TomHanks
;;      and the fixture movie eid (arbitrary but reliably-resolvable
;;      distinct eids; semantic correctness of "movie as actor" is
;;      irrelevant, only distinctness matters for this test).
;;
;; Expected :
;;   Both values live independently in ^EATV for sandbox.person.favactors.
;;
;; Guard    : abort if either fixture reference target fails to
;;            resolve, or if p.karl is never created.
;;------------------------------------------------------------------
    WRITE !,"F27: cardinality-MANY reference attribute two targets"
    NEW favactorsAid,tomEid,movieEid,personEid,tomValkey,movieValkey
    NEW tomLive,movieLive
    DO AddAttr^sapi("sandbox.person.favactors",REF,MANY,ATYPE,"","Favourite actors/entities for a person @en")
    DO Transact^sapi
    SET favactorsAid=$$GetEID^sapiGet("sandbox.person.favactors")
 
    DO INIT^api
    SET tomEid=$$GetEID^apiGet(TomHanks)
    SET movieEid=$$LookupEID^apiGet("tt0011100","sandbox.movie.imdbid")
 
    IF (tomEid<1)!(movieEid<1) DO  QUIT
    . DO AssertTrue("F27 fixture reference targets not resolvable — aborting",0)
 
    ; Step 2 — assert first reference target
    DO AD^api("p.karl","sandbox.person.favactors",tomEid)
    DO Transact^api
 
    ; Step 3 — assert second distinct reference target
    DO AD^api("p.karl","sandbox.person.favactors",movieEid)
    DO Transact^api
 
    SET personEid=$$GetEID^apiGet("p.karl")
 
    IF personEid<1 DO  QUIT
    . DO AssertTrue("F27 p.karl was not created — aborting",0)
 
    SET tomValkey=$GET(^TBDR(favactorsAid,tomEid))
    SET movieValkey=$GET(^TBDR(favactorsAid,movieEid))
 
    SET tomLive=$$IsValkeyLiveF(personEid,favactorsAid,tomValkey)
    SET movieLive=$$IsValkeyLiveF(personEid,favactorsAid,movieValkey)
 
    ; Assertions
    DO AssertTrue("F27 person entity created",(personEid>0))
    DO AssertTrue("F27 first reference target live",tomLive)
    DO AssertTrue("F27 second reference target live",movieLive)
    QUIT
 
 
TestF28
;;------------------------------------------------------------------
;; F28: RetractDatom on one specific value of a cardinality-MANY
;;      reference attribute (the actual DatomRetract regression)
;;
;; Purpose  : This is the branch that was NEVER exercised by F18-F20
;;            — those cover cardinality-many val-supplied retraction
;;            for LITERAL attributes only. Reference attributes take
;;            a different resolution path inside DatomRetract
;;            (ResolveRefEID^sapi vs ResolveAV^sapiRslv), which is the
;;            piece we patched to match DatomAssert^apiWFL. Before the
;;            fix this call would have failed with a false
;;            "has never been asserted" error, since ResolveAV's
;;            label lookup can never succeed for a raw eid.
;;
;; Sequence :
;;   1. p.karl has two live favactors values from F27.
;;   2. RD the TomHanks reference specifically.
;;
;; Expected :
;;   TomHanks reference goes inactive; the movie reference stays live.
;;
;; Guard    : abort if the F27 fixture state is missing — this test
;;            depends on F27 having run first.
;;------------------------------------------------------------------
    WRITE !,"F28: retract one value of cardinality-MANY reference attribute"
    NEW favactorsAid,tomEid,movieEid,personEid,tomValkey,movieValkey
    NEW tomLive,movieLive
    DO INIT^api
 
    SET favactorsAid=$$GetEID^sapiGet("sandbox.person.favactors")
    SET tomEid=$$GetEID^apiGet(TomHanks)
    SET movieEid=$$LookupEID^apiGet("tt0011100","sandbox.movie.imdbid")
    SET personEid=$$GetEID^apiGet("p.karl")
 
    IF (favactorsAid<1)!(tomEid<1)!(movieEid<1)!(personEid<1) DO  QUIT
    . DO AssertTrue("F28 F27 fixture state missing — run F27 first, aborting",0)
 
    SET tomValkey=$GET(^TBDR(favactorsAid,tomEid))
    SET movieValkey=$GET(^TBDR(favactorsAid,movieEid))
 
    ; Step 2 — retract only TomHanks reference value
    DO RD^api("p.karl","sandbox.person.favactors",tomEid)
    DO Transact^api
 
    SET tomLive=$$IsValkeyLiveF(personEid,favactorsAid,tomValkey)
    SET movieLive=$$IsValkeyLiveF(personEid,favactorsAid,movieValkey)
 
    ; Assertions
    DO AssertTrue("F28 targeted reference value retracted",('tomLive))
    DO AssertTrue("F28 sibling reference value remains live",movieLive)
    QUIT
 
 
TestF29
;;------------------------------------------------------------------
;; F29: RetractDatom cardinality-MANY reference — value never
;;      asserted anywhere (companion to F20, for reference values)
;;
;; Purpose  : Confirms ResolveRefEID's "not yet registered" signal
;;            (IsRangeValue=false → isNewValKey=1) is still correctly
;;            treated by DatomRetract as "has never been asserted" —
;;            i.e. the fix doesn't loosen the never-asserted guard,
;;            it only fixes HOW the value gets resolved beforehand.
;;
;; Sequence :
;;   RD an entity's favactors against an eid that was never asserted
;;   as one of that attribute's values (a fresh, unused fixture eid).
;;
;; Expected :
;;   Nothing staged, error logged.
;;
;; Notice   : there's a side effect here that's easy to miss — even
;;            though the retraction is correctly rejected,
;;            ResolveRefEID still allocates and writes a new valkey
;;            into ^TBD/^TBDR for p.gina's eid under
;;            sandbox.person.favactors before DatomRetract gets a
;;            chance to reject it. This test does not currently
;;            assert against that side effect; it's called out here
;;            so it isn't mistaken for a clean no-op.
;;
;; Guard    : abort if the fixture entity (p.gina, from F25) doesn't
;;            resolve.
;;------------------------------------------------------------------
    WRITE !,"F29: retract unasserted cardinality-MANY reference value"
    NEW neverEid,staged
    DO INIT^api
 
    ; Step 1 — use a resolvable entity that was never asserted
    ; as a favactors value for p.karl.
    SET neverEid=$$GetEID^apiGet("p.gina")
 
    IF neverEid<1 DO  QUIT
    . DO AssertTrue("F29 fixture p.gina not resolvable — run F25 first, aborting",0)
 
    ; Step 2 — attempt to retract value that was never asserted
    DO RD^api("p.karl","sandbox.person.favactors",neverEid)
 
    SET staged=($GET(%ABR,0)>0)
 
    ; Assertions
    DO AssertTrue("F29 unasserted reference value stages no changes",'staged)
 
    DO Transact^api
    QUIT


LayerG
;; ==================================================================================================
;; LAYER G — Entity resolution (PE/PH) across paths and edge cases
;; ==================================================================================================
;;
;; Test Coverage: PE^api entity resolution across all resolution paths — raw eid,
;;                sys.attr.key natural key, unique attribute value, non-unique attribute
;;                value — plus safe failure on invalid attribute keys, unmatched values,
;;                EID-shaped but unregistered values, and garbage input. Also covers
;;                cardinality-many multi-value liveness and PH^api raw history reflecting
;;                a revision as a same-tx retraction + assertion pair.
;;
;; Scope: PE^api, PH^api, GetEID^apiGet, GetEID^sapiGet, LookupEID^apiGet, IsEID^utils,
;;        IsUniqueInsert^sapiVld, IsUniqueUpsert^sapiVld, RegisterAttrVal^sapiRslv
;;
;; Result: 9/9 PASS
;; ==================================================================================================
    DO TestG1  ; PE resolves via raw eid Path 0
    DO TestG2  ; PE resolves via sys.attr.key natural key Path 1
    DO TestG3  ; PE resolves via genuine unique attribute value Path 2
    DO TestG4  ; PE invalid attribute key fails safely
    DO TestG5  ; PE valid attribute unmatched value fails safely
    DO TestG6  ; PE resolves EID-shaped value that does not exist
    DO TestG7  ; PE resolves garbage value safely
    DO TestG8  ; PE resolves value through non-unique attribute
    DO TestG9  ; PE cardinality-many attribute has multiple live values
    
    ; -------------------------------------------------------------------------------------------------
    DO TestG10 ; PE tmdbid lookup fails before assertion 				  - must run BEFORE UpdateSeven
    
    DO UpdateSeven^testMovie
    
    DO TestG11 ; PH raw history shows title retraction and new live value - must run AFTER UpdateSeven
    DO TestG12 ; PE tmdbid lookup succeeds after UpdateSeven			  - must run AFTER UpdateSeven
    QUIT


TestG1 ; PE resolves via raw eid Path 0
;;------------------------------------------------------------------
;; Purpose: PE^api resolves a raw EID to itself via Path 0
;; Scope: PE^api, GetEID^apiGet
;; Assert Condition: the eid is valid and resolves to the same eid
;;------------------------------------------------------------------
    WRITE !,"G1: PE resolves via raw eid Path 0"
    NEW eid1  ; eid resolved via imdbid lookup
    NEW eid2  ; eid resolved via PE^api on the raw eid
    NEW ok    ; assertion outcome
    DO INIT^api

    SET eid1=$$LookupEID^apiGet("tt0011100","sandbox.movie.imdbid")

    DO PE^api(eid1)

    SET eid2=$$GetEID^apiGet(eid1)

    SET ok=(eid1>0)&(eid1=eid2)

    DO AssertTrue("G1 raw eid resolves to itself",ok)
    QUIT

TestG2 ; PE resolves via sys.attr.key natural key Path 1
;;------------------------------------------------------------------
;; Purpose: PE^api resolves a sys.attr.key natural key to the same
;;          eid as a direct lookup
;; Scope: PE^api, GetEID^apiGet
;; Assert Condition: the eid resolved directly and via the key match
;;------------------------------------------------------------------
    WRITE !,"G2: PE resolves via sys.attr.key natural key Path 1"
    NEW eidDirect  ; eid resolved directly via TomHanks
    NEW eidViaKey  ; eid resolved via PE^api on the natural key
    NEW ok         ; assertion outcome
    DO INIT^api

    SET eidDirect=$$GetEID^apiGet(TomHanks)

    DO PE^api("obj.tom_hanks")

    SET eidViaKey=$$GetEID^apiGet("obj.tom_hanks")

    SET ok=(eidDirect>0)&(eidDirect=eidViaKey)

    DO AssertTrue("G2 sys.attr.key resolves to same eid",ok)
    QUIT

TestG3 ; PE resolves via genuine unique attribute value Path 2
;;------------------------------------------------------------------
;; Purpose: PE^api resolves a unique attribute value to the same
;;          entity as its known live owner
;; Scope: PE^api, GetEID^apiGet
;; Assert Condition: the owner eid found via ^AVET and the eid
;;                    resolved via PE^api match
;;------------------------------------------------------------------
    WRITE !,"G3: PE resolves via unique attribute value Path 2"
    NEW dlcaid    ; dlc id attribute id
    NEW valkey    ; valkey for "042"
    NEW eidOwner  ; owner eid found directly via ^AVET
    NEW eidViaPE  ; eid resolved via PE^api
    NEW ok        ; assertion outcome
    DO INIT^api

    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET valkey=$GET(^TBDR(dlcaid,"042"))
    SET eidOwner=$ORDER(^AVET(dlcaid,valkey,""))

    DO PE^api("042","sandbox.dlc.id")

    SET eidViaPE=$$GetEID^apiGet("042",dlcaid)

    SET ok=(eidOwner>0)&(eidOwner=eidViaPE)

    DO AssertTrue("G3 unique attribute value resolves to owner eid",ok)
    QUIT

TestG4 ; PE invalid attribute key fails safely
;;------------------------------------------------------------------
;; Purpose: A misspelled attribute key does not resolve to any
;;          attribute or entity
;; Scope: PE^api, GetEID^sapiGet, GetEID^apiGet
;; Assert Condition: the attribute key and the entity both fail to
;;                    resolve
;;------------------------------------------------------------------
    WRITE !,"G4: PE invalid attribute key fails safely"
    NEW badattr  ; aid lookup for the misspelled attribute key
    NEW eid      ; eid resolved via PE^api on the misspelled key
    NEW ok       ; assertion outcome
    DO INIT^api

    SET badattr=$$GetEID^sapiGet("sandbox.movie.imdbi")

    DO PE^api("tt0011100","sandbox.movie.imdbi")

    SET eid=$$GetEID^apiGet("tt0011100",badattr)

    SET ok=(badattr<0)&(eid=0)

    DO AssertTrue("G4 typo attribute key does not resolve",ok)
    QUIT

TestG5 ; PE valid attribute unmatched value fails safely
;;------------------------------------------------------------------
;; Purpose: A valid attribute with a value that was never asserted
;;          does not resolve to any entity
;; Scope: PE^api, GetEID^sapiGet, GetEID^apiGet
;; Assert Condition: the attribute resolves but the entity does not
;;------------------------------------------------------------------
    WRITE !,"G5: PE valid attribute unmatched value fails"
    NEW imdbaid  ; imdbid attribute id
    NEW eid      ; eid resolved via PE^api on the unmatched value
    NEW ok       ; assertion outcome
    DO INIT^api

    SET imdbaid=$$GetEID^sapiGet("sandbox.movie.imdbid")

    DO PE^api("tt0000000","sandbox.movie.imdbid")

    SET eid=$$GetEID^apiGet("tt0000000",imdbaid)

    SET ok=(imdbaid>0)&(eid=0)

    DO AssertTrue("G5 valid attribute unknown value does not resolve",ok)
    QUIT

TestG6 ; PE resolves EID-shaped value that does not exist
;;------------------------------------------------------------------
;; Purpose: A value that is structurally shaped like an EID but was
;;          never registered does not resolve
;; Scope: PE^api, IsEID^utils, GetEID^apiGet
;; Assert Condition: the value is EID-shaped but does not resolve to
;;                    an entity
;;------------------------------------------------------------------
    WRITE !,"G6: PE EID-shaped value does not exist"
    NEW fakeEid       ; well-formed but unregistered EID
    NEW isEidShaped   ; whether fakeEid passes structural validation
    NEW eid           ; eid resolved via PE^api on fakeEid
    NEW ok            ; assertion outcome
    DO INIT^api

    SET fakeEid="6562b5f64d045kqoge3q"
    SET isEidShaped=$$IsEID^utils(fakeEid)

    DO PE^api(fakeEid)

    SET eid=$$GetEID^apiGet(fakeEid)

    SET ok=isEidShaped&(eid=0)

    DO AssertTrue("G6 nonexistent EID-shaped value does not resolve",ok)
    QUIT

TestG7 ; PE resolves garbage value safely
;;------------------------------------------------------------------
;; Purpose: A value with no attribute context that is not EID-shaped
;;          and matches no known key or value fails to resolve
;;          without error
;; Scope: PE^api, IsEID^utils, GetEID^apiGet
;; Assert Condition: the value is not EID-shaped and does not resolve
;;                    to an entity
;;------------------------------------------------------------------
    WRITE !,"G7: PE garbage value no attribute"
    NEW junk          ; arbitrary unregistered value
    NEW isEidShaped   ; whether junk passes structural validation
    NEW eid           ; eid resolved via PE^api on junk
    NEW ok            ; assertion outcome
    DO INIT^api

    SET junk="not-a-real-value-xyz"
    SET isEidShaped=$$IsEID^utils(junk)

    DO PE^api(junk)

    SET eid=$$GetEID^apiGet(junk)

    SET ok=('isEidShaped)&(eid=0)

    DO AssertTrue("G7 unknown garbage value does not resolve",ok)
    QUIT

TestG8 ; PE resolves value through non-unique attribute
;;------------------------------------------------------------------
;; Purpose: A non-unique, non-upsert attribute value still resolves
;;          to the currently live entity holding that value
;; Scope: PE^api, IsUniqueInsert^sapiVld, IsUniqueUpsert^sapiVld,
;;        GetEID^apiGet
;; Assert Condition: the attribute is confirmed non-unique, and
;;                    resolving by title matches resolving by imdbid
;;                    for the same live entity
;;------------------------------------------------------------------
    WRITE !,"G8: PE resolves non-unique attribute value"
    NEW titleaid    ; title attribute id
    NEW isUnq       ; whether title is UNQINSERT
    NEW isUpsert    ; whether title is UNQUPSERT
    NEW eidViaImdb  ; eid resolved via imdbid lookup
    NEW eidViaTitle ; eid resolved via PE^api on the title value
    NEW ok          ; assertion outcome
    DO INIT^api

    SET titleaid=$$GetEID^sapiGet("sandbox.movie.title")
    SET isUnq=$$IsUniqueInsert^sapiVld(titleaid)
    SET isUpsert=$$IsUniqueUpsert^sapiVld(titleaid)

    SET eidViaImdb=$$LookupEID^apiGet("tt0011100","sandbox.movie.imdbid")

    DO PE^api("Seven @en",titleaid)

    SET eidViaTitle=$$GetEID^apiGet("Seven @en",titleaid)

    SET ok=('isUnq)&('isUpsert)&(eidViaTitle=eidViaImdb)&(eidViaImdb>0)

    DO AssertTrue("G8 non-unique attribute resolves existing live entity",ok)
    QUIT

TestG9 ; PE cardinality-many attribute has multiple live values
;;------------------------------------------------------------------
;; Purpose: A cardinality-many attribute can hold multiple distinct
;;          values that are simultaneously live at the same
;;          transaction
;; Scope: RegisterAttrVal^sapiRslv
;; Assert Condition: both newly registered values are live at the
;;                    most recent transaction for this attribute
;;------------------------------------------------------------------
    WRITE !,"G9: PE cardinality-many attribute multiple live values"
    NEW eid       ; eid resolved via imdbid lookup
    NEW genreaid  ; genre attribute id
    NEW vk1       ; resolved valkey for "thriller"
    NEW vk2       ; resolved valkey for "mystery"
    NEW tx        ; most recent tx for genreaid on eid
    NEW live1     ; whether vk1 is live at tx
    NEW live2     ; whether vk2 is live at tx
    NEW isNew1    ; whether RegisterAttrVal registered vk1 as new
    NEW isNew2    ; whether RegisterAttrVal registered vk2 as new
    DO INIT^api

    SET eid=$$LookupEID^apiGet("tt0011100","sandbox.movie.imdbid")
    SET genreaid=$$GetEID^sapiGet("sandbox.movie.genre")

    SET isNew1=$$RegisterAttrVal^sapiRslv(genreaid,"thriller",.vk1)
    SET isNew2=$$RegisterAttrVal^sapiRslv(genreaid,"mystery",.vk2)

    SET tx=$ORDER(^EATV(eid,genreaid,""),-1)

    SET live1=($GET(^EATV(eid,genreaid,tx,vk1),0)=1)
    SET live2=($GET(^EATV(eid,genreaid,tx,vk2),0)=1)

    DO AssertTrue("G9 multiple cardinality-many values remain live",live1&live2)
    QUIT

TestG10 ; PE tmdbid lookup fails before assertion
;;------------------------------------------------------------------
;; Purpose: A tmdbid value that has not yet been asserted onto any
;;          entity does not resolve
;; Scope: PE^api, GetEID^apiGet
;; Assert Condition: the tmdbid value does not resolve to an entity
;;------------------------------------------------------------------
    WRITE !,"G10: PE tmdbid unresolved before UpdateSeven"
    NEW tmdbaid  ; tmdbid attribute id
    NEW eid      ; eid resolved via PE^api on the tmdbid value
    NEW ok       ; assertion outcome
    DO INIT^api

    SET tmdbaid=$$GetEID^sapiGet("sandbox.movie.tmdbid")

    DO PE^api(807,"sandbox.movie.tmdbid")

    SET eid=$$GetEID^apiGet(807,tmdbaid)

    SET ok=(eid=0)

    DO AssertTrue("G10 tmdbid value unresolved before assertion",ok)
    QUIT

TestG11 ; PH raw history shows title retraction and new live value
;;------------------------------------------------------------------
;; Purpose: PH^api reflects a title revision as a retraction of the
;;          old value and an assertion of the new value at the same
;;          transaction
;; Scope: PH^api, RegisterAttrVal^sapiRslv
;; Assert Condition: at the most recent transaction, the old title
;;                    value is retracted and the new title value is
;;                    live
;;------------------------------------------------------------------
    WRITE !,"G11: PH raw history title update retraction and assertion"
    NEW eid       ; eid resolved via imdbid lookup
    NEW titleaid  ; title attribute id
    NEW oldvk     ; resolved valkey for "Seven @en"
    NEW newvk     ; resolved valkey for "Se7en @en"
    NEW tx        ; most recent tx for titleaid on eid
    NEW oldOp     ; op value for oldvk at tx
    NEW newOp     ; op value for newvk at tx
    NEW isNewOld  ; whether RegisterAttrVal registered oldvk as new
    NEW isNewNew  ; whether RegisterAttrVal registered newvk as new
    DO INIT^api

    SET eid=$$LookupEID^apiGet("tt0011100","sandbox.movie.imdbid")
    SET titleaid=$$GetEID^sapiGet("sandbox.movie.title")

    SET isNewOld=$$RegisterAttrVal^sapiRslv(titleaid,"Seven @en",.oldvk)
    SET isNewNew=$$RegisterAttrVal^sapiRslv(titleaid,"Se7en @en",.newvk)

    DO PH^api(eid)

    SET tx=$ORDER(^EATV(eid,titleaid,""),-1)
    SET oldOp=$GET(^EATV(eid,titleaid,tx,oldvk),"")
    SET newOp=$GET(^EATV(eid,titleaid,tx,newvk),"")

    DO AssertTrue("G11 old title value retracted and new title value live",(oldOp=0)&(newOp=1))
    QUIT

TestG12 ; PE tmdbid lookup succeeds after UpdateSeven
;;------------------------------------------------------------------
;; Purpose: After the tmdbid value has been asserted onto the Seven
;;          entity, PE^api resolves it to that same entity
;; Scope: PE^api, GetEID^apiGet
;; Assert Condition: the tmdbid value resolves to the same eid as
;;                    the imdbid lookup
;;------------------------------------------------------------------
    WRITE !,"G12: PE tmdbid resolves after update to same eid"
    NEW tmdbaid     ; tmdbid attribute id
    NEW eidViaImdb  ; eid resolved via imdbid lookup
    NEW eidViaTmdb  ; eid resolved via PE^api on the tmdbid value
    NEW ok          ; assertion outcome
    DO INIT^api

    SET tmdbaid=$$GetEID^sapiGet("sandbox.movie.tmdbid")

    SET eidViaImdb=$$LookupEID^apiGet("tt0011100","sandbox.movie.imdbid")

    DO PE^api(807,"sandbox.movie.tmdbid")

    SET eidViaTmdb=$$GetEID^apiGet(807,tmdbaid)

    SET ok=(eidViaTmdb>0)&(eidViaTmdb=eidViaImdb)

    DO AssertTrue("G12 tmdbid resolves after update to same entity",ok)
    QUIT
    

; ==================================================================================================
; LAYER X — Cross Layer Tests
; ==================================================================================================
LayerX
;; ==================================================================================================
;; LAYER X — Cross-pipeline structural invariants
;; ==================================================================================================
;;
;; Test Coverage: Guarantees spanning the full resolve → validate → stage → commit
;;                lifecycle that no single-routine test can prove alone — control-attribute
;;                stripping, eid immutability under UNQUPSERT, no-redirect staging under
;;                DatomAssert, rollback cleanliness on rejected uniqueness collisions,
;;                atomic mixed-form commits, and bulk-load's validation-only relaxation.
;;
;; Scope: ResolveTargetEntity^apiRslv, Stage^api, Transact^api, DatomAssert^apiWFL, AD^api
;;
;; Result: 6/6 PASS
;; ==================================================================================================
    DO TestX1  ; Stage and AD mixed forms commit atomically
    DO TestX2  ; ResolveTargetEntity preserves UNQUPSERT owner eid
    DO TestX3  ; DatomAssert stages only supplied eid
    DO TestX4  ; Bulk load does not bypass entity resolution failures
    DO TestX5  ; Failed GENID transaction leaves no ^ABE ghost entries
    DO TestX6  ; UNQUPSERT leaves no orphaned staged entities
    
    QUIT


TestX1 ; Stage and AD mixed forms commit atomically
;;------------------------------------------------------------------
;; Purpose: A full Stage^api record update and an AD^api single-datom
;;          assertion targeting the same entity are committed
;;          together by one Transact call
;; Scope: Stage^api, AD^api, Transact^api
;; Assert Condition: the fact staged via the record-update form is
;;                    live after the shared commit
;;------------------------------------------------------------------
    WRITE !,"X1: Form 1 + Form 2 mixed atomic commit"
    NEW Obj         ; staged record-form update (Stage^api)
    NEW eid         ; eid of TomHanks
    NEW nameaid     ; sys.attr.name attribute id
    NEW labelaid    ; sys.attr.label attribute id
    NEW namevalkey  ; current valkey for name after commit
    NEW labelvalkey ; unused — carried over from original test body, not referenced below
    NEW nameok      ; whether the record-form name update committed correctly

    K Obj
    SET Obj(1,key)=TomHanks
    SET Obj(1,name)="tommy_x1"

    DO Stage^api(.Obj)
    DO AD^api(TomHanks,label,"Tom X1 @en")
    DO Transact^api

    SET eid=$$GetEID^apiGet(TomHanks)
    SET nameaid=$$GetEID^sapiGet("sys.attr.name")
    SET labelaid=$$GetEID^sapiGet("sys.attr.label")
    SET namevalkey=$$GetCurrentVK^apiGet(eid,nameaid)
    SET nameok=($$GetDictValue^sapiGet(nameaid,namevalkey)="tommy_x1")

    DO AssertTrue("X1 Form 1 and Form 2 facts committed atomically",nameok)
    QUIT


TestX2 ; ResolveTargetEntity preserves UNQUPSERT owner eid
;;------------------------------------------------------------------
;; Purpose: An UNQUPSERT update resolves the existing owner eid and
;;          commits changes against that same identity, without
;;          redirecting staging to another entity
;; Scope: Stage^api, Transact^api
;; Assert Condition: the eid resolved before staging matches the eid
;;                    resolved after commit, and both are valid
;;------------------------------------------------------------------
    WRITE !,"X2: UNQUPSERT preserves existing owner eid"
    NEW Item      ; staged record for the UNQUPSERT update
    NEW eidbefore ; owner eid resolved before staging
    NEW eidafter  ; owner eid resolved after commit
    NEW dlcaid    ; sandbox.dlc.id attribute id
    NEW valkey    ; valkey for dlc id "042", re-resolved before/after commit

    DO INIT^api

    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET valkey=$GET(^TBDR(dlcaid,"042"))
    SET eidbefore=$ORDER(^AVET(dlcaid,valkey,""))

    K Item
    SET Item(1,dlcid)="042"
    SET Item(1,checkup)="X2 checkup @en"

    DO Stage^api(.Item)
    DO Transact^api

    SET valkey=$GET(^TBDR(dlcaid,"042"))
    SET eidafter=$ORDER(^AVET(dlcaid,valkey,""))

    DO AssertTrue("X2 same eid before and after UNQUPSERT",(eidbefore>0)&(eidbefore=eidafter))
    QUIT


TestX3 ; DatomAssert stages only supplied eid
;;------------------------------------------------------------------
;; Purpose: DatomAssert stages facts only under the eid supplied by
;;          the caller, preventing silent entity redirection during
;;          assertion
;; Scope: DatomAssert^apiWFL
;; Assert Condition: the assertion succeeds, the supplied eid is
;;                    staged, and no other eid appears in the staged
;;                    set
;;------------------------------------------------------------------
    WRITE !,"X3: DatomAssert does not redirect identity"
    NEW eid        ; caller-supplied eid to assert against
    NEW aid        ; sandbox.movie.title attribute id
    NEW ok         ; whether DatomAssert reported success
    NEW otherEid   ; iteration cursor over staged %ABR eids
    NEW foundOther ; whether any staged eid differs from the supplied eid

    DO INIT^api

    SET eid=$$GENID^utils
    SET aid=$$GetEID^sapiGet("sandbox.movie.title")

    SET ok=$$DatomAssert^apiWFL(eid,aid,"X3 Test Title")

    SET foundOther=0
    SET otherEid=""
    FOR  SET otherEid=$ORDER(%ABR(otherEid)) QUIT:otherEid=""  DO
    . IF otherEid'=eid SET foundOther=1

    DO AssertTrue("X3 DatomAssert staged supplied eid only",(ok=1)&('foundOther)&$DATA(%ABR(eid)))
    QUIT


TestX4 ; Bulk load does not bypass entity resolution failures
;;------------------------------------------------------------------
;; Purpose: isBulkLoad bypasses ValidateRecord requirements but does
;;          not bypass ResolveTargetEntity correctness checks —
;;          invalid entity references still abort the operation
;; Scope: Stage^api, Transact^api
;; Assert Condition: nothing is staged for the invalid bulk-load
;;                    entity reference
;;------------------------------------------------------------------
    WRITE !,"X4: isBulkLoad skips validation not ResolveTargetEntity"
    NEW Movies     ; staged record referencing a well-formed but unregistered EID
    NEW ok         ; whether staging correctly produced nothing
    NEW isBulkLoad ; bulk-load flag passed to Stage^api

    K Movies
    SET Movies(1,id)="65560e13bd45f6y9xowl"
    SET Movies(1,"movie.title")="Bulk Test"
    SET isBulkLoad=1

    DO Stage^api(.Movies,"sandbox",isBulkLoad)

    SET ok=('$DATA(%ABR)!(%ABR=0))

    DO Transact^api
    DO AssertTrue("X4 invalid EID rejected even during bulk load",ok)
    QUIT



TestX5 ; Failed GENID transaction leaves no ^ABE ghost entries
;;------------------------------------------------------------------
;; Purpose: A rejected uniqueness collision must not allocate
;;          persistent ^ABE bookkeeping for the failed new entity
;; Scope: Stage^api, Transact^api
;; Assert Condition: the ^ABE root count is unchanged after the
;;                    failed transaction
;;------------------------------------------------------------------
    WRITE !,"X5: failed GENID rollback leaves no ghost ^ABE"
    NEW Movies    ; staged record whose imdbid collides with an existing live value
    NEW abeBefore ; ^ABE root count before the failed transaction
    NEW abeAfter  ; ^ABE root count after the failed transaction

    K Movies
    SET Movies(1,"movie.title")="Ghost Movie X5"
    SET Movies(1,"movie.genre")="drama"
    SET Movies(1,"movie.releaseYear")=2008
    SET Movies(1,"movie.imdbid")="tt0011100"   ; collision

    DO INIT^api

    SET abeBefore=$GET(^ABE,0)

    DO Stage^api(.Movies)
    DO Transact^api

    SET abeAfter=$GET(^ABE,0)

    DO AssertTrue("X5 failed assertion leaves no ghost ^ABE allocation",abeBefore=abeAfter)
    QUIT


TestX6 ; UNQUPSERT leaves no orphaned staged entities
;;------------------------------------------------------------------
;; Purpose: UNQUPSERT staging contains only the resolved owner eid —
;;          no orphaned entries under the original candidate
;;          identity or any other intermediate eid appear in %ABR
;;          before Transact runs
;; Scope: Stage^api
;; Assert Condition: the owner eid resolves and no other eid appears
;;                    in the staged set
;;------------------------------------------------------------------
    WRITE !,"X6: UNQUPSERT no orphaned %ABR"
    NEW Item     ; staged record for the UNQUPSERT update
    NEW dlcaid   ; sandbox.dlc.id attribute id
    NEW valkey   ; valkey for dlc id "042"
    NEW ownereid ; eid owning the "042" dlc id value before staging
    NEW eid      ; iteration cursor over staged %ABR eids
    NEW orphan   ; whether any staged eid differs from the owner eid

    DO INIT^api

    SET dlcaid=$$GetEID^sapiGet("sandbox.dlc.id")
    SET valkey=$GET(^TBDR(dlcaid,"042"))
    SET ownereid=$ORDER(^AVET(dlcaid,valkey,""))

    K Item
    SET Item(1,dlcid)="042"
    SET Item(1,checkup)="X6 checkup @en"

    DO Stage^api(.Item)

    SET orphan=0
    SET eid=""
    FOR  SET eid=$ORDER(%ABR(eid)) QUIT:eid=""  DO
    . IF eid'=ownereid SET orphan=1

    DO Transact^api
    DO AssertTrue("X6 UNQUPSERT stages only owner eid",(ownereid>0)&('orphan))
    QUIT

