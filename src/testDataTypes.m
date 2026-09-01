;; ============================================================ 
;; ^testDataTypes - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 		— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;; ==============================================================================

INIT
	D INIT^utils
	
	D ResetCounters
	
	; D ValidFunctionNames("IsFunctionName^utils")
	; D InvalidFunctionNames("IsFunctionName^utils")
	
	; D ValidGPS("IsGPS^utils")
	; D InvalidGPS("IsGPS^utils")		

	; D ValidPoints("IsPoint^utils")
	; D InvalidPoints("IsPoint^utils")

	; D ValidPointZ("IsPointZ^utils")
	; D InvalidPointZ("IsPointZ^utils")

	; D ValidLangStr("IsLangStr^utils")
	; D InvalidLangStr("IsLangStr^utils")

	; D ValidURL("IsURL^utils")
	; D InvalidURL("IsURL^utils")
		
	; D ValidInts("IsInt^utils")
	; D InvalidInts("IsInt^utils")

	; D ValidNumbers("IsNum^utils")
	; D InvalidNumbers("IsNum^utils")

	; D ValidBoolean("IsBoolean^utils")
	; D InvalidBoolean("IsBoolean^utils")

	D ValidDates("IsDate^utils")
	D InvalidDates("IsDate^utils")

	D ValidTime("IsTime^utils")
	D InvalidTime("IsTime^utils")	
	

	D PrintSummary
	Q


;==================================================================
; TEST FRAMEWORK HELPERS
; Used by ALL test suites below.
; Initializes counters, tracks PASS/FAIL results, and prints the
; final test summary.
;==================================================================

ResetCounters ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Initialize global counters used to tally test results.
    ;--------------------------------------------------------------
    SET ^TESTCNT("PASS")=0
    SET ^TESTCNT("FAIL")=0
    KILL ^TESTFAIL
    QUIT
 
 
PrintSummary ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Print running totals of PASS/FAIL results and list failures.
    ;--------------------------------------------------------------
    NEW total,pct,i,val
 
    SET total=^TESTCNT("PASS")+^TESTCNT("FAIL")
 
    WRITE !,"=== Test Result Summary ===",!
    WRITE "PASS : ",^TESTCNT("PASS"),!
    WRITE "FAIL : ",^TESTCNT("FAIL"),!
    WRITE "TOTAL: ",total,!
 
    IF total>0 DO
    . SET pct=(^TESTCNT("PASS")/total)*100
    . WRITE "Pass rate: ",$FNUMBER(pct,"",1),"%",!
 
    IF ^TESTCNT("FAIL")>0 DO
    . WRITE !,"=== Failed cases ===",!
    . SET i=""
    . FOR  SET i=$ORDER(^TESTFAIL(i)) QUIT:i=""  DO
    . . SET val=^TESTFAIL(i)
    . . WRITE "- ",val,!
 
    QUIT


EscapeQuotes(s) ;    
    ; Double every embedded quote so it's a safe M string literal.
    NEW out,i,c
    SET out=""
    FOR i=1:1:$LENGTH(s) DO
    . SET c=$EXTRACT(s,i)
    . SET out=out_c_$SELECT(c="""":"""",1:"")
    QUIT out
 
 
CallPredicate(fn,val) ;
    ; ------------------------------------------------------------
    ; Purpose : Executes fn(val) indirectly via XECUTE, safely.
    ; fn      : "Tag^Routine" string, e.g. "IsFunctionName^utils"
    ;           (leading "$$" optional — added if not present)
    ; val     : the value to pass to the predicate
    ; Returns : whatever fn(val) returns (expected 1 or 0)
    ; ------------------------------------------------------------
    NEW result,safeVal,call
 
    SET result=0
    IF fn="" QUIT 1
 
    SET call=$SELECT($EXTRACT(fn,1,2)="$$":fn,1:"$$"_fn)
 
    ; Escape embedded quotes so val cannot terminate the string
    ; literal early and inject code into the executed command.
    SET safeVal=$$EscapeQuotes(val)
 
 	; fn is the "Tag^Routine" string (no leading $$).
    ; Since direct indirection ($$@fn(val) / $$@fn@(val)) is not
    ; reliable here, the call is built as a string and run via
    ; XECUTE, with embedded quotes escaped so val can't break out
    ; of the string literal or inject code.	
    XECUTE "SET result="_call_"("""_safeVal_""")"
 
    QUIT result
 
 
AssertGood(fn,val) ;
    ; Expected: $$CallPredicate(fn,val) MUST return 1
    NEW res
    SET res=$$CallPredicate(fn,val)
 
    IF res=1 DO
    . WRITE !,"PASS: ",val
    . SET ^TESTCNT("PASS")=^TESTCNT("PASS")+1
    ELSE  DO
    . WRITE !,"FAIL (should accept): ",val," [",fn,"]"
    . SET ^TESTCNT("FAIL")=^TESTCNT("FAIL")+1
    . SET ^TESTFAIL($INCREMENT(^TESTFAIL))="(should accept) ["_fn_"]: "_val
 
    QUIT
 
 
AssertBad(fn,val) ;
    ; Expected: $$CallPredicate(fn,val) MUST return 0
    NEW res
    SET res=$$CallPredicate(fn,val)
 
    IF res=0 DO
    . WRITE !,"PASS (rejected): ",val
    . SET ^TESTCNT("PASS")=^TESTCNT("PASS")+1
    ELSE  DO
    . WRITE !,"FAIL (accepted but should reject): ",val," [",fn,"]"
    . SET ^TESTCNT("FAIL")=^TESTCNT("FAIL")+1
    . SET ^TESTFAIL($INCREMENT(^TESTFAIL))="(accepted but should reject) ["_fn_"]: "_val
 
    QUIT
 
 
 
;==================================================================
; TEST SUITES
; Collection of positive and negative test cases for all validators.
;==================================================================
;
;
;
;------------------------------------------------------------------
; FUNCTION NAME TEST SUITE
; Valid and invalid test cases for IsFunctionName().
;------------------------------------------------------------------
ValidFunctionNames(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Positive test suite for IsFunctionName()
    ;   Ensures valid MUMPS extrinsic function references are accepted.
    ;
    ; Params:
    ;   fname - "Tag^Routine" string of the validator under test,
    ;           e.g. "IsFunctionName^utils"
    ;
    ; Expected:
    ;   All cases MUST return 1 (valid)
    ;--------------------------------------------------------------
 
    WRITE !,"=== Testing ",fname," VALID CASES ===",!
 
 	; These are syntactically correct function names and the tag/routine exists
 	; these will PASS 
    DO AssertGood(fname,"$$IsInt^utils")			; Standard function references
    DO AssertGood(fname,"$$IsPoint^utils")			; Standard function references
    DO AssertGood(fname,"$$IsGPS^utils")			; Standard function references
 
 	; The following are syntactically correct function names
 	; But all these test will FAIL because those functions do not exist as tag/routine in a file
 	; So a total of 7 tests will FAIL
 	DO AssertBad(fname,"$$AreScoresOrdered^utils") ; Standard function references
 
    DO AssertBad(fname,"$$A^utils")	   	; Single-letter tag
 
    DO AssertBad(fname,"$$IsInt^%utils")	; Routine name starting with %
    DO AssertBad(fname,"$$IsInt^%zutils")	; Routine name starting with %
 
    DO AssertBad(fname,"$$IsInt2^utils")		; Alphanumeric characters in tag/routine
    DO AssertBad(fname,"$$IsInt^utils2")		; Alphanumeric characters in tag/routine
    DO AssertBad(fname,"$$Ver2Check^utils2")	; Alphanumeric characters in tag/routine
 
    WRITE !,"=== Done ",fname," VALID TESTS ===",!
    QUIT
 
 
InvalidFunctionNames(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Negative test suite for IsFunctionName()
    ;   Ensures invalid MUMPS extrinsic function references are rejected.
    ;
    ; Params:
    ;   fname - "Tag^Routine" string of the validator under test,
    ;           e.g. "IsFunctionName^utils"
    ;
    ; Expected:
    ;   All cases MUST return 0 (invalid)
    ;--------------------------------------------------------------
 
    WRITE !,"=== Testing ",fname," INVALID CASES ===",!
 
    DO AssertBad(fname,"AreScoresOrdered^utils")	; Missing $$ prefix
    DO AssertBad(fname,"$AreScoresOrdered^utils")	; Missing $$ prefix
 
    DO AssertBad(fname,"$$areScoresOrdered^utils")  ; Lowercase first letter of tag
    DO AssertBad(fname,"$$isInt^utils") 			; Lowercase first letter of tag
     
    DO AssertBad(fname,"$$AreScoresOrdered") ; Missing ^ separator
    DO AssertBad(fname,"$$IsIntutils")		 ; Missing ^ separator
 
    DO AssertBad(fname,"$$Too^Many^Carets") ; Too many ^ separators
     
    DO AssertBad(fname,"$$^utils") ; Missing tag or routine
    DO AssertBad(fname,"$$IsInt^") ; Missing tag or routine
 
    DO AssertBad(fname,"$$Is-Int^utils") ; Invalid characters
    DO AssertBad(fname,"$$Is Int^utils") ; Invalid characters
    DO AssertBad(fname,"$$IsInt^ut ils") ; Invalid characters
    DO AssertBad(fname,"$$IsInt^utils!") ; Invalid characters
 
    DO AssertBad(fname,"$$1IsInt^utils") ; Tag starting with digit
 
    DO AssertBad(fname,"$$IsInt^2utils") ; Routine starting with digit
 
    DO AssertBad(fname,"IsInt") 		 ; Wrong format / empty
    DO AssertBad(fname,"") 				 ; Wrong format / empty

    ; DO AssertBad(fname,"$$IsInteger^utils") ; Tag not defined in routine (LABELMISSING)
    ; DO AssertBad(fname,"$$IsInt^rutils") 	; Routine does not exist (ZLINKFILE)
 
    WRITE !,"=== Done ",fname," INVALID TESTS ===",!
    QUIT


;------------------------------------------------------------------
; GPS COORDINATE TEST SUITE
; Valid and invalid test cases for IsGPS().
;------------------------------------------------------------------
;
ValidGPS(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Positive test suite for IsGPS()
    ;   Ensures valid GPS latitude/longitude pairs are accepted.
    ;
    ; Params:
    ;   fname - "Tag^Routine" string of the validator under test,
    ;           e.g. "IsGPS^utils"
    ;
    ; Expected:
    ;   All cases MUST return 1 (valid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," VALID CASES ===",!

    ;-----------------------------
    ; Standard GPS coordinates
    ;-----------------------------
    DO AssertGood(fname,"(-36.60664,-72.10344)")
    DO AssertGood(fname,"(37.774900,-122.419400)")
    DO AssertGood(fname,"(37.983810,23.727539)")

    ;-----------------------------
    ; Boundary values
    ;-----------------------------
    DO AssertGood(fname,"(0,0)")
    DO AssertGood(fname,"(90,180)")
    DO AssertGood(fname,"(-90,-180)")

    ;-----------------------------
    ; Positive / negative combinations
    ;-----------------------------
    DO AssertGood(fname,"(45.5,120.75)")
    DO AssertGood(fname,"(-45.5,-120.75)")
    DO AssertGood(fname,"(12.345678,-98.765432)")

    ;-----------------------------
    ; Spaces allowed
    ;-----------------------------
    DO AssertGood(fname,"( -36.60664, -72.10344 )")

    WRITE !,"=== Done ",fname," VALID TESTS ===",!
    QUIT


InvalidGPS(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Negative test suite for IsGPS()
    ;   Ensures invalid GPS coordinates are rejected.
    ;
    ; Params:
    ;   fname - "Tag^Routine" string of the validator under test,
    ;           e.g. "IsGPS^utils"
    ;
    ; Expected:
    ;   All cases MUST return 0 (invalid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," INVALID CASES ===",!

    ;-----------------------------
    ; Latitude violations
    ;-----------------------------
    DO AssertBad(fname,"(91,0)")
    DO AssertBad(fname,"(-91,0)")
    DO AssertBad(fname,"(999,-72.10344)")

    ;-----------------------------
    ; Longitude violations
    ;-----------------------------
    DO AssertBad(fname,"(0,181)")
    DO AssertBad(fname,"(0,-181)")
    DO AssertBad(fname,"(37.7749,999)")

    ;-----------------------------
    ; Missing coordinates
    ;-----------------------------
    DO AssertBad(fname,"(-36.60664)")
    DO AssertBad(fname,"(,-72.10344)")
    DO AssertBad(fname,"(-36.60664,)")

    ;-----------------------------
    ; Too many coordinates
    ;-----------------------------
    DO AssertBad(fname,"(-36.60664,-72.10344,140)")

    ;-----------------------------
    ; Wrong format
    ;-----------------------------
    DO AssertBad(fname,"-36.60664,-72.10344")
    DO AssertBad(fname,"POINT (-72.10344 -36.60664)")
    DO AssertBad(fname,"[-36.60664,-72.10344]")
    DO AssertBad(fname,"GPS (-36.60664,-72.10344)")
    DO AssertBad(fname,"")

    ;-----------------------------
    ; Invalid numeric values
    ;-----------------------------
    DO AssertBad(fname,"(abc,-72.10344)")
    DO AssertBad(fname,"(-36.60664,xyz)")
    DO AssertBad(fname,"(10.5.5,20)")

    WRITE !,"=== Done ",fname," INVALID TESTS ===",!
    QUIT


;------------------------------------------------------------------
; WKT POINT TEST SUITE
; Valid and invalid test cases for IsPoint().
;------------------------------------------------------------------
;
ValidPoints(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Positive test suite for IsPoint()
    ;   Ensures valid WKT POINT geometries are accepted.
    ;
    ; Params:
    ;   fname - "Tag^Routine" string of the validator under test,
    ;           e.g. "IsPoint^utils"
    ;
    ; Expected:
    ;   All cases MUST return 1 (valid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," VALID CASES ===",!

    ;-----------------------------
    ; Standard geographic points
    ;-----------------------------
    DO AssertGood(fname,"POINT (-72.10344 -36.60664)")
    DO AssertGood(fname,"POINT (0 0)")
    DO AssertGood(fname,"POINT (180 90)")
    DO AssertGood(fname,"POINT (-180 -90)")

    ;-----------------------------
    ; Decimal precision cases
    ;-----------------------------
    DO AssertGood(fname,"POINT (-122.419400 37.774900)")
    DO AssertGood(fname,"POINT (23.727539 37.983810)")

    ;-----------------------------
    ; Boundary values
    ;-----------------------------
    DO AssertGood(fname,"POINT (180 -90)")
    DO AssertGood(fname,"POINT (-180 90)")

    WRITE !,"=== Done ",fname," VALID TESTS ===",!
    QUIT


InvalidPoints(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Negative test suite for IsPoint()
    ;   Ensures invalid WKT POINT geometries are rejected.
    ;
    ; Params:
    ;   fname - "Tag^Routine" string of the validator under test,
    ;           e.g. "IsPoint^utils"
    ;
    ; Expected:
    ;   All cases MUST return 0 (invalid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," INVALID CASES ===",!

    ;-----------------------------
    ; Invalid longitude
    ;-----------------------------
    DO AssertBad(fname,"POINT (181 0)")
    DO AssertBad(fname,"POINT (-181 0)")
    DO AssertBad(fname,"POINT (999 45)")

    ;-----------------------------
    ; Invalid latitude
    ;-----------------------------
    DO AssertBad(fname,"POINT (0 91)")
    DO AssertBad(fname,"POINT (0 -91)")
    DO AssertBad(fname,"POINT (30 999)")

    ;-----------------------------
    ; Wrong WKT structure
    ;-----------------------------
    DO AssertBad(fname,"POINT(-72.10344 -36.60664)")
    DO AssertBad(fname,"POINT (-72.10344, -36.60664)")
    DO AssertBad(fname,"POINT (-72.10344)")
    DO AssertBad(fname,"POINT (-72.10344 -36.60664 100)")

    ;-----------------------------
    ; Invalid numeric values
    ;-----------------------------
    DO AssertBad(fname,"POINT (abc 10)")
    DO AssertBad(fname,"POINT (10 xyz)")
    DO AssertBad(fname,"POINT ( )")

    ;-----------------------------
    ; Garbage input
    ;-----------------------------
    DO AssertBad(fname,"")
    DO AssertBad(fname," ")
    DO AssertBad(fname,"POINT")
    DO AssertBad(fname,"GPS (-72.10344 -36.60664)")

    WRITE !,"=== Done ",fname," INVALID TESTS ===",!
    QUIT


;------------------------------------------------------------------
; WKT POINT Z TEST SUITE
; Valid and invalid test cases for IsPointZ().
;------------------------------------------------------------------
ValidPointZ(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Positive test suite for IsPointZ()
    ;   Ensures valid WKT POINT Z geometries are accepted.
    ;
    ; Params:
    ;   fname - "Tag^Routine" string of the validator under test.
    ;
    ; Expected:
    ;   All cases MUST return 1 (valid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," VALID CASES ===",!

    ;-----------------------------
    ; Standard 3D geographic points
    ;-----------------------------
    DO AssertGood(fname,"POINT Z (-72.10344 -36.60664 140)")
    DO AssertGood(fname,"POINT Z (0 0 0)")
    DO AssertGood(fname,"POINT Z (23.727539 37.983810 15)")

    ;-----------------------------
    ; Boundary coordinates
    ;-----------------------------
    DO AssertGood(fname,"POINT Z (180 90 0)")
    DO AssertGood(fname,"POINT Z (-180 -90 -430)")

    ;-----------------------------
    ; Decimal altitude
    ;-----------------------------
    DO AssertGood(fname,"POINT Z (-122.419400 37.774900 16.7)")
    DO AssertGood(fname,"POINT Z (23.727539 37.983810 1234.56)")

    WRITE !,"=== Done ",fname," VALID TESTS ===",!
    QUIT


InvalidPointZ(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Negative test suite for IsPointZ()
    ;   Ensures invalid WKT POINT Z geometries are rejected.
    ;
    ; Params:
    ;   fname - "Tag^Routine" string of the validator under test.
    ;
    ; Expected:
    ;   All cases MUST return 0 (invalid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," INVALID CASES ===",!

    ;-----------------------------
    ; Missing altitude
    ;-----------------------------
    DO AssertBad(fname,"POINT Z (-72.10344 -36.60664)")

    ;-----------------------------
    ; Invalid longitude
    ;-----------------------------
    DO AssertBad(fname,"POINT Z (181 0 10)")
    DO AssertBad(fname,"POINT Z (-181 0 10)")

    ;-----------------------------
    ; Invalid latitude
    ;-----------------------------
    DO AssertBad(fname,"POINT Z (0 91 10)")
    DO AssertBad(fname,"POINT Z (0 -91 10)")

    ;-----------------------------
    ; Invalid altitude
    ;-----------------------------
    DO AssertBad(fname,"POINT Z (10 20 abc)")
    DO AssertBad(fname,"POINT Z (10 20)")

    ;-----------------------------
    ; Wrong WKT structure
    ;-----------------------------
    DO AssertBad(fname,"POINT (-72.10344 -36.60664 140)")
    DO AssertBad(fname,"POINT Z(-72.10344 -36.60664 140)")
    DO AssertBad(fname,"POINT Z (-72.10344, -36.60664, 140)")

    ;-----------------------------
    ; Garbage input
    ;-----------------------------
    DO AssertBad(fname,"")
    DO AssertBad(fname," ")
    DO AssertBad(fname,"POINT Z")
    DO AssertBad(fname,"GPS Z (-72.10344 -36.60664 140)")

    WRITE !,"=== Done ",fname," INVALID TESTS ===",!
    QUIT

;------------------------------------------------------------------
; LANGUAGE STRING TEST SUITE
; Valid and invalid test cases for IsLangStr().
;------------------------------------------------------------------
ValidLangStr(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Positive test suite for IsLangStr()
    ;
    ; Expected:
    ;   All cases MUST return 1 (valid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," VALID CASES ===",!

    ;-----------------------------
    ; Common 2-letter lang codes
    ;-----------------------------
    DO AssertGood(fname,"The Godfather@en")
    DO AssertGood(fname,"Le Parrain @fr")
    DO AssertGood(fname,"Der Pate@de")
    DO AssertGood(fname,"Ο Νονός @el")
    DO AssertGood(fname,"El Padrino @es")
    DO AssertGood(fname,"O Podrinho@pt")

    ;-----------------------------
    ; 3-letter lang codes
    ;-----------------------------
    DO AssertGood(fname,"The Godfather@eng")
    DO AssertGood(fname,"Le Parrain@fra")
    DO AssertGood(fname,"Der Pate@deu")

    ;-----------------------------
    ; @ inside content
    ;-----------------------------
    DO AssertGood(fname,"hello@world@en")
    DO AssertGood(fname,"user@example.com@fr")

    ;-----------------------------
    ; Minimal valid
    ;-----------------------------
    DO AssertGood(fname,"A@en")
    DO AssertGood(fname,"X@zho")

    WRITE !,"=== Done ",fname," VALID TESTS ===",!
    QUIT


InvalidLangStr(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Negative test suite for IsLangStr()
    ;
    ; Expected:
    ;   All cases MUST return 0 (invalid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," INVALID CASES ===",!

    ;-----------------------------
    ; Empty / whitespace
    ;-----------------------------
    DO AssertBad(fname,"")
    DO AssertBad(fname," ")

    ;-----------------------------
    ; Missing @ separator
    ;-----------------------------
    DO AssertBad(fname,"The Godfather")
    DO AssertBad(fname,"hello")
    DO AssertBad(fname,"plainstring")

    ;-----------------------------
    ; Empty string part
    ;-----------------------------
    DO AssertBad(fname,"@en")
    DO AssertBad(fname,"@fr")
    DO AssertBad(fname,"@eng")

    ;-----------------------------
    ; Empty language tag
    ;-----------------------------
    DO AssertBad(fname,"hello@")
    DO AssertBad(fname,"The Godfather@")

    ;-----------------------------
    ; Numeric language tag
    ;-----------------------------
    DO AssertBad(fname,"hello@123")
    DO AssertBad(fname,"hello@12")

    ;-----------------------------
    ; Too short
    ;-----------------------------
    DO AssertBad(fname,"hello@e")
    DO AssertBad(fname,"hello@f")

    ;-----------------------------
    ; Too long
    ;-----------------------------
    DO AssertBad(fname,"hello@engl")
    DO AssertBad(fname,"hello@toolong")
    DO AssertBad(fname,"hello@abcd")

    ;-----------------------------
    ; Invalid characters
    ;-----------------------------
    DO AssertBad(fname,"hello@en1")
    DO AssertBad(fname,"hello@e1")
    DO AssertBad(fname,"hello@e-n")
    DO AssertBad(fname,"hello@!!")

    WRITE !,"=== Done ",fname," INVALID TESTS ===",!
    QUIT

;------------------------------------------------------------------
; URL VALIDATION TEST SUITE
; Valid and invalid test cases for IsURL().
;------------------------------------------------------------------
ValidURL(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Positive test suite for IsURL()
    ;
    ; Expected:
    ;   All cases MUST return 1 (valid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," VALID CASES ===",!

    ;-----------------------------
    ; Basic HTTP / HTTPS
    ;-----------------------------
    DO AssertGood(fname,"http://example.com")
    DO AssertGood(fname,"https://example.com")

    ;-----------------------------
    ; Wikipedia URLs
    ;-----------------------------
    DO AssertGood(fname,"https://en.wikipedia.org/wiki/Inception")
    DO AssertGood(fname,"https://en.wikipedia.org/wiki/The_Godfather")
    DO AssertGood(fname,"https://el.wikipedia.org/wiki/Inception")
    DO AssertGood(fname,"https://fr.wikipedia.org/wiki/Inception_(film)")

    ;-----------------------------
    ; Subdomain
    ;-----------------------------
    DO AssertGood(fname,"https://www.example.com")
    DO AssertGood(fname,"http://sub.domain.example.com")

    ;-----------------------------
    ; Paths
    ;-----------------------------
    DO AssertGood(fname,"https://example.com/some/path")
    DO AssertGood(fname,"https://example.com/path/to/page.html")

    ;-----------------------------
    ; Query / fragment
    ;-----------------------------
    DO AssertGood(fname,"https://example.com/search?q=hello")
    DO AssertGood(fname,"https://example.com/search?q=hello&lang=en")
    DO AssertGood(fname,"https://en.wikipedia.org/wiki/Film#History")
    DO AssertGood(fname,"https://example.com/page?x=1#section2")

    WRITE !,"=== Done ",fname," VALID TESTS ===",!
    QUIT


InvalidURL(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Negative test suite for IsURL()
    ;
    ; Expected:
    ;   All cases MUST return 0 (invalid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," INVALID CASES ===",!

    ;-----------------------------
    ; Empty / whitespace
    ;-----------------------------
    DO AssertBad(fname,"")
    DO AssertBad(fname," ")
    DO AssertBad(fname,"   ")

    ;-----------------------------
    ; Missing scheme
    ;-----------------------------
    DO AssertBad(fname,"example.com")
    DO AssertBad(fname,"www.example.com")
    DO AssertBad(fname,"en.wikipedia.org/wiki/Inception")

    ;-----------------------------
    ; Wrong scheme
    ;-----------------------------
    DO AssertBad(fname,"ftp://example.com")
    DO AssertBad(fname,"mailto:user@example.com")
    DO AssertBad(fname,"file:///etc/passwd")
    DO AssertBad(fname,"//example.com")

    ;-----------------------------
    ; No host
    ;-----------------------------
    DO AssertBad(fname,"http://")
    DO AssertBad(fname,"https://")

    ;-----------------------------
    ; Spaces
    ;-----------------------------
    DO AssertBad(fname,"https://example.com/path with spaces")
    DO AssertBad(fname,"https://ex ample.com")
    DO AssertBad(fname,"http:// example.com")

    ;-----------------------------
    ; Malformed host
    ;-----------------------------
    DO AssertBad(fname,"https://.example.com")
    DO AssertBad(fname,"https://example.")
    DO AssertBad(fname,"https://-example.com")
    DO AssertBad(fname,"https://example-.com")

    ;-----------------------------
    ; No dot in host
    ;-----------------------------
    DO AssertBad(fname,"https://localhost")
    DO AssertBad(fname,"http://myserver")

    ;-----------------------------
    ; Garbage
    ;-----------------------------
    DO AssertBad(fname,"notaurl")
    DO AssertBad(fname,"12345")
    DO AssertBad(fname,"@#$%^&*()")
    DO AssertBad(fname,"http//example.com")
    DO AssertBad(fname,"https:/example.com")

    WRITE !,"=== Done ",fname," INVALID TESTS ===",!
    QUIT


;------------------------------------------------------------------
; INTEGER VALIDATION TEST SUITE
; Valid and invalid test cases for IsInt().
;------------------------------------------------------------------
ValidInts(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Positive test suite for IsInt()
    ;   Ensures valid integer values are accepted.
    ;
    ; Params:
    ;   fname - "Tag^Routine" string of the validator under test.
    ;
    ; Expected:
    ;   All cases MUST return 1 (valid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," VALID CASES ===",!

    ;-----------------------------
    ; Standard integers
    ;-----------------------------
    DO AssertGood(fname,"0")
    DO AssertGood(fname,"1")
    DO AssertGood(fname,"42")
    DO AssertGood(fname,"123456")
    DO AssertGood(fname,"999999999")

    WRITE !,"=== Done ",fname," VALID TESTS ===",!
    QUIT


InvalidInts(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Negative test suite for IsInt()
    ;   Ensures invalid integer values are rejected.
    ;
    ; Expected:
    ;   All cases MUST return 0 (invalid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," INVALID CASES ===",!

    ;-----------------------------
    ; Decimal values
    ;-----------------------------
    DO AssertBad(fname,"1.0")
    DO AssertBad(fname,"10.5")

    ;-----------------------------
    ; Signed values
    ;-----------------------------
    DO AssertBad(fname,"-1")
    DO AssertBad(fname,"+1")

    ;-----------------------------
    ; Non-numeric values
    ;-----------------------------
    DO AssertBad(fname,"1a")
    DO AssertBad(fname,"abc")

    ;-----------------------------
    ; Empty values
    ;-----------------------------
    DO AssertBad(fname,"")
    DO AssertBad(fname," ")

    WRITE !,"=== Done ",fname," INVALID TESTS ===",!
    QUIT


;------------------------------------------------------------------
; NUMBER VALIDATION TEST SUITE
; Valid and invalid test cases for IsNum().
;------------------------------------------------------------------
ValidNumbers(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Positive test suite for IsNum()
    ;   Ensures valid numeric values are accepted.
    ;
    ; Expected:
    ;   All cases MUST return 1 (valid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," VALID CASES ===",!

    ;-----------------------------
    ; Integer values
    ;-----------------------------
    DO AssertGood(fname,"0")
    DO AssertGood(fname,"1")

    ;-----------------------------
    ; Decimal values
    ;-----------------------------
    DO AssertGood(fname,"10.5")
    DO AssertGood(fname,"0.1")
    DO AssertGood(fname,"123.456")
    DO AssertGood(fname,"999999.999999")
    DO AssertGood(fname,"10.")
    DO AssertGood(fname,".5")

    WRITE !,"=== Done ",fname," VALID TESTS ===",!
    QUIT


InvalidNumbers(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Negative test suite for IsNum()
    ;   Ensures invalid numeric values are rejected.
    ;
    ; Expected:
    ;   All cases MUST return 0 (invalid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," INVALID CASES ===",!

    ;-----------------------------
    ; Invalid decimal formats
    ;-----------------------------
    DO AssertBad(fname,"1.2.3")

    ;-----------------------------
    ; Non-numeric values
    ;-----------------------------
    DO AssertBad(fname,"abc")

    ;-----------------------------
    ; Unsupported formats
    ;-----------------------------
    DO AssertBad(fname,"1,000")
    DO AssertBad(fname,"1e10")   ; scientific notation not supported

    ;-----------------------------
    ; Signed values
    ;-----------------------------
    DO AssertBad(fname,"-10")
    DO AssertBad(fname,"+10")

    WRITE !,"=== Done ",fname," INVALID TESTS ===",!
    QUIT
    

;------------------------------------------------------------------
; BOOLEAN VALIDATION TEST SUITE
; Valid and invalid test cases for IsBoolean().
;------------------------------------------------------------------
;
ValidBoolean(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Positive test suite for IsBoolean()
    ;
    ; Expected:
    ;   All cases MUST return 1 (valid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," VALID CASES ===",!

    ;-----------------------------
    ; Numeric forms
    ;-----------------------------
    DO AssertGood(fname,"1")
    DO AssertGood(fname,"0")

    ;-----------------------------
    ; Uppercase words
    ;-----------------------------
    DO AssertGood(fname,"TRUE")
    DO AssertGood(fname,"FALSE")
    DO AssertGood(fname,"YES")
    DO AssertGood(fname,"NO")

    ;-----------------------------
    ; Single-letter forms
    ;-----------------------------
    DO AssertGood(fname,"Y")
    DO AssertGood(fname,"N")
    DO AssertGood(fname,"T")
    DO AssertGood(fname,"F")

    ;-----------------------------
    ; Lowercase forms
    ;-----------------------------
    DO AssertGood(fname,"true")
    DO AssertGood(fname,"false")
    DO AssertGood(fname,"yes")
    DO AssertGood(fname,"no")
    DO AssertGood(fname,"y")
    DO AssertGood(fname,"n")
    DO AssertGood(fname,"t")
    DO AssertGood(fname,"f")

    WRITE !,"=== Done ",fname," VALID TESTS ===",!
    QUIT


InvalidBoolean(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Negative test suite for IsBoolean()
    ;
    ; Expected:
    ;   All cases MUST return 0 (invalid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," INVALID CASES ===",!

    ;-----------------------------
    ; Invalid words
    ;-----------------------------
    DO AssertBad(fname,"TRUEE")
    DO AssertBad(fname,"FALSEE")
    DO AssertBad(fname,"YESSS")
    DO AssertBad(fname,"NOPE")
    DO AssertBad(fname,"ON")
    DO AssertBad(fname,"OFF")
    DO AssertBad(fname,"OK")
    DO AssertBad(fname,"NONE")

    ;-----------------------------
    ; Invalid numeric forms
    ;-----------------------------
    DO AssertBad(fname,"2")
    DO AssertBad(fname,"-1")
    DO AssertBad(fname,"10")

    ;-----------------------------
    ; Mixed / corrupted input
    ;-----------------------------
    DO AssertBad(fname,"Y1")
    DO AssertBad(fname,"N0")
    DO AssertBad(fname,"T/F")
    DO AssertBad(fname,"TRUE FALSE")
    DO AssertBad(fname,"F A L S E")

    ;-----------------------------
    ; Empty / whitespace / garbage
    ;-----------------------------
    DO AssertBad(fname,"")
    DO AssertBad(fname," ")
    DO AssertBad(fname,"abc123")
    DO AssertBad(fname,"@")

    WRITE !,"=== Done ",fname," INVALID TESTS ===",!
    QUIT

;------------------------------------------------------------------
; DATE VALIDATION TEST SUITE
; Valid and invalid test cases for IsDate().
;------------------------------------------------------------------
;
ValidDates(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Positive test suite for IsDate()
    ;   Ensures valid ISO date formats are accepted.
    ;
    ; Expected:
    ;   All cases MUST return 1 (valid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," VALID CASES ===",!

    ;-----------------------------
    ; Compact ISO format YYYYMMDD
    ;-----------------------------
    DO AssertGood(fname,"20240101")
    DO AssertGood(fname,"19991231")
    DO AssertGood(fname,"20240229")

    ;-----------------------------
    ; Standard ISO format YYYY-MM-DD
    ;-----------------------------
    DO AssertGood(fname,"2024-01-01")
    DO AssertGood(fname,"1999-12-31")
    DO AssertGood(fname,"2020-02-29")

    ;-----------------------------
    ; Boundary values
    ;-----------------------------
    DO AssertGood(fname,"00010101")
    DO AssertGood(fname,"99991231")

    WRITE !,"=== Done ",fname," VALID TESTS ===",!
    QUIT


InvalidDates(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Negative test suite for IsDate()
    ;   Ensures invalid ISO date formats are rejected.
    ;
    ; Expected:
    ;   All cases MUST return 0 (invalid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," INVALID CASES ===",!

    ;-----------------------------
    ; Format violations
    ;-----------------------------
    DO AssertBad(fname,"2024-13-01")
    DO AssertBad(fname,"2024-00-10")
    DO AssertBad(fname,"2024-01-00")
    DO AssertBad(fname,"2024-01-32")

    ;-----------------------------
    ; Wrong structure
    ;-----------------------------
    DO AssertBad(fname,"2024-1-01")
    DO AssertBad(fname,"2024-01-1")
    DO AssertBad(fname,"2024011")
    DO AssertBad(fname,"2024/01/01")

    ;-----------------------------
    ; Leap year violations
    ;-----------------------------
    DO AssertBad(fname,"2023-02-29")
    DO AssertBad(fname,"1900-02-29")

    ;-----------------------------
    ; Garbage input
    ;-----------------------------
    DO AssertBad(fname,"abcd-ef-gh")
    DO AssertBad(fname,"9999-99-99")
    DO AssertBad(fname,"")
    DO AssertBad(fname," ")

    ;-----------------------------
    ; Mixed corruption
    ;-----------------------------
    DO AssertBad(fname,"2024-02-30")
    DO AssertBad(fname,"2024-04-31")
    DO AssertBad(fname,"2024-06-31")

    WRITE !,"=== Done ",fname," INVALID TESTS ===",!
    QUIT

;------------------------------------------------------------------
; TIME VALIDATION TEST SUITE
; Valid and invalid test cases for IsTime().
;------------------------------------------------------------------
;
ValidTime(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Positive test suite for IsTime()
    ;   Ensures valid ISO 8601 time formats are accepted.
    ;
    ; Expected:
    ;   All cases MUST return 1 (valid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," VALID CASES ===",!

    DO AssertGood(fname,"00:00:00")
    DO AssertGood(fname,"23:59:59")

    ;-----------------------------
    ; UTC designator
    ;-----------------------------
    DO AssertGood(fname,"12:34:56Z")
    DO AssertGood(fname,"00:00:00Z")
    DO AssertGood(fname,"23:59:59Z")

    ;-----------------------------
    ; Fractional seconds
    ;-----------------------------
    DO AssertGood(fname,"12:34:56.1")
    DO AssertGood(fname,"12:34:56.12")
    DO AssertGood(fname,"12:34:56.123")
    DO AssertGood(fname,"12:34:56.1234")
    DO AssertGood(fname,"12:34:56.12345")
    DO AssertGood(fname,"12:34:56.123456")

    ;-----------------------------
    ; Timezone offsets
    ;-----------------------------
    DO AssertGood(fname,"12:34:56+00:00")
    DO AssertGood(fname,"12:34:56+05:30")
    DO AssertGood(fname,"12:34:56-05:30")

    ;-----------------------------
    ; Fraction + timezone
    ;-----------------------------
    DO AssertGood(fname,"12:34:56.123456Z")
    DO AssertGood(fname,"12:34:56.123456+05:30")
    DO AssertGood(fname,"12:34:56.123456-05:30")

    WRITE !,"=== Done ",fname," VALID TESTS ===",!
    QUIT


InvalidTime(fname) ;
    ;--------------------------------------------------------------
    ; Purpose:
    ;   Negative test suite for IsTime()
    ;   Ensures invalid ISO 8601 time formats are rejected.
    ;
    ; Expected:
    ;   All cases MUST return 0 (invalid)
    ;--------------------------------------------------------------

    WRITE !,"=== Testing ",fname," INVALID CASES ===",!

    DO AssertBad(fname,"24:00:00")
    DO AssertBad(fname,"12:60:00")
    DO AssertBad(fname,"12:34:60")

    DO AssertBad(fname,"12:34")
    DO AssertBad(fname,"12:34:5")

    DO AssertBad(fname,"123:45:56")
    DO AssertBad(fname,"12:345:56")
    DO AssertBad(fname,"12:34:567")

    DO AssertBad(fname,"12-34-56")
    DO AssertBad(fname,"12:34:56.")

    DO AssertBad(fname,"12:34:56.1234567")

    DO AssertBad(fname,"12:34:56+24:00")
    DO AssertBad(fname,"12:34:56+01:60")

    DO AssertBad(fname,"12:34:56+0100")
    DO AssertBad(fname,"12:34:56+1:00")
    DO AssertBad(fname,"12:34:56+01")

    DO AssertBad(fname,"12:34:56-24:00")
    DO AssertBad(fname,"12:34:56-01:60")

    DO AssertBad(fname,"12:34:56ABC")
    DO AssertBad(fname,"AB:CD:EF")

    DO AssertBad(fname,"")
    DO AssertBad(fname," ")

    DO AssertBad(fname,"12:34:56Z+")
    DO AssertBad(fname,"Z12:34:56")

    WRITE !,"=== Done ",fname," INVALID TESTS ===",!
    QUIT



