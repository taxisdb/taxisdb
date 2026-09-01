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
-- TBAVET.sql
--
-- Octo table definition mapping for YottaDB global ^TBAVET
--
-- Global layout: ^TBAVET(aid,kv,eid,tx)=op
--   aid    - attribute ID       (1st subscript, INTEGER)
--   kv     - value key          (2nd subscript, VARCHAR)
--   eid    - entity ID          (3rd subscript, INTEGER)
--   tx     - transaction number (4th subscript, INTEGER)
--   op     - operation flag, node value: 0 = retraction, 1 = assertion (INTEGER)
--   status - computed VARCHAR column ('A'/'R'), derived from op via
--            the MapOp() SQL function, backed by MapOp^utils
--
-- ============================================================

CREATE FUNCTION IF NOT EXISTS MapOp(INTEGER)
RETURNS VARCHAR AS $$MapOp^utils;

DROP TABLE IF EXISTS TBAVET;

CREATE TABLE TBAVET
(aid    INTEGER PRIMARY KEY,
 kv     VARCHAR KEY NUM 1,
 eid    INTEGER KEY NUM 2,
 tx     INTEGER KEY NUM 3,
 op     INTEGER,
 status VARCHAR EXTRACT MapOp(op))
GLOBAL "^TBAVET"
READONLY;