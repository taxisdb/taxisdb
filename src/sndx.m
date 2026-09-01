;; ============================================================================================= 
;; ^sndx - Build TBox/Schema indexes part of the boostrap process - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 	— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;; =============================================================================================

INIT
	; All TBox system entities occupy IDS from 1 to 999.
	; User defined data type schema entities start from 1000
	SET TBSYSCNT=999
	QUIT



BuildAttrRange(MD)
;;------------------------------------------------------------------
;; Routine  : BuildAttrRange
;; Purpose  : Loads EAV terms and simultaneously builds the
;;            attribute-value data type index (^TBD / ^TBDR)
;;
;; Scope
;;   Reads  : MD(eid,aid)          	 — input EAV structure: : metadata entity (term), metadata attribute
;;   Writes : ^TBD(aid,key)=val      — forward data type index
;;            ^TBDR(aid,val)=key     — reverse lookup index
;;            ^TBE(eid,1)=""         — metadata entity registry
;;            ^TBE                   — metadata entity count
;;
;; Call     : DO BuildAttrRange(.Metadata)
;;------------------------------------------------------------------
    NEW eid,aid,val

    SET eid=""
    FOR  SET eid=$ORDER(MD(eid)) QUIT:eid=""  DO    
    . SET aid=""
    . FOR  SET aid=$ORDER(MD(eid,aid)) QUIT:aid=""  DO
    . . NEW vk
    . . SET val=MD(eid,aid)
    . . ; Skip if already indexed (reverse index is authoritative)
    . . QUIT:$DATA(^TBDR(aid,val))
    . . ; Register value + allocate lookup key
    . . SET vk=$$CreateNewValKey^sapiRslv(aid,val)

    QUIT


BuildTBoxIndexes(MD)
;;------------------------------------------------------------------
;; Routine  : BuildTBox
;; Purpose  : Single-pass build of both canonical stores from the
;;            metadata (MD) local array, replacing raw values with data type
;;            keys sourced from ^TBDR.
;;
;; Scope
;;   Reads  : MD(eid,aid)                       — input EAV structure: metadata entity (term), metadata attribute
;;            ^TBDR(aid,val)                    — reverse data type index
;;   Writes : ^TBEAVT(eid,attr,valkey,tx)       — primary index
;;            ^TBAVET(attr,valkey,eid,tx)       — secondary index
;;            ^TBEAVT("seq")                    — assertion sequence generator
;;            ^TBEAVT		                    — root counter of total assertions
;;
;; Notice   : 1. MD(eid,aid) holds the raw value directly.
;;            2. String subscripts at the eid level are skipped via eid=+eid.
;;            4. Requires BuildAttrRange to have populated ^TBDR.
;;------------------------------------------------------------------
    NEW tx,eid,aid,val

	 ; Root bootstrap transaction
    SET tx=$$TxAdd^sapiWFL("Root")

    ; Initialise sequence generator
    SET ^TBEAVT("seq")=TBSYSCNT
    
    ; Reset counters
    SET ^TBEAVT=0
    SET ^TBE=0

    SET eid=""
    FOR  SET eid=$ORDER(MD(eid)) QUIT:eid=""  DO
    . QUIT:'(eid=+eid) ; skip string subscripts
    . SET ^TBE(eid,1)=""
    . SET ^TXE(tx,eid)=""
    . SET ^TBE=$INCREMENT(^TBE)
    . SET aid=""
    . FOR  SET aid=$ORDER(MD(eid,aid)) QUIT:aid=""  DO
    . . NEW valkey
    . . SET val=MD(eid,aid)
    . . SET valkey=^TBDR(aid,val)
    . . SET ^TBEAVT(eid,aid,valkey,tx)=1
    . . SET ^TBAVET(aid,valkey,eid,tx)=1
    . . SET ^TBEAVT=$INCREMENT(^TBEAVT)
    . SET ^TXE=1
    QUIT


