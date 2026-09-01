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
-- TBKW.sql
--
-- Octo table definition mapping for YottaDB global ^TBKW, as
-- extracted in TBKW.zwr:
--
--   ^TBKW("obj.claudio_arrau",0)="ClaudioArrau"
--   ^TBKW("obj.tom_hanks",0)="TomHanks"
--   ^TBKW("obj.tom_hanks",1)="%TomHanks"
--
-- Global layout: ^TBKW(key,alsndx)=als
--   ekey    - entity key identifier (1st subscript, VARCHAR)
--   alsndx  - alias index, distinguishes multiple aliases per ekey
--             (2nd subscript, INTEGER)
--   als     - the alias text itself (node value, VARCHAR)
-- ============================================================

DROP TABLE IF EXISTS TBKW;

CREATE TABLE TBKW
(ekey VARCHAR PRIMARY KEY,
 alsndx INTEGER KEY NUM 1,
 als    VARCHAR)
GLOBAL "^TBKW"
READONLY;