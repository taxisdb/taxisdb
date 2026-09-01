;; ================================================================================================= 
;; ^testSpec - Test for entity specs and entity predicates  - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 		— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;; ==================================================================================================

;; TODO... it is not implemented

INIT		
	D ^init
    D Load^keywords
    
    QUIT


;;==============================================================================
ScoreSchema   
    S Score(1,key)="sandbox.score.low"
    S Score(1,range)=INTEGER
    S Score(1,cardin)=ONE
    S Score(1,isa)=ATYPE
    S Score(1,doc)="The lower bound value of the score range @en"
    S Score(1,validfn)="$$IsInt^utils"
    S Score(1,alias)="low"

    S Score(2,key)="sandbox.score.high"
    S Score(2,range)=INTEGER
    S Score(2,cardin)=ONE
    S Score(2,isa)=ATYPE
    S Score(2,doc)="The upper bound value of the score range @en"    
    S Score(2,validfn)="$$IsInt^utils"
    S Score(2,alias)="high"        
    D Stage^sapi(.Obj)    
    D Transact^sapi
	QUIT

ScoreSpec
	W !,"<------ Create Score Spec ------>",!
    K M    
    S Score(3,key)="sandbox.score_guard"
    S Score(3,doc)="Entity spec ensuring score entities carry both a low and a high score attribute, and that the low value does not exceed the high value @en"
    S Score(3,name)="score_guard"
    S Score(3,isa)=OBJ
    S Score(3,alias)="ScoreGuard"
    S Score(3,label)="Score Guard Spec @en"
    S Score(3,entattr)="score.low|score.high"
    S Score(3,entvalidfn)="$$AreScoresOrdered^utils"
    D Stage^api(.Score,"sandbox",0)
    D Transact^api
    
ScoreEntry
    S Score(1,"score.low")=100
    S Score(1,"score.high")=20
    S Score(1,entspec)="sandbox.score_guard"        
    D Stage^api(.Score,"sandbox",0)
    D Transact^api
    QUIT