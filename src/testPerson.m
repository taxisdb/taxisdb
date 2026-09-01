;; =============================================================================================================== 
;; ^testPerson - Build a sandbox person schema and create person instances - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 		— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;; ================================================================================================================

INIT
	; D ^init
	D PersonSchema
	D Athan
	QUIT
	
	
PersonSchema
	W !,!,"======= Build Schema for a Person Entity Type =======",!
	D AddAttr^sapi("sandbox.person.name",STRING,ONE,ATYPE)
    D AddAttr^sapi("sandbox.person.age",INT,ONE,ATYPE)
    D AddAttr^sapi("sandbox.person.email",STRING,ONE,ATYPE,UNQINSERT,"Unique email address of the person @en")
    D AddAttr^sapi("sandbox.person.ssn",STRING,ONE,ATYPE,UNQUPSERT,"Unique social security number of the person @en")
    D Transact^sapi
    ; D PrintSchema^sapi("sandbox.person")
    QUIT

Athan	
	W !,"<------ Create Person p.athan ------>",!
	K P
	S P(1,key)="p.athan"
    S P(1,"person.name")="athan"
    S P(1,"person.age")=56
    S P(1,"person.email")="athan@example.com"
    D Stage^api(.P,"sandbox")
    D Transact^api
    D PE^api("p.athan")        
    QUIT
	
