;; ================================================================================== 
;; ^testOther - Other auxiliary test - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 		— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;; ===================================================================================

INIT
	QUIT


BuildTestG ; populate ^G with sample (eid,aid,tx,val,op) datoms for CurrentDatom testing
    KILL ^G

    SET ^G("Alice","salary",7418,"$1200")=1
    SET ^G("Alice","salary",7420,"$1200")=0
    SET ^G("Alice","salary",7420,"$1800")=1

    SET ^G("Bob","salary",7401,"$1000")=1
    SET ^G("Bob","salary",7410,"$1000")=0
    SET ^G("Bob","salary",7410,"$1200")=1
    SET ^G("Bob","salary",7420,"$1200")=0
    SET ^G("Bob","salary",7420,"$1500")=1

    SET ^G("Fred","salary",7420,"$2200")=1

    SET ^G("John","salary",7406,"$1400")=1
    SET ^G("John","salary",7420,"$1400")=0

    QUIT



CheckTBD(attrid)
    ;;------------------------------------------------------------
    ;; Verify that:
    ;;   ^TBD(attrid,valkey)=value
    ;; matches:
    ;;   ^TBDR(attrid,value)=valkey
    ;;------------------------------------------------------------

    NEW valkey,desc,rev,cnt,err

    SET (cnt,err)=0

    WRITE !!,"Checking ^TBD("_attrid_") <-> ^TBDR("_attrid_")",!

    SET valkey=""

    FOR  SET valkey=$ORDER(^TBD(attrid,valkey)) QUIT:valkey=""  DO
    . ; Skip node count
    . IF valkey?1N.N QUIT
    .
    . SET cnt=cnt+1
    . SET desc=$GET(^TBD(attrid,valkey))
    . SET rev=$GET(^TBDR(attrid,desc))
    .
    . IF rev'=valkey DO
    . . SET err=err+1
    . . WRITE !
    . . WRITE "Mismatch",!
    . . WRITE "  ^TBD("_attrid_",""",valkey,""")=",desc,!
    . . WRITE "  ^TBDR("_attrid_",desc)=",rev,!
    . . WRITE "  Expected: ",valkey,!
    . ELSE  DO
    . . WRITE !,"OK  ",valkey

    WRITE !!
    WRITE "Checked : ",cnt,!
    WRITE "Errors  : ",err,!!

    QUIT
    

CountTBDR
    NEW global,sub1,sub2,count

    SET global="^TBDR"
    SET count=0

    SET sub1=""

    FOR  SET sub1=$ORDER(@global@(sub1)) QUIT:sub1=""  DO
    . SET sub2=""
    . FOR  SET sub2=$ORDER(@global@(sub1,sub2)) QUIT:sub2=""  DO
    . . SET count=count+1

    WRITE !,"TOTAL ^TBDR ENTRIES: ",count,!

    QUIT