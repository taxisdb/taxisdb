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
-- TXE.sql
--
-- Octo table definition mapping for YottaDB global ^TXE, as
-- extracted in TXE.zwr:
--
--   ^TXE(7409,1049)=""
--   ^TXE(7410,"6594429848c456am0zuv")=""
--
-- Global layout: ^TXE(tx,eid)="" (node value unused/empty)
--   tx  - transaction number (1st subscript, INTEGER)
--   eid - entity ID          (2nd subscript, VARCHAR -- mixed
--         numeric-looking and alphanumeric values, e.g. 1049 vs.
--         "6594429848c456am0zuv", so VARCHAR covers both)
-- ============================================================

DROP TABLE IF EXISTS TXE;

CREATE TABLE TXE
(tx  INTEGER PRIMARY KEY,
 eid VARCHAR KEY NUM 1)
GLOBAL "^TXE"
READONLY;