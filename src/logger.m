;; =============================================================================================================== 
;; ^logger - Logging utility for configurable, debug-level based messages - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 	— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;; ===============================================================================================================

INIT(level,output,trace,origin) ;  initializes logger configuration for a NEW session
    ; Each call creates a new numbered "session" under $JOB, rather than
    ; overwriting a single shared CFG node. This gives a full history of
    ; every (re)initialization for the process, and lets LOG/SEQ continue
    ; seamlessly across sessions.
    ;
    NEW session,prevseq,label
    SET origin=$GET(origin,"SETUP")   ; "SETUP" (explicit) or "AUTO" (guard-triggered)

    SET session=$INCREMENT(^TXLOG($JOB,"SESSIONS"))
    SET ^TXLOG($JOB,"CURRENT")=session   ; pointer LOG uses to find active CFG

    ; Carry the running sequence number forward from the prior session,
    ; instead of resetting to 0, so seq numbers stay unique per process.
    SET prevseq=0
    IF session>1 SET prevseq=$GET(^TXLOG($JOB,session-1,"CFG","SEQ"),0)

    SET ^TXLOG($JOB,session,"CFG","LEVEL")=level
    SET ^TXLOG($JOB,session,"CFG","OUTPUT")=$GET(output,0)
    SET ^TXLOG($JOB,session,"CFG","TRACE")=$GET(trace,0)
    SET ^TXLOG($JOB,session,"CFG","SEQ")=prevseq

    ; Label the session-start marker depending on how we got here
    IF origin="AUTO" SET label="AUTO-STARTED at"
    ELSE  IF session=1 SET label="STARTED at"
    ELSE  SET label="RESTARTED at"
    SET ^TXLOG($JOB,session,"CFG",label)=$$DATETIME^utils($$EPOCH^utils())
    QUIT


Setup(levelstr,output,trace)
;;------------------------------------------------------------------
;; Procedure : Setup
;; Call      : DO Setup^logger(levelstr,output,trace)
;;
;; Example   : DO Setup^logger("DEBUG",1,0)
;;             DO Setup^logger("INFO",1,0)
;;             DO Setup^logger("WARNING",0,1)
;;
;; Purpose   : Convenience wrapper around INIT — configures the
;;             logger using a human-readable severity level string
;;             (e.g. "ERROR") instead of requiring the caller to know
;;             logger.m's numeric level scheme (10/20/30/40/50).
;;             Single shared entry point for every module (api.m,
;;             sapi.m, ...) that wants string-level logger setup —
;;             avoids each module reimplementing this translation.
;;
;; Parameters
;;   name     : (IN) Logical logger name stamped into every
;;              formatted log line (e.g. "API", "SAPI").
;;   levelstr : (IN, optional) One of "DEBUG","INFO","WARNING",
;;              "ERROR","CRITICAL" (case-insensitive).
;;              Default: "ERROR".
;;   output   : (IN, optional) 1=also print to console, 0=silent.
;;              Default: 1.
;;   trace    : (IN, optional) 1=capture $STACK trace per log entry,
;;              0=don't. Default: 0.
;;
;; Returns  : Nothing (procedure)
;;
;; Sets     : ^TXLOG("CFG",...) via INIT — see above
;;
;; Notice   : The logical name stamped into each log line (e.g. "API",
;;            "SAPI") is supplied per-call as the first argument to the 
;; 			  LOG*^logger entry points, so a single process can log on behalf 
;;			  of several modules without re-running Setup for each one.
;;------------------------------------------------------------------
    NEW level
    SET levelstr=$GET(levelstr,"ERROR")
    SET output=$GET(output,1)
    SET trace=$GET(trace,0)

    SET level=$$LEVELNUM(levelstr)
    DO INIT(level,output,trace,"SETUP")
    QUIT


; Numeric Severity Level Constants
;
LVLDEBUG()    ; Lowest level: detailed diagnostic information
    QUIT 10
LVLINFO()     ; Normal operational messages
    QUIT 20
LVLWARNING()  ; Unexpected situations, but execution continues
    QUIT 30
LVLERROR()    ; Operation failed
    QUIT 40
LVLCRITICAL() ; System may not continue (unexpected runtime error %YDB-E-....)
    QUIT 50
 

LEVELNAME(level) ; Map Numeric Level → Text Label
    ; Convert numeric severity to human-readable label
    IF level=50 QUIT "CRITICAL"
    IF level=40 QUIT "ERROR"
    IF level=30 QUIT "WARNING"
    IF level=20 QUIT "INFO"
    IF level=10 QUIT "DEBUG"
    ; Default fallback
    QUIT "NOTSET"


LEVELNUM(levelname) ; Map Text Label → Numeric Level
    ; Convert human-readable severity label to its numeric level.
    ; Inverse of LEVELNAME. Case-insensitive — normalizes to
    ; uppercase before matching.
    ; Unknown/invalid input defaults to INFO (20) — same numeric
    ; default LOG already falls back to via $GET(^TXLOG("CFG","LEVEL"),20)
    ; when no level has been configured at all.
    NEW lvl
    SET lvl=$ZCONVERT($GET(levelname,"INFO"),"U")
    IF lvl="DEBUG"    QUIT $$LVLDEBUG()
    IF lvl="INFO"     QUIT $$LVLINFO()
    IF lvl="WARNING"  QUIT $$LVLWARNING()
    IF lvl="ERROR"    QUIT $$LVLERROR()
    IF lvl="CRITICAL" QUIT $$LVLCRITICAL()
    QUIT $$LVLINFO()


; Convenience wrapper APIs for logging at specific severity levels.
; These should be used instead of calling LOG(level,msg) directly.
;
; Rationale:
; - Eliminates the need for callers to know numeric level values (10,20,...)
; - Improves readability and intent (e.g. LOGERROR vs LOG(40,...))
; - Prevents misuse or inconsistent level assignment across the codebase
;
; Every wrapper takes `name` as its first parameter — the calling
; module's logical name (e.g. "API", "SAPI") — followed by `msg`. This
; lets a single process log on behalf of multiple modules without
; needing a separate Setup call or global name state per module.
;
LOGDEBUG(name,msg)
    ; Log a DEBUG-level message
    ; Used for detailed diagnostic output (typically suppressed in production)    
    DO LOG($$LVLDEBUG,name,msg)
    QUIT

LOGINFO(name,msg)
    ; Log an INFO-level message
    ; Used for normal operational confirmations    
    DO LOG($$LVLINFO(),name,msg)
    QUIT

LOGWARNING(name,msg)
    ; Log a WARNING-level message
    ; Indicates a potential issue or unexpected situation
    DO LOG($$LVLWARNING(),name,msg)
    QUIT

LOGERROR(name,msg)
    ; Log an ERROR-level message
    ; Indicates a failure in a specific operation
    DO LOG($$LVLERROR(),name,msg)
    QUIT

LOGCRITICAL(name,msg)
    ; Log a CRITICAL-level message
    ; Indicates a severe failure that may stop the system
    DO LOG($$LVLCRITICAL(),name,msg)
    QUIT


LOG(level,name,msg)
    ; ------------------------------------------------------------
    ; Description:
    ; Main logging entry point for the system. Handles log filtering
    ; based on the active session's configured severity level, formats
    ; the log message, persists it into YottaDB globals under the
    ; process's current session, and optionally captures execution
    ; stack trace information when trace mode is enabled.
    ;
    ; This routine is intended to be called indirectly via the
    ; LOG* convenience wrappers (LOGDEBUG, LOGINFO, LOGWARNING,
    ; LOGERROR, LOGCRITICAL) rather than directly.
    ;
    ; ------------------------------------------------------------
    ; Parameters:
    ; level  - Numeric severity level of the log message
    ;          (10=DEBUG, 20=INFO, 30=WARNING, 40=ERROR, 50=CRITICAL)
    ;
    ; name   - Logical name of the calling module, stamped into the
    ;          formatted log line (e.g. "API", "SAPI"). Supplied by
    ;          the caller on every call.
    ;
    ; msg    - Text message to be logged
    ; ------------------------------------------------------------
    ; Returns:
    ; None (procedure)
    ; Side effects only:
    ;   - Writes formatted log entry to ^TXLOG($JOB,session,seq)
    ;   - Outputs message to console
    ;   - Optionally writes stack trace to ^TXLOG($JOB,session,seq,i)
    ; ------------------------------------------------------------
    ; Sessions:
    ;   Every process keeps its own numbered "sessions" under
    ;   ^TXLOG($JOB,session,"CFG",...), one per call to INIT/Setup —
    ;   each (re)configuration opens a new session rather than
    ;   overwriting a single shared CFG node. ^TXLOG($JOB,"CURRENT")
    ;   points at whichever session is currently active, and that
    ;   session's CFG values (LEVEL/OUTPUT/TRACE/SEQ) are what govern
    ;   this call. SEQ carries forward from the prior session so log
    ;   entry numbers stay unique and increasing across the whole
    ;   process, even after a re-init.
    ; ------------------------------------------------------------
    ; Guard:
    ;   If Setup^logger/INIT^logger was never called in this process,
    ;   ^TXLOG($JOB,"CURRENT") does not exist. This routine detects
    ;   that case, auto-initializes a new session with safe defaults
    ;   (LEVEL=INFO, OUTPUT=1, TRACE=0) via INIT(...,"AUTO"), and
    ;   prints a console warning — so a missing Setup call is visible
    ;   and diagnosable rather than a crash. The session itself is
    ;   stamped with CFG("AUTO-STARTED at") by INIT, so no separate
    ;   marker needs to be written here.
    ; ------------------------------------------------------------
    NEW i,cfgLevel,tshex,tschar,seq,formatted,traceflag,outflag,notinit,session

    SET notinit='$DATA(^TXLOG($JOB,"CURRENT"))
    IF notinit DO
    . DO INIT(20,1,0,"AUTO")    ; safe defaults, opens session 1 (or next) as AUTO
    . WRITE !,"WARNING: logger^logger was not initialized — call DO Setup^logger(""INFO"",1,0) before logging. Falling back to LEVEL=INFO, OUTPUT=1, TRACE=0.",!

    SET session=^TXLOG($JOB,"CURRENT")

    SET cfgLevel=$GET(^TXLOG($JOB,session,"CFG","LEVEL"),20)
    SET traceflag=$GET(^TXLOG($JOB,session,"CFG","TRACE"),0)
    SET outflag=$GET(^TXLOG($JOB,session,"CFG","OUTPUT"),1)

    IF level<cfgLevel QUIT

    SET name=$GET(name,"DEFAULT")

    SET tshex=$$EPOCH^utils()
    SET tschar=$$DATETIME^utils(tshex)

    ; Per-session sequence number — continues across re-inits
    SET seq=$INCREMENT(^TXLOG($JOB,session,"CFG","SEQ"))

    SET formatted=tschar_" | "_name_" | "_$$LEVELNAME(level)_" | "_msg

    ; ^TXLOG($JOB,session,seq)
    SET ^TXLOG($JOB,session,seq)=formatted

    IF traceflag DO
    . NEW i
    . FOR i=$STACK:-1:0 DO
    . . SET ^TXLOG($JOB,session,seq,i)=$STACK(i,"PLACE")

    IF outflag DO
    . WRITE !,formatted,!

    QUIT
