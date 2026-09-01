;; ============================================================================== 
;; ^start - Generates a new TaxisDB - This file is part of TaxisDB Platform
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
	NEW Success
	SET Success=$$Bootstrap(0) ; Use $$Bootstrap(1) to override the confirmation
	IF 'Success WRITE !,"INIT aborted — Bootstrap did not complete.",! QUIT
	
	D INIT^load	; Load rest of TaxisBase schema and data sets on top of TaxisBase bootstrap system schema	
	QUIT


EraseEverything
	KILL ^TX,^TXE,^TXLOG								; Region - transactions.dat
	KILL ^TBE,^TBD,^TBDR,^TBEAVT,^TBAVET,^TBKW,^TBEnts  ; Region - tbox.dat
	KILL ^EATV,^AVET,^AEVT,^VAET,^ABE					; Region - abox.dat
	QUIT


Bootstrap(Override)
;;-------------------------------------------------------------------------------------------------------
;; Routine  : Bootstrap Procedure (test.m)
;; Purpose  : Initialises the TBox and ABox from scratch by clearing all
;;            existing TBox and ABox globals, loading the bootstrap schema from a metadata local array
;;            and building the full TBox system indexes.
;;
;; Call	    : SET ok=$$Bootstrap^test()		; interactive, prompts for confirmation
;;            SET ok=$$Bootstrap^test(1)	; non-interactive, skips confirmation
;;            Returns 1 on success, 0 if aborted/declined.
;;
;;-------------------------------------------------------------------------------------------------------
	NEW Confirm,HasData

	SET:'$DATA(Override) Override=0

	; Detect whether any existing data is present across the three regions
	SET HasData=0
	SET HasData=HasData!($DATA(^TX)>0)!($DATA(^TXE)>0)!($DATA(^TXLOG)>0)
	SET HasData=HasData!($DATA(^TBE)>0)!($DATA(^TBD)>0)!($DATA(^TBDR)>0)!($DATA(^TBEAVT)>0)!($DATA(^TBAVET)>0)!($DATA(^TBKW)>0)!($DATA(^TBEnts)>0)
	SET HasData=HasData!($DATA(^EATV)>0)!($DATA(^AVET)>0)!($DATA(^AEVT)>0)!($DATA(^VAET)>0)!($DATA(^ABE)>0)

	WRITE !,"*********************************************************************************"
	WRITE !,"*  TaxisDB   — database engine licensed under SSPL v1.0                         *" 
	WRITE !,"*  TaxisBase — knowledge base  licensed under ODbL v1.0 + DBCL v1.0             *"
	WRITE !,"*                                                                               *"
	WRITE !,"*  Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu                  *"
	WRITE !,"*  All rights reserved except as granted by the applicable copy-left licenses   *" 
	WRITE !,"*                                                                               *"
	WRITE !,"*  THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND.                *"
	WRITE !,"*                                                                               *"
	WRITE !,"*                                                                               *"
	
	IF 'Override DO
	. IF HasData DO
	. . WRITE !,"*                                                                               *"
	. . WRITE !,"*  WARNING: Existing data was found in TaxisDB	 database                        *"
	. . WRITE !,"*  A new TaxisDB will be generated and all existing data                        *"
	. . WRITE !,"*  currently stored will be PERMANENTLY DELETED and cannot be recovered         *"
	. . WRITE !,"*                                                                               *"
	. . WRITE !,"*********************************************************************************",!
	. ELSE  DO
	. . WRITE !,"*                                                                               *"
	. . WRITE !,"*  TaxisDB is empty, no existing data was found. A new database will be created *"	
	. . WRITE !,"*                                                                               *"
	. . WRITE !,"***************************************(*****************************************",!
	. WRITE !,"Type YES to continue, or anything else to abort: "
	. READ Confirm,!

	IF 'Override,Confirm'="YES" WRITE !,"Bootstrap aborted. No data was deleted.",! QUIT 0
	IF 'Override WRITE !,"Confirmed. Proceeding with bootstrap...",!

	DO EraseEverything
	NEW Metadata
	
	DO INIT^bootstrap(.Metadata)
	
	; ; Build TBox system indexes
	DO INIT^sndx
	DO BuildAttrRange^sndx(.Metadata)	
	DO BuildTBoxIndexes^sndx(.Metadata)
	
	DO INIT^sapi	
	DO INIT^api
	
	DO Build^keywords(.Metadata)
	DO INIT^keywords ; this is the first time we load keywords from the bootstrap of the system
	;  				 ; we use keywords in BuildTypes and BuildSchema	
	QUIT 1
	
	
	
	