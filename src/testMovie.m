;; =============================================================================================================== 
;; ^testMovie - Build a sandbox movie schema and create movie instances - This file is part of TaxisDB Platform
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
    D MovieSchema
    D Seven
	QUIT


;;==============================================================================
MovieSchema
	W !,!,"======= Build Schema for a Movie Entity Type =======",!
    ; Attributes for a Movie
    S Movie(1,key)="sandbox.movie.title"
    S Movie(1,range)=STRING
    S Movie(1,cardin)=ONE
    S Movie(1,isa)=ATYPE
    S Movie(1,doc)="The title of the movie @en"
    S Movie(1,req)=1
    S Movie(1,validfn)="$$IsLangStr^utils"
    S Movie(1,alias)="title"

    S Movie(2,key)="sandbox.movie.genre"
    S Movie(2,range)=STRING
    S Movie(2,cardin)=MANY
    S Movie(2,isa)=ATYPE
    S Movie(2,doc)="The genre of the movie @en"
    S Movie(2,alias)="genre"

    S Movie(3,key)="sandbox.movie.releaseYear"
    S Movie(3,range)=INT
    S Movie(3,cardin)=ONE
    S Movie(3,isa)=ATYPE
    S Movie(3,doc)="The year the movie was released in theaters @en"
    S Movie(3,validfn)="$$IsInt^utils"
    S Movie(3,alias)="ry"

    S Movie(4,key)="sandbox.movie.imdbid"
    S Movie(4,range)=STRING
    S Movie(4,cardin)=ONE
    S Movie(4,isa)=ATYPE
    S Movie(4,doc)="IMDB unique identifier for the entity @en"
    S Movie(4,unq)=UNQINSERT
    S Movie(4,req)=1
    S Movie(4,alias)="imdb"
    
    S Movie(5,key)="sandbox.movie.tmdbid"
    S Movie(5,range)=INT
    S Movie(5,cardin)=ONE
    S Movie(5,isa)=ATYPE
    S Movie(5,doc)="TMDb unique identifier for the movie @en"
    S Movie(5,unq)=UNQUPSERT
    S Movie(5,alias)="tmdb"
        
    D Stage^sapi(.Movie)
    D Transact^sapi
    D Load^keywords
    QUIT


Seven
	W !,"<------ Create Movie Seven ------>",!
    K M
    S M(17,"movie.title")="Seven @en"
    S M(17,"movie.genre")="thriller|mystery"
    S M(17,"movie.releaseYear")=1995
    S M(17,"movie.imdbid")="tt0011100"
    D Stage^api(.M,"sandbox",0)
    D Transact^api
    
    D PE^api("tt0011100","sandbox.movie.imdbid")    
    QUIT


UpdateSeven
    K Movies
    SET Movies(1,id)=$$LookupEID^apiGet("tt0011100","sandbox.movie.imdbid")
    SET Movies(1,"movie.title")="Se7en @en"     ; updated title
    SET Movies(1,"movie.genre")="crime"			; add another genre
    SET Movies(1,"movie.tmdbid")=807			; add another lookup (unique) attribute
    DO INIT^api
    DO Stage^api(.Movies)
    DO Transact^api
    QUIT


LookupSeven	
	; D PE^sapi("sandbox.movie.imdbid")
	; D PE^sapi("sandbox.movie.tmdbid")	
	; w $$GetEID^apiGet(807,1004)
	; w $$GetEID^apiGet("tt0011100",1003)
	; w $$LookupEID^apiGet("tt0011100","sandbox.movie.imdbid")
	; w $$LookupEID^apiGet(807,"sandbox.movie.tmdbid")
	
	; Run UpdateSeven first
	D PE^api(807,"sandbox.movie.tmdbid")
	D PE^api("tt0011100","sandbox.movie.imdbid")
	
	QUIT


TheMatrix
    K M
    ; Movie has TWO unique attributes — imdbid (UNQINSERT) and tmdbid (UNQINSERT)
    ; ResolveByUnique can't guess which one to use, so sys.attr.resolvedby
    ; tells it explicitly: "use movie.imdbid to find/create this entity"
    S M(20,"sys.attr.resolvedby")="sandbox.movie.imdbid"
    S M(20,"movie.title")="The Matrix @en"
    S M(20,"movie.genre")="action|scifi"
    S M(20,"movie.releaseYear")=1999
    S M(20,"movie.imdbid")="tt0133093"
    S M(20,"movie.tmdbid")="603"
    D Stage^api(.M,"sandbox",0)
    D Transact^api
    
    D PE^api("tt0133093","sandbox.movie.imdbid")
    D PE^api("603","sandbox.movie.tmdbid")
    QUIT


BulkLoad
	D SetM
	D Stage^api(.M,"sandbox",1) ; isBulkLoad=1, skips validation phase
	D Transact^api

SetM	
	K M
	S M(1,"movie.title")="The Reader"
	S M(1,"movie.genre")="drama|romance"
	S M(1,"movie.releaseYear")=2008
	S M(1,"movie.imdbid")="tt0976051"

	S M(2,"movie.title")="Crazy Stupid Love"
	S M(2,"movie.genre")="comedy|romance"
	S M(2,"movie.releaseYear")=2011
	S M(2,"movie.imdbid")="tt1570728"

	S M(3,"movie.title")="The Perfect Storm"
	S M(3,"movie.genre")="drama|adventure"
	S M(3,"movie.releaseYear")=2000
	S M(3,"movie.imdbid")="tt0177971"

	S M(4,"movie.title")="The Thin Red Line"
	S M(4,"movie.genre")="drama|war"
	S M(4,"movie.releaseYear")=1998
	S M(4,"movie.imdbid")="tt0120863"

	S M(5,"movie.title")="The Shawshank Redemption"
	S M(5,"movie.genre")="drama|romance"
	S M(5,"movie.releaseYear")=1994
	S M(5,"movie.imdbid")="tt0111161"

	S M(6,"movie.title")="Forrest Gump"
	S M(6,"movie.genre")="drama|romance"
	S M(6,"movie.releaseYear")=1994
	S M(6,"movie.imdbid")="tt0109830"

	S M(7,"movie.title")="Saving Private Ryan"
	S M(7,"movie.genre")="drama|war"
	S M(7,"movie.releaseYear")=1998
	S M(7,"movie.imdbid")="tt0120815"

	S M(8,"movie.title")="Cast Away"
	S M(8,"movie.genre")="drama|adventure"
	S M(8,"movie.releaseYear")=2000
	S M(8,"movie.imdbid")="tt0162222"

	S M(9,"movie.title")="That Thing You Do"
	S M(9,"movie.genre")="comedy|music"
	S M(9,"movie.releaseYear")=1996
	S M(9,"movie.imdbid")="tt0117887"

	S M(10,"movie.title")="Larry Crowne"
	S M(10,"movie.genre")="comedy|romance"
	S M(10,"movie.releaseYear")=2011
	S M(10,"movie.imdbid")="tt1583420"

	S M(11,"movie.title")="Band of Brothers"
	S M(11,"movie.genre")="drama|war"
	S M(11,"movie.releaseYear")=2001
	S M(11,"movie.imdbid")="tt0185906"

	S M(12,"movie.title")="Mamma Mia"
	S M(12,"movie.genre")="comedy|romance"
	S M(12,"movie.releaseYear")=2008
	S M(12,"movie.imdbid")="tt0491605"
	
	S M(13,"movie.title")="Cast Away"
	S M(13,"movie.genre")="drama|adventure"
	S M(13,"movie.releaseYear")=1986
	S M(13,"movie.imdbid")="tt0090708"
	
	S M(14,"movie.title")="Memento"
	S M(14,"movie.genre")="thriller|mystery"
	S M(14,"movie.releaseYear")=2000
	S M(14,"movie.imdbid")="tt0209144"
	
	S M(15,"movie.title")="The Gift"
	S M(15,"movie.genre")="drama"
	S M(15,"movie.releaseYear")=1979
	S M(15,"movie.imdbid")="tt0079217"
	
	S M(16,"movie.title")="The Gift"
	S M(16,"movie.genre")="thriller|mystery"
	S M(16,"movie.releaseYear")=2000
	S M(16,"movie.imdbid")="tt0219699"

	; S M(17,"movie.title")="Seven"
	; S M(17,"movie.genre")="thriller|mystery"
	; S M(17,"movie.releaseYear")=1995
	; S M(17,"movie.imdbid")="tt0011100"
	QUIT
 
 