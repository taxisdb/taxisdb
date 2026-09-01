-- ========================================================================================= 
-- Octo table definition mapping for TaxisDB global - This file is part of TaxisDB Platform
--
-- Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
-- All rights reserved except as granted by the applicable copy-left licenses.
--
-- TaxisDB Platform includes:
-- TaxisDB 		— database engine licensed under SSPL v1.0
-- TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.


-- ============================================================
-- TBEnts.sql
--
-- Octo table definition mapping for YottaDB global ^TBEnts, as
-- extracted in TBEnts.zwr:
--
--   ^TBEnts(157,"sys.val.double","sys.attr.name")="double"
--   ^TBEnts(159,"sys.val.url","sys.attr.alias")="URL"
--
-- Global layout: ^TBEnts(eid,ekey,akey)=val
--   eid - entity ID   (1st subscript, INTEGER)
--   ekey - entity key (2nd subscript, VARCHAR)
--   akey - attribute key (3rd subscript, VARCHAR)
--   val  - value (node value, VARCHAR)
-- ============================================================

DROP TABLE IF EXISTS TBEnts;

CREATE TABLE TBEnts
(eid  INTEGER PRIMARY KEY,
 ekey VARCHAR KEY NUM 1,
 akey VARCHAR KEY NUM 2,
 val  VARCHAR)
GLOBAL "^TBEnts"
READONLY;