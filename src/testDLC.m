;; ============================================================================== 
;; ^testDLC - Dilithium Crystals Inventory Timeline - This file is part of TaxisDB Platform
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

;; Dilithium Crystals Inventory Timeline
;; This test models a simple inventory item (DLC-042) moving through six transactions that span 2012–2014, 
;; demonstrating TaxisDB's core assert/retract/upsert mechanisms for cardinality-one attributes.

;; The schema transaction establishes four attributes: 
;; a unique string id, a string description, an integer count, and a txdate. 
;; sandbox.dlc.id is UNQUPSERT — find-or-merge semantics — so every transaction below
;; simply asserts Item(1,dlcid)="042" 

;; The five data transactions drive a single entity through a realistic lifecycle: 
;; initial creation, two routine stock adjustments, a data-entry error, and a correction. 
;; Because count and txdate are both cardinality-one, every update automatically triggers SingleValueUpsert — 
;; the old value is retracted and the new one asserted within the same transaction, 
;; building up a complete audit trail in ^EATV without any explicit retract calls from the caller.
;; The April 2014 transaction is the interesting case. 
;; The count is erroneously set to 9999 and the mistake is not caught until May. 

;; The May 2014 correction (TX6) resets count back to 100 — a value already present
;; earlier in the entity's history (from TX2). ResolveAV correctly recognizes "100" as
;; an EXISTING valkey rather than minting a new one, so the value dictionary reuses the
;; same valkey across two separate points in the timeline. The ^EATV audit trail still
;; correctly reflects this as a fresh retract(9999)/assert(100) pair at TX6's own tx
;; number — the value's reuse does not collapse or merge the history entries.

;; Here is how data evolves step-by-step:
;; 1. Transaction 1 (2012): Installs the schema, establishing attributes for a DLC item
;; 2. Transaction 2 (Jan 2013): Creates the item `DLC-042` ("Dilitihium Crystals") with a count of 100.
;; 3. Transaction 3 (Feb 2013): Updates the count to 250. Under the hood, TaxisDB implicitly retracts `100` and asserts `250`.
;; 4. Transaction 4 (Feb 2014): Updates the count to 50.
;; 5. Transaction 5 (April Fool's Day, 2014): A data entry error occurs! The count is accidentally set to 9999. 

;; TODO: Because the operator realized it was a mistake, they attached `:tx/error true` to the _transaction itself_.
;; 6. Transaction 6 (May 2014): The error is corrected, resetting the count back to 100.


; Verified output — full run from a fresh database, 2026-07-06:
;
; ==============================
; 042
; ==============================
;   655ebd168d6749eaa79q  sandbox.dlc.id           042
;   655ebd168d6749eaa79q  sandbox.dlc.checkup      Dilithium Crystals on 15th May 2014 @en
;   655ebd168d6749eaa79q  sandbox.dlc.count        100
;   655ebd168d6749eaa79q  sandbox.dlc.txdate       2014-05-15
;
; Full ^EATV history (PrintHistory) confirms:
;   - dlc.id (aid 1008) stays a no-op across all 5 transactions — value never changes
;   - checkup/count/txdate each show a clean retract/assert pair at every update tx
;   - count's TX6 correction reuses the SAME valkey as TX2's original "100" —
;     value dictionary correctly dedupes, audit trail correctly still shows the
;     retract/assert pair at TX6's own tx number

;; TODO marks the one place where TaxisDB currently diverges from the Datomic original: 
;; Datomic annotates the transaction entity itself with :tx/error true, 
;; making the error a fact about the transaction rather than about the item.

;; ==================================================================================================================================

INIT
	; D ^init
	D BuildSchema
	D Load^keywords
	
	D TX2
	D EXE		
	
	; UpdateItem
	QUIT


BuildSchema
    NEW DLC	
	W !,!,"======= Build Schema for a DLC Item Type =======",!
    S DLC(1,key)="sandbox.dlc.id"
    S DLC(1,range)=STRING
    S DLC(1,cardin)=ONE
    S DLC(1,isa)=ATYPE
    S DLC(1,doc)="Unique identifier for the inventory item @en"
    S DLC(1,unq)=UNQUPSERT    
    S DLC(1,alias)="dlcid"

    S DLC(2,key)="sandbox.dlc.checkup"
    S DLC(2,range)=STRING
    S DLC(2,cardin)=ONE
    S DLC(2,isa)=ATYPE
    S DLC(2,doc)="Write notes for the checkup of the DLC item @en"    
    S DLC(2,alias)="checkup"

    S DLC(3,key)="sandbox.dlc.count"
    S DLC(3,range)=INT
    S DLC(3,cardin)=ONE
    S DLC(3,isa)=ATYPE
    S DLC(3,doc)="Current inventory count of the item @en"
    S DLC(3,validfn)="$$IsInt^utils"    
    S DLC(3,alias)="count"

    S DLC(4,key)="sandbox.dlc.txdate"
    S DLC(4,range)=DATE
    S DLC(4,cardin)=ONE
    S DLC(4,isa)=ATYPE
    S DLC(4,doc)="Date of the inventory transaction @en"
    S DLC(4,validfn)="$$IsDate^utils"
    S DLC(4,alias)="txdate"

    D Stage^sapi(.DLC)
    D Transact^sapi
    ; D PrintSchema^sapi("sandbox.dlc")
    QUIT


UpdateItem
	D TX3
	D EXE
	
	D TX4
	D EXE
	
	D TX5
	D EXE
	
	D TX6
	D EXE
	QUIT
    
EXE
	D Stage^api(.Item)
    D Transact^api("Root")
    D PE^api("042",dlcid)
    D PrintHistory^api("042",dlcid)
    QUIT
    
TX2
	W !,"<------ Create DLC Item 042 ------>",!
	; TX2 — Jan 2013: Create item DLC-042
	; No unique attributes owned yet — ResolveByUnique/ResolveSingleUnique
	; generates a fresh EID via GENID.
    K Item
    S Item(1,dlcid)="042"    
    S Item(1,checkup)="Dilithium Crystals on 1st January 2013 @en"
    S Item(1,count)=100
    S Item(1,txdate)="2013-01-01"    
	QUIT

TX3
	; TX3 — Feb 2013: Update count 100 → 250
	; dlcid="042" already owned — UNQUPSERT merge resolves to the
	; existing entity. sandbox.dlc.id is the only unique attribute in
	; this namespace, so no sys.attr.resolvedby is needed.
    K Item
    S Item(1,dlcid)="042"
    S Item(1,count)=250
    S Item(1,txdate)="2013-02-01"
    S Item(1,checkup)="Dilithium Crystals on 1st February 2013 @en"    
    QUIT
    
TX4
	; TX4 — Feb 2014: Update count 250 → 50
    K Item
    S Item(1,dlcid)="042"
    S Item(1,checkup)="Dilithium Crystals on 28th February 2014 @en"
    S Item(1,count)=50
    S Item(1,txdate)="2014-02-28"    
    QUIT
    
TX5
	; TX5 — Apr 2014: Erroneous entry, count → 9999
    K Item
    S Item(1,dlcid)="042"
    S Item(1,checkup)="Dilithium Crystals on 1st April 2014 @en"
    S Item(1,count)=9999
    S Item(1,txdate)="2014-04-01"    
    QUIT

TX6
	; TX6 — May 2014: Correct count back to 100
	; Note: "100" reuses the SAME valkey originally minted in TX2 —
	; ResolveAV reports (RES)-EXISTS rather than creating a new value.
	; The retract(9999)/assert(100) pair is still correctly recorded
	; under TX6's own tx number in ^EATV.
    K Item
    S Item(1,dlcid)="042"
    S Item(1,checkup)="Dilithium Crystals on 15th May 2014 @en"
    S Item(1,count)=100
    S Item(1,txdate)="2014-05-15"    
    QUIT