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
-- EATV.sql
--
-- Octo table definition mapping the pre-existing YottaDB global
-- ^EATV, an EAV-style (entity-attribute-value) assertion/
-- retraction log, as extracted in EATV.zwr:
--
--   ^EATV=33
--   ^EATV("658f6b021049f9l16cw2",210,7401,"K0D2.018833")=1
--   ^EATV("658f6b021049f9l16cw2",240,7401,"K0F0.018834")=0
--
-- Global layout: ^EATV(eid,aid,tx,vk)=op
--   eid - entity ID          (1st subscript, VARCHAR)
--   aid - attribute ID       (2nd subscript, INTEGER)
--   tx  - transaction number (3rd subscript, INTEGER)
--   vk  - value key          (4th subscript, VARCHAR)
--   op  - operation flag, node value: 0 = retraction, 1 = assertion (INTEGER)
--   status - computed VARCHAR column ('A'/'R'), derived from op via
--            the OPFLAG() SQL function defined below
--
-- The ^EATV=33 root/0-node (a count, not part of the 4-level
-- subscript series) is not mapped by this table.
-- ============================================================

-- Register the M extrinsic function OPFLAG^opflag as an Octo SQL function
CREATE FUNCTION IF NOT EXISTS MapOp(INTEGER)
RETURNS VARCHAR AS $$MapOp^utils;

DROP TABLE IF EXISTS EATV;

CREATE TABLE EATV
(eid    VARCHAR PRIMARY KEY,
 aid    INTEGER KEY NUM 1,
 tx     INTEGER KEY NUM 2,
 vk     VARCHAR KEY NUM 3,
 op     INTEGER,
 status VARCHAR EXTRACT MapOp(op))
GLOBAL "^EATV"
READONLY;