;; ==================================================================================== 
;; ^init - Process Initialization - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 		— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;;======================================================================================

INIT ; ^init must be called once per process before using ^api and/or ^sapi routines
	D Setup^logger("INFO",0,0) ; Debug Level:INFO, Output to Console:TRUE, capture $STACK trace:FALSE
    D INIT^sapi
    D INIT^api
    D Load^keywords    
