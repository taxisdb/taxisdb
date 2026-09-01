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
-- TBE.sql
--
-- Octo table definition mapping for YottaDB global ^TBE, as
-- extracted in TBE.zwr:
--
--   ^TBE(1001,1)=""
--   ^TBE(1002,1)=""
--
-- Global layout: ^TBE(eid,op)="" (node value unused/empty)
--   eid    - entity ID (1st subscript, INTEGER)
--   op     - operation flag: 0 = retraction, 1 = assertion (2nd subscript, INTEGER)
--   status - computed VARCHAR column ('A'/'R'), derived from the
--            op key column via the MapOp() SQL function, backed
--            by MapOp^utils
--
-- ============================================================

CREATE FUNCTION IF NOT EXISTS MapOp(INTEGER)
RETURNS VARCHAR AS $$MapOp^utils;

DROP TABLE IF EXISTS TBE;

CREATE TABLE TBE
(eid    INTEGER PRIMARY KEY,
 op     INTEGER KEY NUM 1,
 status VARCHAR EXTRACT MapOp(op))
GLOBAL "^TBE"
READONLY;