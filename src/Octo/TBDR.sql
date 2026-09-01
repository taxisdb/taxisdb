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
-- TBDR.sql
--
-- Octo table definition mapping the pre-existing YottaDB global
-- ^TBDR, as extracted in TBDR.zwr:
--
--   ^TBDR=472
--   ^TBDR(204)=4
--   ^TBDR(204,"$$IsDate^utils")="K0CC.018874"
--   ^TBDR(204,"$$IsInt^utils")="K0CC.018851"
--   ^TBDR(204,"$$IsLangStr^utils")="K0CC.018849"
--   ^TBDR(204,"$$IsURL^utils")="K0CC.0187AB"
--   ^TBDR(210)=76
--   ^TBDR(210,"location.cvt.geo")="K0D2.018818"
--   ^TBDR(210,"obj.claudio_arrau")="K0D2.018833"
--   ...
--
-- Global layout (2-level nodes only): ^TBDR(aid,val)=vk
--   aid - attribute ID (1st subscript, INTEGER)
--   val - value        (2nd subscript, VARCHAR)
--   vk  - value key    (node value, VARCHAR)
--
-- ^TBDR is essentially the inverse index of ^TBD: ^TBD maps
-- (aid,vk)->val while ^TBDR maps (aid,val)->vk.
--
-- The single-subscript nodes (^TBDR=472, ^TBDR(204)=4, ^TBDR(210)=76
-- -- these look like a root count and per-aid counts) are NOT part
-- of the 2-level (aid,val) series and are automatically excluded:
-- a 2-key READONLY table's generated code does one $ORDER loop per
-- key column (over aid, then over val underneath each aid), so it
-- only ever visits nodes 2 levels deep. No explicit START/END/SKIP
-- is needed to filter out the 1-level nodes.
-- ============================================================

DROP TABLE IF EXISTS TBDR;

CREATE TABLE TBDR
(aid INTEGER PRIMARY KEY,
 val VARCHAR KEY NUM 1,
 vk  VARCHAR)
GLOBAL "^TBDR"
READONLY;