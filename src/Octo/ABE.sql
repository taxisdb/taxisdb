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
-- ABE.sql
--
-- Octo table definition mapping for YottaDB global ^ABE, as
-- extracted in ABE.zwr:
--
--   ^ABE("6593cc2b1bc30jszqjhj",1)=""
--   ^ABE("6593cc2b1c2fe13f98tm",1)=""
--
-- Global layout: ^ABE(eid,op)="" (node value unused/empty)
--   eid    - entity ID (1st subscript, VARCHAR)
--   op     - operation flag: 0 = retraction, 1 = assertion (2nd subscript, INTEGER)
--   status - computed VARCHAR column ('A'/'R'), derived from the
--            op key column via the MapOp() SQL function, backed
--            by MapOp^utils
--
-- ============================================================

CREATE FUNCTION IF NOT EXISTS MapOp(INTEGER)
RETURNS VARCHAR AS $$MapOp^utils;

DROP TABLE IF EXISTS ABE;

CREATE TABLE ABE
(eid    VARCHAR PRIMARY KEY,
 op     INTEGER KEY NUM 1,
 status VARCHAR EXTRACT MapOp(op))
GLOBAL "^ABE"
READONLY;