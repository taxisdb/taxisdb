;; ================================================================================ 
;; ^tx - Transaction helper/utility functions - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 		— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;;
;;============================================================================== 


GetLast() ; resolve the most recently allocated transaction id
;;------------------------------------------------------------------
;; Function : GetLast^sapiGet
;; Call     : SET tx=$$GetLast^sapiGet()
;;
;; Purpose  : Resolves the most recently allocated transaction id by reading
;;            the last node under ^TXE.
;;
;; Parameters
;;   (none)
;;
;; Scope
;;   Reads  : ^TXE(tx)
;;
;; Returns  :
;;   tx : the highest tx id currently present under ^TXE
;;   ""  : no transaction has ever been committed — ^TXE is empty
;;------------------------------------------------------------------
    ; find the last transaction, read the last node in ^TXE (tx ids are monotonically incremented)
    QUIT $ORDER(^TXE(""),-1) ; first node from the end


IsNop(tx) ; check whether a transaction asserted no new datoms
;;----------------------------------------------------------------------------------------------------
;; Function : IsNop^sapiVld
;;
;; Call     : WRITE $$IsNop^tx(tx)
;;            WRITE $$IsNop^sapiVld()
;;
;; Purpose  : Determine whether a transaction is stamped as a no-op — i.e. every
;;            triplet it staged was already asserted, so Transact^sapi wrote the ^TXE(tx,0) marker
;;
;; Parameters
;;   tx : (IN, optional) Transaction id to check. 
;;		  Defaults to the most recently allocated transaction id
;;
;; Returns  : 1 if tx is stamped as a no-op, otherwise 0.
;;
;; Notes    : no-op status is indicated by the existence of the node, not by a
;;            non-empty value e.g. ^TXE(7409,0)=""
;;
;;	''$DATA(...) double-negation canonicalize $DATA's four-valued return into a strict 0/1 boolean.
;;----------------------------------------------------------------------------------------------------    
    SET tx=$GET(tx,$$GetLast()) ; default the most recently allocated transaction id
    QUIT ''$DATA(^TXE(tx,0))
