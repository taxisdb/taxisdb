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
-- TBD.sql
--
-- Octo table definition mapping the pre-existing YottaDB global
-- ^TBD, as extracted in TBD.zwr:
--
--   ^TBD(204,"K0CC.0187AB")="$$IsURL^utils"
--   ^TBD(204,"K0CC.018849")="$$IsLangStr^utils"
--
-- Global layout: ^TBD(aid,vk)=val
--   aid - attribute ID (1st subscript, INTEGER)
--   vk  - value key    (2nd subscript, VARCHAR)
--   val - value        (node value, VARCHAR)
--
-- Unlike ^EATV/^TBEAVT, the node value here is a plain descriptive
-- string (an M validator entryref or a dotted type/value name), not
-- a 0/1 flag, so no MapOp()/status computed column is needed.
-- ============================================================

DROP TABLE IF EXISTS TBD;

CREATE TABLE TBD
(aid INTEGER PRIMARY KEY,
 vk  VARCHAR KEY NUM 1,
 val VARCHAR)
GLOBAL "^TBD"
READONLY;