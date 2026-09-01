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
-- TBEAVT.sql
--
-- Octo table definition mapping the pre-existing YottaDB global
-- ^TBEAVT, an EAV-style (entity-attribute-value) assertion/
-- retraction log, as extracted in TBEAVT.zwr:
--
--   ^TBEAVT(100,210,"K0D2.0186A1",7400)=1
--   ^TBEAVT(100,230,"K0E6.0186A2",7400)=1
--   ^TBEAVT(100,240,"K0F0.0186A3",7400)=1
--
-- Global layout: ^TBEAVT(eid,aid,kv,tx)=op
--   eid    - entity ID          (1st subscript, INTEGER)
--   aid    - attribute ID       (2nd subscript, INTEGER)
--   kv     - value key          (3rd subscript, VARCHAR)
--   tx     - transaction number (4th subscript, INTEGER)
--   op     - operation flag, node value: 0 = retraction, 1 = assertion (INTEGER)
--   status - computed VARCHAR column ('A'/'R'), derived from op via
--            the MapOp() SQL function, backed by MapOp^utils
-- ============================================================

CREATE FUNCTION IF NOT EXISTS MapOp(INTEGER)
RETURNS VARCHAR AS $$MapOp^utils;

DROP TABLE IF EXISTS TBEAVT;

CREATE TABLE TBEAVT
(eid    INTEGER PRIMARY KEY,
 aid    INTEGER KEY NUM 1,
 kv     VARCHAR KEY NUM 2,
 tx     INTEGER KEY NUM 3,
 op     INTEGER,
 status VARCHAR EXTRACT MapOp(op))
GLOBAL "^TBEAVT"
READONLY;