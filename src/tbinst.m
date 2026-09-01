;; ============================================================================== 
;; ^tbinst - Taxis Base Instances - This file is part of TaxisDB Platform
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

Load
	; D ^init
	
	W !,"<---------- Create Geo Instances ------->",!
	K Geo		
	; Geographic coordinates of Chillán, Chile
	S Geo(1,lng)=-72.10344											; longitude
	S Geo(1,lat)=-36.60664											; latitude
	S Geo(1,point)="POINT (-72.10344 -36.60664)"					; WKT 2D representation (longitude latitude)
	S Geo(1,pointz)="POINT Z (-72.10344 -36.60664 140)"				; WKT 3D representation with altitude (meters)
	S Geo(1,gps)="(-36.60664, -72.10344)"							; GPS representation (latitude longitude)
	S Geo(1,geohash)="63kxxpzyu5d"									; Geohash representation
	S Geo(1,display)="(lat -36.60664, lng -72.10344, alt 140m)"		; Human-readable display
	S Geo(1,isa)=GEO	
	D Stage^api(.Geo,"location")
    D Transact^api
    QUIT

Sam
	S Sam(1,personGivenName)="Sam"
	S Sam(1,personBirthDate)="1972-10-12"
	S Sam(1,personFamilyName)="Cromwell"
	S Sam(1,isa)=PERSON
	S Sam(1,key)="sam"
	D Stage^api(.Sam,"people")
    D Transact^api
    QUIT
    
Bob
	S Bob(1,isa)=PERSON
	S Bob(1,key)="bob"
	S Bob(1,personGivenName)="Bob"
	S Bob(1,personBirthDate)="1982-1-12"
	S Bob(1,personFamilyName)="Dumfried"
	S Bob(1,personEmail)="bob@example.com"
	S Bob(1,personFollows)=$$LookupEID^apiGet("sam")
	D Stage^api(.Bob,"people")
    D Transact^api
    
	QUIT