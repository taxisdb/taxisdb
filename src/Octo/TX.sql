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
-- TX.sql
--
-- Octo table definition mapping for YottaDB global ^TX, as
-- extracted in TX.zwr:
--
--   ^TX(7400,"dt")="6593cc2b18340"
--   ^TX(7400,"usr")="Root"
--   ^TX(7401,"dt")="6593cc2b1c5b6"
--   ^TX(7401,"usr")="Root"
--
-- Global layout: ^TX(tx,"dt")=dt and ^TX(tx,"usr")=usr, i.e.
-- two fixed-literal-subscript nodes collapsed into one row per tx:
--   tx     - transaction number (key, INTEGER)
--   dt     - raw datetime token (VARCHAR), from ^TX(tx,"dt")
--   usr    - user name          (VARCHAR), from ^TX(tx,"usr")
--   dtstr  - human-readable datetime, computed from dt via the
--            DATETIME() SQL function, backed by DATETIME^utils,
--            e.g. DATETIME^utils("6593cc2b1c5b6")
--                 = "2026-08-17T11:49:19.604150"
--
-- Each non-key column overrides GLOBAL to point at its own
-- literal subscript under keys("tx"), rather than relying on the
-- default PIECE-of-node-value mapping -- there is no data node
-- at plain ^TX(tx) itself.
-- ============================================================

CREATE FUNCTION IF NOT EXISTS DATETIME(VARCHAR)
RETURNS VARCHAR AS $$DATETIME^utils;

DROP TABLE IF EXISTS TX;

CREATE TABLE TX
(tx     INTEGER PRIMARY KEY,
 dt     VARCHAR EXTRACT "$GET(^TX(keys(""tx""),""dt""))",
 usr    VARCHAR EXTRACT "$GET(^TX(keys(""tx""),""usr""))",
 dtstr  VARCHAR EXTRACT DATETIME(dt))
GLOBAL "^TX"
READONLY;