;; ============================================================================================== 
;; ^keywords - Manage keywords (process local variables) subroutines - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 		— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;; ===============================================================================================
INIT
	D Load
	QUIT


Load
;;------------------------------------------------------------------
;; Routine  : Load Procedure
;; Purpose  : Loads all TBox keywords into local variables for use
;;            in the YDB shell by iterating ^TBKW and creating a
;;            local variable for each alias via indirection.
;;
;; Globals
;;    ^TBKW : Keyword registry to store canonical keyword strings
;;
;; Scope
;;   Reads  : ^TBKW(key,idx)  — keyword index, one alias per index
;;   Writes : None (globals unchanged)
;;
;; Parameters : None
;; Returns    : None
;; Call       : DO Load^keywords
;;
;; Notice   : 1. Local variables are created via indirection using the alias string as the variable name.
;;               SET @alias=keyword
;;               The left side (e.g. sys.attr.description) is the canonical key used internally.
;;               The right side (e.g. doc) acts like a symbolic constant name.
;;               This emulates Datomic-style keywords in native M syntax.
;;
;;            2. A single keyword may have multiple aliases at different index subscripts:
;;                 ^TBKW(key,0)=alias0
;;                 ^TBKW(key,1)=alias1
;;               All aliases resolve to the same canonical key.
;;
;;------------------------------------------------------------------
    ; Local variables used by this routine
    N keyword 
    S keyword=""
    	    
    ; ------------------------------------------------------------------
    ; Executable commands
    ; ------------------------------------------------------------------
    ;; TBox status
    
    S ^TBKW("DO PrintTBoxState^sapi",0)="TBS" 					; X TBS
    S ^TBKW("DO Transact^sapi",0)="TS" 							; X TS
    S ^TBKW("DO Transact^api",0)="TA" 							; X TA
    S ^TBKW("DO Setup^logger(""DEBUG"",1,0)",0)="DEBUG"			; X DEBUG
    S ^TBKW("DO Setup^logger(""INFO"",1,0)",0)="INFO"			; X INFO
    S ^TBKW("DO Setup^logger(""WARNING"",1,0)",0)="WARNING"		; X WARNING
    S ^TBKW("DO Setup^logger(""ERROR"",1,0)",0)="ERROR"			; X ERROR
    S ^TBKW("DO Setup^logger(""CRITICAL"",1,0)",0)="CRITICAL"	; X CRITICAL
    S ^TBKW("DO Load^keywords",0)="KW"							; X KW
    S ^TBKW("DO Print^keywords",0)="PKW"						; X PKW
    S ^TBKW("DO PrintSchema^sapi(""sandbox"")",0)="PS"			; X PS
    
    S ^TBKW("+",0)="A"
    S ^TBKW("-",0)="R"    
    
    ; ------------------------------------------------------------------
    ; Dynamic keyword loading
    ; This loop dynamically creates local variables from the ^TBKW registry.
    ; ------------------------------------------------------------------
    ;
    ; Iterate over all keywords in ^TBKW
    FOR  SET keyword=$ORDER(^TBKW(keyword)) QUIT:keyword=""  DO
    . NEW idx,als
    . SET idx=""
    . FOR  SET idx=$ORDER(^TBKW(keyword,idx)) QUIT:idx=""  DO
    . . SET als=^TBKW(keyword,idx)    
    . . SET @als=keyword
    QUIT
    


Build(Term)
;;------------------------------------------------------------------
;; Routine  : Build
;; Purpose  : Builds a global keyword index ^TBKW mapping each alias
;;            to its corresponding term key, resolved entirely from the Term local array.
;;			  this is executed only once after the bootstrap of the system
;;
;; Global   : ^TBKW(key) = alias
;;              Conceptually (Alias) -> TermKey
;;
;; Scope
;;   Reads  : Term(eid,aid)     — bootstrap EAV structure
;;   Writes : ^TBKW(key,0)		— alias keyword index
;;
;; Parameters : Term  — passed by reference
;;
;; Returns  : None
;;
;; Call     : DO Build(.Term)
;;
;;------------------------------------------------------------------
    NEW eid,alias,key

    SET eid=""
    FOR  SET eid=$ORDER(Term(eid)) QUIT:eid=""  DO
    . QUIT:'(eid=+eid)                          ; skip string subscripts
    . ; Skip entities that carry no alias or no key
    . QUIT:'$DATA(Term(eid,ALIASID))
    . QUIT:'$DATA(Term(eid,AKEYID))
    . SET alias=Term(eid,ALIASID)
    . SET key=Term(eid,AKEYID)    
    . SET ^TBKW(key,0)=alias
    QUIT


Print(ns)
;;------------------------------------------------------------------
;; Routine  : Print — Procedure
;;
;; Purpose  : Print all (keyword, alias) pairs whose key belongs to
;;            the specified namespace prefix, read directly from
;;            ^TBKW without entity resolution.
;;            If ns is omitted or "", prints all keywords.
;;
;; Grouping:
;;   - Keywords with no dot are grouped under "Executable Commands"
;;     with a double separator line
;;   - Keywords with dots are grouped by first dot-component (e.g. "sys")
;;     with a double separator line
;;   - Within a top-level group, a single separator is printed when
;;     the second dot-component changes (e.g. "sys.attr" -> "sys.type")
;;   - Deeper namespace changes (3rd part onward) produce no separator
;;
;; Examples :
;;   DO Print^keywords("")
;;   DO Print^keywords("sys")
;;   DO Print^keywords("sys.attr")
;;   DO Print^keywords("sys.val")
;;
;; Globals
;;   Read:
;;     ^TBKW  - keyword → alias mapping index
;;
;;------------------------------------------------------------------
    NEW key,nslen,col,i
    NEW cat1,prevCat1,cat2,prevCat2,dotpos

    SET ns=$GET(ns,"")
    SET nslen=$LENGTH(ns)
    SET col=35

    WRITE !
    FOR i=1:1:col+30 WRITE "~"
    IF ns="" WRITE !,"ALL KEYWORDS",!
    IF ns'="" WRITE !,"Namespace: ",ns
    FOR i=1:1:col+30 WRITE "~"
    WRITE !,!
    WRITE $EXTRACT("KEYWORD"_$JUSTIFY("",col),1,col)
    WRITE "ALIAS"
    WRITE !
    FOR i=1:1:col+30 WRITE "-"
    WRITE !

    SET key=ns
    SET prevCat1=""
    SET prevCat2=""
    FOR  DO  QUIT:key=""
    . SET key=$ORDER(^TBKW(key))
    . QUIT:key=""
    . IF nslen>0 QUIT:$EXTRACT(key,1,nslen)'=ns
    .
    . ; derive cat1 (top-level) and cat2 (second-level)
    . SET dotpos=$LENGTH(key,".")
    . IF dotpos=1 DO
    . . SET cat1="Executable Commands"
    . . SET cat2="Executable Commands"
    . IF dotpos>1 DO
    . . SET cat1=$PIECE(key,".",1)
    . . SET cat2=$PIECE(key,".",1,2)
    .
    . ; double separator when cat1 changes
    . IF cat1'=prevCat1 DO
    . . WRITE !,!
    . . FOR i=1:1:col+30 WRITE "="
    . . WRITE !,"  ",cat1
    . . WRITE !
    . . FOR i=1:1:col+30 WRITE "="
    . . WRITE !
    . . SET prevCat1=cat1
    . . SET prevCat2=cat2
    .
    . ; single separator when cat2 changes within same cat1
    . IF cat2'=prevCat2 DO
    . . WRITE !
    . . SET prevCat2=cat2
    . ; print all aliases for this key
    . NEW idx,als,first
    . SET idx=""
    . SET first=1
    . FOR  SET idx=$ORDER(^TBKW(key,idx)) QUIT:idx=""  DO
    . . SET als=^TBKW(key,idx)
    . . IF first WRITE !,$EXTRACT(key_$JUSTIFY("",col),1,col),als SET first=0
    . . ELSE  WRITE !,$JUSTIFY("",col),als

    WRITE !
    QUIT