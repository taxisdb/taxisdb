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
-- TXLOG.sql
--
-- Octo table definition mapping for YottaDB global ^TXLOG, as
-- extracted in TXLOG.zwr:
--
--   ^TXLOG(1649717,1,1753)="2026-08-17T20:40:05.219549 | API | DEBUG | Transact: ^EATV(659442cd741f3nkh1hbg,1000,7412,K3E8.018920)=1"
--   ^TXLOG(1649717,1,1754)="2026-08-17T20:40:05.219565 | API | DEBUG | Transact: ^EATV(659442cd741f3nkh1hbg,1001,7412,K3E9.018909)=1"
--
-- Global layout: ^TXLOG(job,sescnt,msgcnt)=dt | module | dlevel | msg
--   job     - Process $JOB number the message was logged from      (1st subscript, INTEGER)
--   sescnt  - session counter within the process      				(2nd subscript, INTEGER)
--   msgcnt  - message counter within the session    				(3rd subscript, INTEGER)
--   dt      - ISO-ish datetime string                				(node value, piece 1 of " | ")
--   module  - routine/module name, e.g. "API"        				(node value, piece 2 of " | ")
--   dlevel  - debug level, e.g. "DEBUG"               				(node value, piece 3 of " | ")
--   msg     - free-text log message, e.g. "Transact: ^EATV(...)=1" (node value, piece 4 through end of " | ")
--
-- dt/module/dlevel use the built-in PIECE/DELIM mapping since each is a single fixed field position. 
-- msg uses EXTRACT with an M $PIECE range (4,9999) instead of a plain PIECE 4, so that if the
-- free-text message itself ever contains the " | " delimiter sequence, the entire remainder 
-- is still captured rather than truncated at the first embedded occurrence.
-- ============================================================

DROP TABLE IF EXISTS TXLOG;

CREATE TABLE TXLOG
(job     INTEGER PRIMARY KEY,
 sescnt  INTEGER KEY NUM 1,
 msgcnt  INTEGER KEY NUM 2,
 dt      VARCHAR PIECE 1 DELIM " | ",
 module  VARCHAR PIECE 2 DELIM " | ",
 dlevel  VARCHAR PIECE 3 DELIM " | ",
 msg     VARCHAR EXTRACT "$PIECE($GET(^TXLOG(keys(""job""),keys(""sescnt""),keys(""msgcnt""))),"" | "",4,9999)")
GLOBAL "^TXLOG"
READONLY;