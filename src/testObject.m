;; ======================================================================================================= 
;; ^testObject - Test role playing founded on creation of objects - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 		— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;; =========================================================================================================

INIT
	D ^init
	D AddObjects
	QUIT
	
AddObjects
    K Obj
    W !,"<------ Create Objects obj.claudio_arrau and obj.tom_hanks ------>",!
    S Obj(1,key)="obj.claudio_arrau"
    S Obj(1,doc)="Chilean pianist (1903-1991) @en"
    S Obj(1,name)="claudio_arrau"
    S Obj(1,isa)=OBJ
    S Obj(1,alias)="ClaudioArrau"
    S Obj(1,label)="Claudio Arrau @en"
    S Obj(1,wiki)="https://en.wikipedia.org/wiki/Claudio_Arrau|https://es.wikipedia.org/wiki/Claudio_Arrau|https://de.wikipedia.org/wiki/Claudio_Arrau"
    S Obj(1,home)="https://arrauhouse.org/content/homepage.htm"
	
    S Obj(2,key)="obj.tom_hanks"
    S Obj(2,doc)="American actor and filmmaker (born 1956) @en"
    S Obj(2,name)="tom_hanks"
    S Obj(2,isa)=OBJ
    S Obj(2,alias)="TomHanks|%TomHanks"
    S Obj(2,label)="Tom Hanks @en"
    S Obj(2,wiki)="https://en.wikipedia.org/wiki/Tom_Hanks|https://fr.wikipedia.org/wiki/Tom_Hanks|https://el.wikipedia.org/wiki/Τομ_Χανκς"

    D Stage^api(.Obj)
    D Transact^api
    D PE^api("obj.claudio_arrau")
    D PE^api("obj.tom_hanks")
    QUIT

    
TomHanks1
	; remove the name value
	; add another label value
    K Obj
    S Obj(1,key)="obj.foobar"
    S Obj(1,name,"-")=""
    S Obj(1,label)="Τομ Χανκς @el"
    D Stage^api(.Obj)
    D Transact^api
    
    D PE^api(TomHanks)
    D PrintHistory^api(TomHanks)
    QUIT


TomHanks2
	; Add a new name value
	; Add another wiki URL
    K Obj
    S Obj(100,key)=TomHanks
    S Obj(100,wiki)="https://es.wikipedia.org/wiki/Tom_Hanks"
    S Obj(100,name)="tommy"
    D Stage^api(.Obj)
    D Transact^api    
    
    D PE^api(TomHanks)
    D PrintHistory^api(TomHanks)
    QUIT


TomHanks3
	; Try to add the same wiki
    K Obj
    S Obj(200,key)=TomHanks    
    S Obj(200,wiki,R)="https://es.wikipedia.org/wiki/Tom_Hanks|https://fr.wikipedia.org/wiki/Tom_Hanks"
    D Stage^api(.Obj)
    D Transact^api

	; Try to add the same wiki using AssertDatom command
    D AD^api(TomHanks,wiki,"https://de.wikipedia.org/wiki/Tom_Hanks")
    D Transact^api
    
    D PE^api(TomHanks)
    D PrintHistory^api(TomHanks)
    QUIT


TomHanks4
	; Add another alias
	K Obj
	S Obj(1,key)="obj.tom_hanks"
	S Obj(1,alias)="tommy"
	S Obj(1,wiki,R)="https://es.wikipedia.org/wiki/Tom_Hanks|https://fr.wikipedia.org/wiki/Tom_Hanks"
	D Stage^api(.Obj)
	D Transact^api
	
	X KW
	D PE^api(tommy)
    QUIT






