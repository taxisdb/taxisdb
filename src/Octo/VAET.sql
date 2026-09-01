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
-- VAET.sql
--
-- Octo table definition mapping for YottaDB global ^VAET
--
-- Global layout: ^VAET(vk,aid,eid,tx)=op
--   vk     - value key          (1st subscript, VARCHAR)
--   aid    - attribute ID       (2nd subscript, INTEGER)
--   eid    - entity ID          (3rd subscript, VARCHAR)
--   tx     - transaction number (4th subscript, INTEGER)
--   op     - operation flag, node value: 0 = retraction, 1 = assertion (INTEGER)
--   status - computed VARCHAR column ('A'/'R'), derived from op via
--            the MapOp() SQL function, backed by MapOp^utils
--
-- ============================================================

CREATE FUNCTION IF NOT EXISTS MapOp(INTEGER)
RETURNS VARCHAR AS $$MapOp^utils;

DROP TABLE IF EXISTS VAET;

CREATE TABLE VAET
(vk     VARCHAR PRIMARY KEY,
 aid    INTEGER KEY NUM 1,
 eid    VARCHAR KEY NUM 2,
 tx     INTEGER KEY NUM 3,
 op     INTEGER,
 status VARCHAR EXTRACT MapOp(op))
GLOBAL "^VAET"
READONLY;