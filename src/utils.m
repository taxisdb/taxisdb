;; ====================================================================================================== 
;; ^utils - Shared helper/utility functions used across TaxisDB Platform - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 		— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;; =======================================================================================================
INIT
	QUIT


FunctionExists(tag,rtn) ; Safely check whether tag^rtn resolves to real source
    ;------------------------------------------------------------------
    ; Purpose:
    ;   Confirms a syntactically-valid Tag^Routine pair actually resolves at runtime. 
    ;   $TEXT returns "" for a missing label; $ETRAP guards against any error during
    ;   lookup (e.g. a routine file that can't be linked).
    ;
    ; Params:
    ;   tag - the tag/label name (already syntax-validated)
    ;   rtn - the routine name (already syntax-validated)    
    ;
    ; Returns:
    ;   1 = tag exists in routine, 0 = not found / any error
    ;------------------------------------------------------------------
    NEW result,src,$ETRAP

    SET result=0
    SET $ETRAP="GOTO FunctionExistsERR^utils"

    SET src=$TEXT(@(tag_"^"_rtn))
    SET result=(src'="")

    IF 'result DO LOGERROR^logger("utils","IsFunction: Routine or label not found — routine `"_rtn_"` may not exist, or tag `"_tag_"` is not defined within it.")

    QUIT result


FunctionExistsERR
    NEW $ETRAP
    SET $ECODE=""
    SET result=0
    QUIT result
    

IsEID(val) ; check if entity ID is structurally valid
;;------------------------------------------------------------------
;; Function  : $$IsEID^utils
;;
;; Purpose   : Check if entity ID is structurally valid.
;;
;;             Structural rules derived from GENID:
;;               - Total length = 13 (hex timestamp) + 7 (base36 suffix) = exactly 20 characters (default RLEN=7)
;;               - First 13 characters are lowercase hex: 0-9, a-f only
;;                 (timestamp produced by EPOCH via $ZCONVERT hex output)
;;               - Last 7 characters are lowercase base36: 0-9, a-z only
;;               - No uppercase characters permitted anywhere
;;
;; Parameters
;;   val    : (IN)  eid string to test
;;
;; Returns   :
;;             1  val is a structurally valid EID — exactly 20 chars,
;;                first 13 lowercase hex, last 7 lowercase base36
;;             0  val fails structural validation
;;------------------------------------------------------------------
    NEW len			; length of val
    NEW ts			; first 13 chars — candidate hex timestamp
    NEW sfx			; last 7 chars — candidate base36 suffix
    NEW hexchars	; allowed lowercase hex character set
    NEW b36chars	; allowed lowercase base36 character set

    ; ------------------------------------------------------------------
    ; Length must be EXACTLY 20 — not "at least 8" as before.
    ; ------------------------------------------------------------------
    SET len=$LENGTH(val)
    IF len'=20 QUIT 0
    ;. DO LOGDEBUG^logger("utils","IsEID: malformed EID — expected 20 chars, got "_len_" — "_val)

    SET ts=$EXTRACT(val,1,13)
    SET sfx=$EXTRACT(val,14,20)

    ; ------------------------------------------------------------------
    ; Prefix — 13 chars, lowercase hex only (0-9,a-f)
    ; ------------------------------------------------------------------
    SET hexchars="0123456789abcdef"
    IF $TRANSLATE(ts,hexchars)'="" DO  QUIT 0
    . DO LOGDEBUG^logger("utils","IsEID: malformed EID — non-hex timestamp segment — "_val)

    ; ------------------------------------------------------------------
    ; Suffix — 7 chars, lowercase base36 only (0-9,a-z)
    ; ------------------------------------------------------------------
    SET b36chars="0123456789abcdefghijklmnopqrstuvwxyz"
    IF $TRANSLATE(sfx,b36chars)'="" DO  QUIT 0
    . DO LOGDEBUG^logger("utils","IsEID: malformed EID — non-base36 suffix segment — "_val)

    DO LOGDEBUG^logger("utils","IsEID: structurally valid — "_val)
    QUIT 1

    
IsFunctionName(val) ; Validate MUMPS extrinsic function reference (e.g. $$Tag^Routine)
    ;------------------------------------------------------------------
    ; Purpose:
    ;   Validates that a value conforms to:
    ;     - $$Tag^Routine
    ;
    ;   Performs:
    ;     - "$$" prefix validation
    ;     - single "^" separator validation (exactly two pieces)
    ;     - tag name validation (starts with uppercase letter, then alphanumeric)
    ;     - routine name validation (starts with letter or "%", then alphanumeric)
    ;     - existence validation (tag actually resolves in routine)
    ;
    ; Returns:
    ;   1 = valid function reference
    ;   0 = invalid function reference (error logged via LOGERROR^logger)
    ;------------------------------------------------------------------
    NEW ref,tag,rtn,ok

    SET ok=1

    ; 1. Prefix validation
    IF ok,$EXTRACT(val,1,2)'="$$" DO
    . DO LOGERROR^logger("utils","IsFunction: Expected value to start with $$ in value: < "_val_" >")
    . SET ok=0

    ; 2. Separator validation - must contain exactly one "^"
    IF ok DO
    . SET ref=$EXTRACT(val,3,$LENGTH(val))
    . IF $LENGTH(ref,"^")'=2 DO
    . . DO LOGERROR^logger("utils","IsFunction: Expected exactly one ^ separating Tag and Routine in value: < "_val_" >")
    . . SET ok=0

    ; 3. Tag name validation - must start with an uppercase letter,
    ;    followed by zero or more alphanumeric characters
    IF ok DO
    . SET tag=$PIECE(ref,"^",1)
    . SET rtn=$PIECE(ref,"^",2)
    . IF tag'?1U.AN DO
    . . DO LOGERROR^logger("utils","IsFunction: Invalid tag name ("_tag_") in value: < "_val_" >")
    . . SET ok=0

    ; 4. Routine name validation - must start with a letter or "%",
    ;    followed by zero or more alphanumeric characters
    IF ok,rtn'?1(1A,1"%").AN DO
    . DO LOGERROR^logger("utils","IsFunction: Invalid routine name ("_rtn_") in value: < "_val_" >")
    . SET ok=0

	; 5. Existence validation - only reached if 1-4 all passed.
    IF ok,'$$FunctionExists(tag,rtn) SET ok=0
    QUIT ok


IsLangStr(val) ; Validate Language-Tagged String
    ;------------------------------------------------------------------
    ; Purpose:
    ;   Ensures the input is a valid language-tagged string.
    ;   A language-tagged string MUST end with @<lang> suffix
    ;   where <lang> is a valid ISO 639 language code (2 or 3 letters)
    ;
    ; Returns:
    ;   1 = valid language-tagged string
    ;   0 = invalid (logged via LOGERROR^logger)
    ;------------------------------------------------------------------
    NEW atpos,strpart,langtag

    ; Must not be empty
    IF val="" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsLangStr: Empty value received")

    ; Must contain @ separator
    IF val'["@" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsLangStr: Missing @ language tag separator in value: < "_val_" >")

    ; Extract string part and lang tag (lang tag is always after the last @)
    S atpos=$L(val,"@")
    S strpart=$P(val,"@",1,atpos-1)
    S langtag=$P(val,"@",atpos)

    ; String part must not be empty
    IF strpart="" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsLangStr: Empty string part in value: < "_val_" >")

    ; Lang tag must not be empty
    IF langtag="" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsLangStr: Empty language tag in value: < "_val_" >")

    ; Lang tag must be 2 or 3 alpha characters only (ISO 639)
    IF langtag'?2.3A DO  QUIT 0
    . DO LOGERROR^logger("utils","IsLangStr: Invalid language code '"_langtag_"' in: < "_val_" >")

    QUIT 1


IsBoolean(val) ; Validate Boolean Value (portable M)
    ;------------------------------------------------------------------
    ; Purpose:
    ;   Validates boolean-like values in a portable way.
    ;
    ; Accepted TRUE:
    ;   1, "1", "TRUE", "YES", "Y", "T"
    ;
    ; Accepted FALSE:
    ;   0, "0", "FALSE", "NO", "N", "F"
    ;
    ; Notes:
    ;   - Case-insensitive (manual normalization)
    ;   - Input assumed pre-trimmed
    ;
    ; Returns:
    ;   1 = valid boolean representation
    ;   0 = invalid (logged via LOGERROR^logger)
    ;------------------------------------------------------------------

    NEW v,i,c,out

    ;-----------------------------
    ; Manual uppercase normalization
    ;-----------------------------
    SET out=""
    FOR i=1:1:$LENGTH(val) DO
    . SET c=$ASCII($EXTRACT(val,i))
    . IF (c>96)&(c<123) SET c=c-32
    . SET out=out_$CHAR(c)

    SET v=out

    ;-----------------------------
    ; TRUE values
    ;-----------------------------
    IF (v=1)!(v="1")!(v="TRUE")!(v="YES")!(v="Y")!(v="T") DO  QUIT 1
    . QUIT

    ;-----------------------------
    ; FALSE values
    ;-----------------------------
    IF (v=0)!(v="0")!(v="FALSE")!(v="NO")!(v="N")!(v="F") DO  QUIT 1
    . QUIT

    ;-----------------------------
    ; Invalid boolean
    ;-----------------------------
    DO LOGERROR^logger("utils","IsBoolean: Invalid boolean value: < "_val_" >")
    QUIT 0


IsDate(val) ; Validate ISO Compact (YYYYMMDD) or ISO Standard (YYYY-MM-DD)
    ;------------------------------------------------------------------
    ; Purpose:
    ;   Validates that a value conforms to either:
    ;     - YYYYMMDD (compact ISO form)
    ;     - YYYY-MM-DD (standard ISO form)
    ;
    ;   Performs:
    ;     - Format validation
    ;     - Numeric component extraction
    ;     - Month validation
    ;     - Day validation
    ;     - Leap year validation
    ;
    ; Returns:
    ;   1 = valid date
    ;   0 = invalid date
    ;------------------------------------------------------------------
    NEW y,m,d,maxDay,leap

    ;--------------------------------------------------------------
    ; 1. Format validation
    ;--------------------------------------------------------------
    IF val?8N DO
    . SET y=$EXTRACT(val,1,4)
    . SET m=$EXTRACT(val,5,6)
    . SET d=$EXTRACT(val,7,8)
    ELSE  IF val?4N1"-"2N1"-"2N DO
    . SET y=$EXTRACT(val,1,4)
    . SET m=$EXTRACT(val,6,7)
    . SET d=$EXTRACT(val,9,10)
    ELSE  DO
    . DO LOGERROR^logger("utils","IsDate: Invalid format in value: < "_val_" >")
    . SET y="",m="",d=""

    IF y="" QUIT 0

    ; Convert strings to numbers
    SET y=+y
    SET m=+m
    SET d=+d

    ;--------------------------------------------------------------
    ; 2. Month validation
    ;--------------------------------------------------------------
    IF (m<1)!(m>12) DO
    . DO LOGERROR^logger("utils","IsDate: Invalid month "_m_" in value: < "_val_" >")
    . SET m=0

    IF m=0 QUIT 0

    ;--------------------------------------------------------------
    ; 3. Determine maximum valid day for month
    ;--------------------------------------------------------------
    SET maxDay=31

    ; 30-day months
    IF (m=4)!(m=6)!(m=9)!(m=11) SET maxDay=30

    ; February
    IF m=2 DO
    . SET leap=0
    .
    . ; Gregorian leap year rule:
    . ; divisible by 400  -> leap
    . ; divisible by 100  -> not leap
    . ; divisible by 4    -> leap
    . ELSE               ;-> not leap
    .
    . IF (y#400)=0 SET leap=1
    . ELSE  IF (y#100)'=0,(y#4)=0 SET leap=1
    .
    . IF leap SET maxDay=29
    . ELSE  SET maxDay=28

    ;--------------------------------------------------------------
    ; 4. Day validation
    ;--------------------------------------------------------------
    IF (d<1)!(d>maxDay) DO
    . DO LOGERROR^logger("utils","IsDate: Invalid day "_d_" for month "_m_" in value: < "_val_" >")
    . SET d=0

    IF d=0 QUIT 0

    ;--------------------------------------------------------------
    ; Valid date
    ;--------------------------------------------------------------
    QUIT 1


IsDecimal(val) ; Validate decimal numeric value
    ;------------------------------------------------------------------
    ; Purpose:
    ;   Validates that a value represents a decimal number.
    ;
    ;   Accepted formats:
    ;     - Integer:        123
    ;     - Negative int:  -123
    ;     - Decimal:       123.45
    ;     - Negative dec: -123.45
    ;
    ;   Rejects:
    ;     - Empty values
    ;     - Non-numeric strings
    ;     - Multiple decimal points
    ;     - Decimal without leading integer part (.5)
    ;     - Decimal without fractional part (12.)
    ;
    ; Returns:
    ;   1 = valid decimal
    ;   0 = invalid decimal (error logged via LOGERROR^logger)
    ;------------------------------------------------------------------
    NEW num,int,frac,dots,dotpos

    ; 1. Empty validation
    IF val="" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsDecimal: Empty value is not a valid decimal")

    SET num=val

    ; 2. Validate optional negative sign
    IF $EXTRACT(num,1)="-" DO
    . SET num=$EXTRACT(num,2,$LENGTH(num))

    IF num="" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsDecimal: Missing numeric value in < "_val_" >")

    ; Negative sign not allowed elsewhere
    IF num["-" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsDecimal: Invalid negative sign placement in value: < "_val_" >")

    ; 3. Count decimal separators
    SET dots=$LENGTH(num,".")-1

    IF dots>1 DO  QUIT 0
    . DO LOGERROR^logger("utils","IsDecimal: Multiple decimal separators in value: < "_val_" >")

    ; 4. Split integer and fraction parts
    SET dotpos=$FIND(num,".")

    IF dotpos DO
    . SET int=$PIECE(num,".",1)
    . SET frac=$PIECE(num,".",2)
    ELSE  DO
    . SET int=num
    . SET frac=""

    ; 5. Integer part validation
    IF int="" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsDecimal: Missing integer part in value: < "_val_" >")

    IF int'?1.N DO  QUIT 0
    . DO LOGERROR^logger("utils","IsDecimal: Invalid integer part in value: < "_val_" >")

    ; 6. Fraction validation
    IF dotpos,(frac="") DO  QUIT 0
    . DO LOGERROR^logger("utils","IsDecimal: Missing fractional part in value: < "_val_" >")

    IF dotpos,(frac'?1.N) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsDecimal: Invalid fractional part in value: < "_val_" >")

    QUIT 1


IsPoint(val) ; Validate WKT POINT (longitude latitude)
    ;------------------------------------------------------------------
    ; Purpose:
    ;   Validates that a value conforms to:
    ;     - POINT (longitude latitude)
    ;
    ;   Performs:
    ;     - WKT syntax validation
    ;     - longitude range validation (-180 to 180)
    ;     - latitude range validation (-90 to 90)
    ;
    ; Returns:
    ;   1 = valid point
    ;   0 = invalid point (error logged via LOGERROR^logger)
    ;------------------------------------------------------------------
    NEW coords,lon,lat

    ; 1. Format validation
    IF val'?1"POINT ("1.E1")" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsPoint: Expected WKT POINT (longitude latitude) format in value: < "_val_" >")

    ; 2. Extract coordinates
    SET coords=$PIECE($PIECE(val,"(",2),")",1)

    ; POINT must contain exactly 2 coordinates
    IF $LENGTH(coords," ")'=2 DO  QUIT 0
    . DO LOGERROR^logger("utils","IsPoint: POINT requires exactly longitude and latitude coordinates in value: < "_val_" >")

    SET lon=$PIECE(coords," ",1)
    SET lat=$PIECE(coords," ",2)

    ; 3. Coordinate validation
    IF '$$IsDecimal(lon) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsPoint: Invalid longitude value ("_lon_") in value: < "_val_" >")

    IF '$$IsDecimal(lat) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsPoint: Invalid latitude value ("_lat_") in value: < "_val_" >")

    ; 4. Longitude range
    IF (lon<-180)!(lon>180) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsPoint: Longitude outside valid range (-180..180) in value: < "_val_" >")

    ; 5. Latitude range
    IF (lat<-90)!(lat>90) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsPoint: Latitude outside valid range (-90..90) in value: < "_val_" >")

    QUIT 1


IsPointZ(val) ; Validate WKT POINT Z (longitude latitude altitude)
    ;------------------------------------------------------------------
    ; Purpose:
    ;   Validates that a value conforms to:
    ;     - POINT Z (longitude latitude altitude)
    ;
    ;   Performs:
    ;     - WKT syntax validation
    ;     - coordinate count validation
    ;     - longitude range validation (-180 to 180)
    ;     - latitude range validation (-90 to 90)
    ;     - altitude numeric validation
    ;
    ; Returns:
    ;   1 = valid point Z
    ;   0 = invalid point Z (error logged via LOGERROR^logger)
    ;------------------------------------------------------------------
    NEW coords,lon,lat,alt

    ; 1. Format validation
    IF val'?1"POINT Z ("1.E1")" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsPointZ: Expected WKT POINT Z (longitude latitude altitude) format in value: < "_val_" >")

    ; 2. Extract coordinates
    SET coords=$PIECE($PIECE(val,"(",2),")",1)

    ; POINT Z must contain exactly 3 coordinates
    IF $LENGTH(coords," ")'=3 DO  QUIT 0
    . DO LOGERROR^logger("utils","IsPointZ: POINT Z requires exactly longitude latitude altitude coordinates in value: < "_val_" >")

    SET lon=$PIECE(coords," ",1)
    SET lat=$PIECE(coords," ",2)
    SET alt=$PIECE(coords," ",3)

    ; 3. Longitude validation
    IF '$$IsDecimal(lon) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsPointZ: Invalid longitude value ("_lon_") in value: < "_val_" >")

    IF (lon<-180)!(lon>180) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsPointZ: Longitude outside valid range (-180..180) in value: < "_val_" >")

    ; 4. Latitude validation
    IF '$$IsDecimal(lat) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsPointZ: Invalid latitude value ("_lat_") in value: < "_val_" >")

    IF (lat<-90)!(lat>90) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsPointZ: Latitude outside valid range (-90..90) in value: < "_val_" >")

    ; 5. Altitude validation
    IF '$$IsDecimal(alt) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsPointZ: Invalid altitude value ("_alt_") in value: < "_val_" >")

    QUIT 1


IsGPS(val) ; Validate GPS coordinate pair (latitude, longitude)
    ;------------------------------------------------------------------
    ; Purpose:
    ;   Validates a GPS geographic coordinate pair represented as:
    ;
    ;       (latitude, longitude)
    ;
    ;   Performs:
    ;     - format validation
    ;     - coordinate count validation
    ;     - latitude validation (-90..90)
    ;     - longitude validation (-180..180)
    ;
    ; Returns:
    ;   1 = valid GPS coordinate pair
    ;   0 = invalid GPS coordinate pair (error logged via LOGERROR^logger)
    ;------------------------------------------------------------------
    NEW coords,lat,lon

    ; 1. Format validation
    IF val'?1"("1.E1")" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsGPS: Expected GPS format (latitude, longitude) in value: < "_val_" >")

    ; 2. Extract coordinates
    SET coords=$PIECE($PIECE(val,"(",2),")",1)
    
    ; 3. Remove spaces
	SET coords=$TRANSLATE(coords," ","")

    ; GPS requires exactly two comma-separated values
    IF $LENGTH(coords,",")'=2 DO  QUIT 0
    . DO LOGERROR^logger("utils","IsGPS: Expected latitude and longitude coordinates in value: < "_val_" >")

    SET lat=$PIECE(coords,",",1)
    SET lon=$PIECE(coords,",",2)

    ; 4. Latitude validation
    IF '$$IsDecimal(lat) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsGPS: Invalid latitude value ("_lat_") in value: < "_val_" >")

    IF (lat<-90)!(lat>90) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsGPS: Latitude outside valid range (-90..90) in value: < "_val_" >")

    ; 5. Longitude validation
    IF '$$IsDecimal(lon) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsGPS: Invalid longitude value ("_lon_") in value: < "_val_" >")

    IF (lon<-180)!(lon>180) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsGPS: Longitude outside valid range (-180..180) in value: < "_val_" >")

    QUIT 1


IsInt(val) ; Validate Integer
    ;------------------------------------------------------------------
    ; Purpose:
    ;   Ensures the input is a strict integer (no decimals, no signs,
    ;   no scientific notation).
    ;
    ; Returns:
    ;   1 = valid integer
    ;   0 = invalid (logged via LOGERROR^logger)
    ;------------------------------------------------------------------
    IF val'?1.N DO  QUIT 0
    . DO LOGERROR^logger("utils","IsInt: Expected integer value, received: < "_val_" >")

    QUIT 1


IsURL(val) ; Validate URL
    ;------------------------------------------------------------------
    ; Purpose:
    ;   Ensures the input is a valid URL with scheme, host and
    ;   optional path/query/fragment.
    ;
    ;   Accepted schemes : http, https
    ;   Rejected         : empty, no scheme, no host, spaces
    ;
    ; Returns:
    ;   1 = valid URL
    ;   0 = invalid (logged via LOGERROR^logger)
    ;------------------------------------------------------------------
    NEW rest,host,hostTmp,seg,i

    ; Must not be empty
    IF val="" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsURL: Empty value received")

    ; Must not contain spaces
    IF val[" " DO  QUIT 0
    . DO LOGERROR^logger("utils","IsURL: URL contains spaces: < "_val_" >")

    ; Must start with http:// or https://
    IF val'?1"http"0.1(1"s")1"://"1.ANP DO  QUIT 0
    . DO LOGERROR^logger("utils","IsURL: Missing or invalid scheme in value: < "_val_" >")

    ; Extract everything after the scheme
    IF val["https://" S rest=$P(val,"https://",2)
    ELSE  S rest=$P(val,"http://",2)

    ; Extract host (everything before first / ? or #)
    S host=$P($P($P(rest,"/",1),"?",1),"#",1)

    ; Host must not be empty
    IF host="" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsURL: Missing host in value: < "_val_" >")

    ; Host must contain at least one dot
    IF host'["." DO  QUIT 0
    . DO LOGERROR^logger("utils","IsURL: Host missing dot separator: < "_host_" >")

    ; Host must not start or end with a dot
    IF $E(host,1)="." DO  QUIT 0
    . DO LOGERROR^logger("utils","IsURL: Host starts with dot: < "_host_" >")
    IF $E(host,$L(host))="." DO  QUIT 0
    . DO LOGERROR^logger("utils","IsURL: Host ends with dot: < "_host_" >")

    ; Check each label segment does not start or end with hyphen
    NEW %err
    S %err=0
    S hostTmp=host
    FOR i=1:1 Q:hostTmp=""  D
    . S seg=$P(hostTmp,".",1)
    . S hostTmp=$P(hostTmp,".",2,$L(hostTmp,"."))
    . IF $E(seg,1)="-" S %err=1 D
    . . DO LOGERROR^logger("utils","IsURL: Host segment starts with hyphen: < "_seg_" >")
    . IF $E(seg,$L(seg))="-" S %err=1 D
    . . DO LOGERROR^logger("utils","IsURL: Host segment ends with hyphen: < "_seg_" >")

    IF %err QUIT 0

    QUIT 1
    

IsAlphaNum(val) ; Validate Alphanumeric strings that are safe to use as @alias in indirection
    ;------------------------------------------------------------------
    ; Purpose:
    ;   Validates that the value is a valid MUMPS local variable name
    ;   suitable for use as an alias via indirection in LoadKeywords.
    ;
    ;   Rules:
    ;     - Optional leading % (one only)
    ;     - Remaining characters must be letters or digits only
    ;     - No underscores, dots, spaces, or special characters
    ;
    ; Returns:
    ;   1 = valid alias (safe to use as @alias in indirection)
    ;   0 = invalid (logged via LOGERROR^logger)
    ;------------------------------------------------------------------
    NEW stripped,check
    SET check=val

    ; Strip optional leading % (one only)
    IF $EXTRACT(check,1)="%" SET check=$EXTRACT(check,2,$LENGTH(check))

    ; Remaining must be letters and digits only
    SET stripped=$TRANSLATE(check,"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789","")
    IF stripped'="" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsAlphaNum: Expected %+alphanumeric only, received: < "_val_" >")

    ; Must not be empty after stripping %
    IF check="" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsAlphaNum: Alias is empty or just '%': < "_val_" >")

    QUIT 1


IsAlpha(val) ; Validate Alphabetic only
    ;------------------------------------------------------------------
    ; Purpose:
    ;   Validates that the value contains only alphabetic characters.
    ;   No digits, spaces, punctuation, or symbols allowed.
    ;
    ; Returns:
    ;   1 = valid alphabetic string
    ;   0 = invalid (logged via LOGERROR^logger)
    ;------------------------------------------------------------------
    IF val'?1.A DO  QUIT 0
    . DO LOGERROR^logger("utils","IsAlpha: Expected alphabetic text only, received value: < "_val_" >")

    QUIT 1


IsNum(val) ; Validate MUMPS numeric value
    ;------------------------------------------------------------------
    ; Purpose:
    ;   Validates MUMPS numeric literals.
    ;
    ;   Supported:
    ;     123
    ;     123.
    ;     .123
    ;     123.456
    ;
    ;   Not supported:
    ;     +123
    ;     -123
    ;     1e10
    ;     1,000
    ;
    ; Returns:
    ;   1 = valid numeric
    ;   0 = invalid
    ;------------------------------------------------------------------

    NEW left,right,dots

    IF val="" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsNum: Expected numeric value, received null value: < "_val_" >")

    ; No more than one decimal point
    SET dots=$LENGTH(val,".")-1

    IF dots>1 DO  QUIT 0
    . DO LOGERROR^logger("utils","IsNum: Multiple decimal points in value: < "_val_" >")

    SET left=$PIECE(val,".",1)
    SET right=$PIECE(val,".",2)

    ; Validate left side if present
    IF left'="" DO
    . IF left'?1.N SET left="INVALID"

    IF left="INVALID" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsNum: Expected numeric value, received value: < "_val_" >")

    ; Validate right side if present
    IF right'="" DO
    . IF right'?1.N SET right="INVALID"

    IF right="INVALID" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsNum: Expected numeric value, received value: < "_val_" >")

    ; Reject "." alone
    IF (left="")&(right="") DO  QUIT 0
    . DO LOGERROR^logger("utils","IsNum: Expected numeric value, received value: < "_val_" >")

    QUIT 1
       


IsTime(val) ; Validate ISO 8601 Time
    ;------------------------------------------------------------------
    ; Purpose:
    ;   Validates ISO 8601 time values in the following forms:
    ;
    ;     HH:MM:SS
    ;     HH:MM:SSZ
    ;     HH:MM:SS.ffffff
    ;     HH:MM:SS.ffffffZ
    ;     HH:MM:SS+HH:MM
    ;     HH:MM:SS-HH:MM
    ;     HH:MM:SS.ffffff+HH:MM
    ;     HH:MM:SS.ffffff-HH:MM
    ;
    ;   Fractional seconds are optional and support
    ;   1-6 digits of precision.
    ;
    ;   Timezone designators:
    ;     Z         UTC
    ;     +HH:MM    Positive UTC offset
    ;     -HH:MM    Negative UTC offset
    ;
    ; Returns:
    ;   1 = Valid
    ;   0 = Invalid (error logged)
    ;------------------------------------------------------------------

    NEW hh,mm,ss
    NEW rest,frac,tz
    NEW offH,offM

    
    ; Minimum length HH:MM:SS
    IF $LENGTH(val)<8 DO  QUIT 0
    . DO LOGERROR^logger("utils","IsTime: Invalid ISO 8601 time format in value: < "_val_" >")

    ; Validate separators
    IF $EXTRACT(val,3)'=":" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsTime: Invalid ISO 8601 time format: < "_val_" >")
    IF $EXTRACT(val,6)'=":" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsTime: Invalid ISO 8601 time format: < "_val_" >")
    
    ; Extract HH MM SS
    SET hh=$EXTRACT(val,1,2)
    SET mm=$EXTRACT(val,4,5)
    SET ss=$EXTRACT(val,7,8)

    IF hh'?2N DO  QUIT 0
    . DO LOGERROR^logger("utils","IsTime: Invalid hour value in value < "_val_" >")
    IF mm'?2N DO  QUIT 0
    . DO LOGERROR^logger("utils","IsTime: Invalid minute value in value < "_val_" >")
    IF ss'?2N DO  QUIT 0
    . DO LOGERROR^logger("utils","IsTime: Invalid second value in value < "_val_" >")

    ; Validate ranges
    IF (hh<0)!(hh>23) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsTime: Hour out of range < "_hh_" >")
    IF (mm<0)!(mm>59) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsTime: Minute out of range < "_mm_" >")
    IF (ss<0)!(ss>59) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsTime: Second out of range < "_ss_" >")

    ; Remaining content after HH:MM:SS
    SET rest=$EXTRACT(val,9,$LENGTH(val))

    ; No fractional seconds / timezone
    IF rest="" QUIT 1

    ; UTC designator only
    IF rest="Z" QUIT 1

    ; Fractional seconds
    IF $EXTRACT(rest,1)="." DO
    . SET frac=$EXTRACT(rest,2,$LENGTH(rest))
    . SET tz=""
    . IF frac["Z" DO
    . . SET tz="Z"
    . . SET frac=$PIECE(frac,"Z",1)
    . IF tz="",frac["+" DO
    . . SET tz="+"_$PIECE(frac,"+",2)
    . . SET frac=$PIECE(frac,"+",1)
    . IF tz="",frac["-" DO
    . . SET tz="-"_$PIECE(frac,"-",2)
    . . SET frac=$PIECE(frac,"-",1)
    . IF frac'?1.6N DO  QUIT
    . . DO LOGERROR^logger("utils","IsTime: Invalid fractional second precision in value < "_val_" >")
    . . SET rest="INVALID"
    . SET rest=tz

    IF rest="INVALID" QUIT 0

    ; No timezone after fractional seconds
    IF rest="" QUIT 1

    ; UTC designator after fractional seconds
    IF rest="Z" QUIT 1

    ; Validate timezone offset
    ; Format: +HH:MM or -HH:MM
    IF $LENGTH(rest)'=6 DO  QUIT 0
    . DO LOGERROR^logger("utils","IsTime: Invalid timezone offset format in value < "_val_" >")

    IF ($EXTRACT(rest,1)'="+")&($EXTRACT(rest,1)'="-") DO  QUIT 0
    . DO LOGERROR^logger("utils","IsTime: Invalid timezone designator in value < "_val_" >")

    IF $EXTRACT(rest,4)'=":" DO  QUIT 0
    . DO LOGERROR^logger("utils","IsTime: Invalid timezone offset format in value <"_val_" >")

    SET offH=$EXTRACT(rest,2,3)
    SET offM=$EXTRACT(rest,5,6)

    IF offH'?2N DO  QUIT 0
    . DO LOGERROR^logger("utils","IsTime: Invalid timezone hour offset in value < "_val_" >")

    IF offM'?2N DO  QUIT 0
    . DO LOGERROR^logger("utils","IsTime: Invalid timezone minute offset in value < "_val_" >")

    IF (offH<0)!(offH>23) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsTime: Timezone hour offset out of range < "_offH_" >")

    IF (offM<0)!(offM>59) DO  QUIT 0
    . DO LOGERROR^logger("utils","IsTime: Timezone minute offset out of range <"_offM_" >")

    QUIT 1


InRange(val,min,max) ; Validate value bounds
    ;------------------------------------------------------------------
    ; Purpose:
    ;   Ensures that a numeric value lies within an inclusive range.
    ;
    ;   This is a generic constraint validator used for:
    ;     - bounded integers
    ;     - bounded numeric values
    ;     - schema-enforced range restrictions
    ;
    ; Returns:
    ;   1 = value is within [min,max]
    ;   0 = value is out of bounds (logged via LOGERROR^logger)
    ;
    ; Notes:
    ;   - Assumes val, min, max are already numeric or comparable
    ;   - Does not perform type validation (use IsInt/IsNum first)
    ;------------------------------------------------------------------

    IF (val<min)!(val>max) DO  QUIT 0
    . DO LOGERROR^logger("utils","InRange: Value out of bounds ("_min_"-"_max_") received value: < "_val_" >")

    QUIT 1


DOC(label,routine)
	;;------------------------------------------------------------------
	;; Routine  : Doc
	;; Type     : Procedure
	;; Purpose  : Prints the documentation block of a given routine
	;;            entry point to the console. Automatically detects
	;;            the end of the ;; doc block by scanning lines until
	;;            a non-;; line is encountered, eliminating the need
	;;            for a caller-supplied offset.
	;;
	;; Parameters
	;;   label   : (IN) Entry point label within the target routine.
	;;                  Example: "SchemaInit"
	;;   routine : (IN) Name of the target routine (without ^ prefix).
	;;                  Example: "init"
	;;
	;; Returns  : None
	;;
	;; Call     : DO Doc("SchemaInit","init")
	;;
	;; Notice   : Doc block must use ;; (double semicolon) prefix
	;;            on every documentation line — single
	;;------------------------------------------------------------------
	NEW baseRef,line,offset,text

	; Build $TEXT reference as complete string: label+N^routine
	SET offset=1
	FOR  DO  QUIT:text'[";;"
	. SET baseRef=label_"+"_offset_"^"_routine
	. SET line=$TEXT(@baseRef)
	. SET text=$EXTRACT(line,1,2)
	. IF text=";;" DO
	. . WRITE $PIECE(line,";;",2,$LENGTH(line,";;")),!
	. . SET offset=offset+1

	QUIT


;============================================================================
; ID ROUTINES
;============================================================================
;
IDDT(ID) 
;;------------------------------------------------------------------
;; Routine  : IDDT Function
;;
;; Call     : WRITE $$IDDT^<routine>(ID)
;;
;; Usage    :
;;   SET TS=$$IDDT^<routine>(ID)
;;
;; Purpose  :
;;   Extracts the timestamp portion of a GENID value and converts
;;   it into a human-readable ISO datetime string with
;;   microsecond precision.
;;
;;   The function assumes the GENID format begins with a
;;   13-character hexadecimal timestamp generated by $$EPOCH.
;;
;; Scope
;;   Reads  : $$DATETIME
;;   Writes : timepart (local variable)
;;
;; Parameters
;;   ID     : (IN)
;;             A GENID value containing a 13-character hexadecimal
;;             timestamp prefix.
;;
;; Returns  :
;;   An ISO-8601 formatted timestamp string with microsecond
;;   precision.
;;
;;   Example:
;;     2026-04-29T15:31:07.408218
;;
;; Notice   :
;;   - Only the first 13 characters of the ID are used.
;;   - Assumes the ID was generated using the GENID/EPOCH format.
;;   - Requires the DATETIME function to be available in the
;;     same routine or namespace.
;;
;;------------------------------------------------------------------
    NEW timepart    
    ; 1. Extract 13 characters to match the 13-char Hex timestamp
    SET timepart=$E(ID,1,13)
    QUIT $$DATETIME(timepart)




GENID(RLEN) ; Generate a Time-Sorted Compact ID (KSUID-style)
;;------------------------------------------------------------------
;; Routine  : GENID Function
;;
;; Call     : WRITE $$GENID^<routine>(RLEN)
;;
;; Usage    :
;;   SET ID=$$GENID^<routine>()
;;   SET ID=$$GENID^<routine>(10)
;;
;; Purpose  :
;;   Generates a compact, chronologically sortable unique identifier
;;   similar in concept to a KSUID.
;;
;;   The identifier consists of:
;;     - A 13-character hexadecimal timestamp prefix generated
;;       by $$EPOCH
;;     - A random Base36 suffix of configurable length
;;
;;   This structure preserves time ordering while reducing the
;;   likelihood of collisions between generated IDs.
;;
;; Scope
;;   Reads  : $$EPOCH, $RANDOM
;;   Writes : CHARSET, RAND, I, POS, RLEN (local variables)
;;
;; Parameters
;;   RLEN   : (IN)
;;             Length of the random Base36 suffix.
;;             Defaults to 7 if not supplied.
;;
;; Returns  :
;;   A lowercase time-sorted identifier in the format:
;;
;;     [Hex Timestamp(13)][Random Base36 Suffix(RLEN)]
;;
;;   Example:
;;     66a1f4c9d2e7b4k9x2qa
;;
;; Notice   :
;;   - Uses Base36 characters: 0-9 and a-z.
;;   - Timestamp ordering allows IDs to sort chronologically.
;;   - Collision probability depends on suffix length and
;;     generation frequency within the same microsecond.
;;   - Requires the EPOCH function to be available in the
;;     same routine or namespace.
;;
;;------------------------------------------------------------------ 
    NEW CHARSET,RAND,I,POS
    
    ; Ensure RLEN has a value; default to 7 if not provided
    SET RLEN=$G(RLEN,7)    
        
    ; Define the character set for the random suffix (Base36: 0-9, a-z)
    SET CHARSET="0123456789abcdefghijklmnopqrstuvwxyz"
    SET RAND=""
    
    ; Generate the random portion of the ID
    ; This provides the entropy needed to prevent collisions in the same ms
    FOR I=1:1:RLEN DO
    . SET POS=$RANDOM($L(CHARSET))+1
    . SET RAND=RAND_$E(CHARSET,POS)
    
    ; Concatenate and return the result in lowercase
    ; The result is [Timestamp(13)][Random(RLEN)]
    QUIT $$EPOCH_RAND
    

UUID4() ; Generate a UUID v4 (Random Version)
    NEW RAND,V4,I
    
    ; 1. Generate 32 hex characters of randomness
    SET RAND=""
    FOR I=1:1:32 SET RAND=RAND_$ZCONVERT($RANDOM(16),"DEC","HEX")
    
    ; 2. Assemble and force Version (4) and Variant (8)
    ; Format: 8-4-4-4-12
    ; Position 13 (start of 3rd block) is '4'
    ; Position 17 (start of 4th block) is '8'
    
    SET V4=$E(RAND,1,8)_"-"_$E(RAND,9,12)_"-4"_$E(RAND,14,16)
    SET V4=V4_"-8"_$E(RAND,18,20)_"-"_$E(RAND,21,32)
    
    QUIT $ZCONVERT(V4,"L")


;============================================================================
; DATE/TIME ROUTINES
;============================================================================
;	
DATETIME(epochhex)
	NEW US,USR,SECONDS,DAYS,SECS,ISO,TS
	; Convert HEX to DEC
	SET US=$ZCONVERT(epochhex,"hex","dec")
	; 2. Convert Microseconds to Seconds and the microsecond remainder (USR)
    SET SECONDS=US\1000000
    SET USR=US#1000000    
    ; 3. Convert Unix to MUMPS Horolog (Offset 47117)
    SET DAYS=(SECONDS\86400)+47117
    SET SECS=SECONDS#86400
    SET TS=DAYS_","_SECS    
    ; 4. Using your ZDATE logic, updated to show full 6-digit microseconds
    ; Changed $J(MSR,3) to $J(USR,6) and removed the hardcoded "000"
    SET ISO=$ZDATE(TS,"YEAR-MM-DD")_"T"_$ZDATE(TS,"24:60:SS")_"."_$TR($J(USR,6)," ","0")
    ; Return UTC datetime in ISO‑8601 formatting
    QUIT ISO
	

EPOCH()
;;------------------------------------------------------------------
;; Routine  : EPOCH Function
;;
;; Call     : WRITE $$EPOCH^<routine>
;;
;; Purpose  :
;;   Generates a hexadecimal representation of the current
;;   Unix/Universal timestamp in microseconds.
;;
;;   The timestamp is converted from decimal to hexadecimal,
;;   transformed to lowercase, and returned as a unique
;;   13-character string.
;;
;; Returns  :
;;   A lowercase hexadecimal string representing the current
;;   timestamp in microseconds.
;;
;; Notice   :
;;   - Uses YottaDB special variable $ZUT.
;;------------------------------------------------------------------
	NEW HEXUS
	; Convert the Unix/Universal timestamp in microseconds to a 13-character Hexadecimal string    
    SET HEXUS=$ZCONVERT($ZUT,"dec","hex")
    ; Convert it to lower case and return it
    QUIT $ZCONVERT(HEXUS,"L")
	

UNIXMS() 
 	; Get Unix Epoch (UT- Universal/Unix Time) in microseconds
    ; $ZUT returns the number of microseconds since January 1, 1970 00:00:00 UTC
    ; We divide by 1000 to get milliseconds
    QUIT $ZUT\1000



PRUNE(ROOTREF) ;
    ; Description:
    ;   Deletes all descendant nodes under a given global node,
    ;   while preserving the value of the parent node itself.
    ;
    ; Parameters:
    ;   ROOTREF (by name, required)
    ;     - Closed root reference to the node you want to prune
    ;     - Must be passed by name using indirection
    ;     - Example: "^Employee(""id"",""skills"",3)"
    ;
    ; Returns:
    ;   1  = Success (node existed or was processed)
    ;   0  = Invalid reference or error condition
    ;
    ; Behavior:
    ;   - If ROOTREF has a value, it is preserved
    ;   - All subnodes beneath ROOTREF are deleted
    ;   - If ROOTREF has no value but has descendants, the subtree is removed
    ;   - If ROOTREF does not exist at all, no action is taken
    ;
    ; Notes / Notices:
    ;   - YottaDB / GT.M does NOT support the "*,*" style wildcard KILL
    ;   - A plain KILL removes the node AND all descendants
    ;   - This routine works around that by saving/restoring the node value
    ;   - ROOTREF must be a valid, fully-qualified global reference
    ;   - No locking is performed — caller is responsible for concurrency control
    ;   - Large subtrees may incur performance cost due to full KILL
    ;
    ; Example Usage:
    ;   DO PRUNE^utils("^Employee(""6509e00ddfe4271afadmw"",""skills"",3)")
    ;
    ; ------------------------------------------------------------	 
    NEW $ETRAP,$ESTACK
    SET $ETRAP="DO LOGERROR^logger(""UTILS"",""PRUNE: Runtime error"") SET $ECODE="""" QUIT 0"

    NEW val,exists

    ; Validate input
    IF $GET(ROOTREF)="" DO LOGERROR^logger("utils","PRUNE: ROOTREF is empty") QUIT 0
    IF ROOTREF'?1"^".E DO LOGERROR^logger("utils","PRUNE: Invalid global reference: "_ROOTREF) QUIT 0

    ; Check if node exists (value or descendants)
    SET exists=$DATA(@ROOTREF)
    IF exists=0 DO LOGERROR^logger("utils","PRUNE: Node does not exist: "_ROOTREF) QUIT 0

    ; Save value if present
    IF exists#2 DO
    . SET val=@ROOTREF
    ELSE  DO
    . SET val=""

    ; Kill entire subtree (node + descendants)
    KILL @ROOTREF

    ; Restore value if it existed
    IF val'="" DO
    . SET @ROOTREF=val

    QUIT 1

Export(glob)
    ; Export a global to a .zwr file on disk
    ; glob = name of the global (with or without leading "^")
    NEW file,ref
    IF glob="" WRITE "Error: no global name supplied",! QUIT

    ; strip a leading "^" if the caller included one
    IF $EXTRACT(glob,1)="^" SET glob=$EXTRACT(glob,2,$LENGTH(glob))
    SET ref="^"_glob

    ; bail out if the global doesn't actually exist
    IF '$DATA(@ref) WRITE "Error: global "_ref_" is undefined",! QUIT

    SET file="Octo/"_glob_".zwr"

    OPEN file:NEW USE file

    WRITE "YottaDB MUPIP EXTRACT UTF-8",!
    WRITE $ZD($H,"DD-MON-YEAR 24:60:SS")," ZWR",!

    ZWRITE @ref

    CLOSE file
    ; back on the console now that the file is closed
    WRITE file_" has been successfully created",!
    QUIT
    
    
Octo(fname)
    ; Load <fname>.zwr into the database via MUPIP, then apply
    ; <fname>.sql against it via Octo.
    ;
    ; fname = base name (no extension) shared by both files,
    ;         e.g. "EATV" for EATV.zwr and EATV.sql
    NEW zwr,sql,cmd

    IF fname="" WRITE "Error: no file name supplied",! QUIT
	
    SET zwr="Octo/"_fname_".zwr"
    SET sql="Octo/"_fname_".sql"

    ; bail out early if either input file is missing
    IF '$$FileExists(zwr) WRITE "Error: "_zwr_" not found",! QUIT
    IF '$$FileExists(sql) WRITE "Error: "_sql_" not found",! QUIT

    ; MUPIP LOAD the extract into the database
    SET cmd="mupip load "_zwr
    WRITE "Running: "_cmd,!
    ZSYSTEM cmd
    IF $ZSYSTEM'=0 WRITE "Error: mupip load failed, exit status "_$ZSYSTEM,! QUIT

    ; apply the Octo table definition
    SET cmd="octo -f "_sql
    WRITE "Running: "_cmd,!
    ZSYSTEM cmd
    IF $ZSYSTEM'=0 WRITE "Error: octo -f failed, exit status "_$ZSYSTEM,! QUIT

    WRITE fname_" loaded and schema applied successfully",!
    QUIT


FileExists(file)
    NEW dummy,found
    SET dummy=$ZSEARCH("",0)
    SET found=$ZSEARCH(file)
    QUIT found'=""
    

MapOp(op)
    ; op = 0 (retraction) or 1 (assertion)
    ; returns "R" or "A" respectively
    QUIT $SELECT(op=1:"A",1:"R")