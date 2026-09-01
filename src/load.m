;; ============================================================================== 
;; ^load - Load data into TaxisDB - This file is part of TaxisDB Platform
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
	D ^testObject 	; Add two objects obj.tom_hands, obj.claudio_arrau
	W !,!
	D ^testMovie	; Build a movie schema and add a movie (Seven)
	W !,!
	D ^testPerson   ; Build a person schema and add a person (Athan)
	W !,!
	D ^testDLC		; Build Dilithium Crystals Schema and create the first DLC item "042"
	W !,!

	X KW			; D Load^keywords
	; X PKW			; D Print^keywords (ALL)
	
	; X TBS			; D PrintTBoxStatus^sapi
	; X PS			; D PrintSchema^sapi("sandbox")
	QUIT

