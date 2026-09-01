;; ============================================================================= 
;; ^sapiUtils - TBox/Schema print helper/utility sub-routines - This file is part of TaxisDB Platform
;;
;; Copyright © 2026 Athanassios Hatzis - athanassios@healis.eu
;; All rights reserved except as granted by the applicable copy-left licenses.
;;
;; TaxisDB Platform includes:
;; TaxisDB 		— database engine licensed under SSPL v1.0
;; TaxisBase 	— knowledge base  licensed under ODbL v1.0 + DBCL v1.0
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
;;==============================================================================

PrintW(wKey,wDesc,wVal)
;;------------------------------------------------------------------
;; Routine  : PrintW^sapiUtils — Procedure (private)
;; Call     : DO PrintW^sapiUtils(.wKey,.wDesc,.wVal)
;;
;; Purpose  : Returns the standard column widths used by all table
;;            rendering routines in this module. Centralising widths
;;            here ensures that PrintDIV, PrintHDR, PrintRow, PrintSection,
;;            and PrintNamespaceSection all stay aligned without
;;            hardcoding the same values in multiple places.
;;
;; Parameters
;;   wKey   : (OUT) Width of the first column  — Global Key
;;   wDesc  : (OUT) Width of the second column — Description
;;   wVal   : (OUT) Width of the third column  — Value
;;
;; Returns  : Nothing (procedure). Caller receives widths by reference.
;;------------------------------------------------------------------
    SET wKey=12
    SET wDesc=30
    SET wVal=6
    QUIT


PrintDIV()
;;------------------------------------------------------------------
;; Function : PrintDIV^sapiUtils
;; Call     : SET div=$$PrintDIV^sapiUtils()
;;
;; Purpose  : Builds and returns a horizontal divider string used to
;;            separate rows in the TBox status table. The divider
;;            spans all three columns using underscore fill characters
;;            with plus signs at each column junction:
;;
;;              +________________________+________________________+________+
;;
;;            Column widths are read from PrintW so the divider
;;            stays aligned automatically if widths change.
;;
;; Parameters: None
;;
;; Returns  : div — formatted divider string ready to WRITE
;;------------------------------------------------------------------
    NEW wKey,wDesc,wVal,div
    DO PrintW(.wKey,.wDesc,.wVal)
    SET div="  +"_$TRANSLATE($JUSTIFY("",wKey+2)," ","_")
    SET div=div_"+"_$TRANSLATE($JUSTIFY("",wDesc+2)," ","_")
    SET div=div_"+"_$TRANSLATE($JUSTIFY("",wVal+2)," ","_")_"+"
    QUIT div


PrintHDR()
;;------------------------------------------------------------------
;; Function : PrintHDR^sapiUtils (private)
;; Call     : SET hdr=$$PrintHDR^sapiUtils()
;;
;; Purpose  : Builds and returns the column header row string for the
;;            TBox status table. The header labels the three columns
;;            with fixed titles, left-aligned in the first two columns
;;            and right-aligned in the value column:
;;
;; 			  | Global Key  | Description | Value |
;;
;;            Column widths are read from PrintW so the header
;;            stays aligned automatically if widths change.
;;
;; Parameters: None
;;
;; Returns  : hdr — formatted header row string ready to WRITE
;;------------------------------------------------------------------
    NEW wKey,wDesc,wVal,hdr
    DO PrintW(.wKey,.wDesc,.wVal)
    SET hdr="  | "_$EXTRACT("Global Key"_$JUSTIFY("",wKey),1,wKey)
    SET hdr=hdr_" | "_$EXTRACT("Description"_$JUSTIFY("",wDesc),1,wDesc)
    SET hdr=hdr_" | "_$JUSTIFY("Value",wVal)_" |"
    QUIT hdr



PrintRow(akey,desc,val)
;;------------------------------------------------------------------
;; Routine  : PrintRow^sapiUtils — Procedure (private)
;; Call     : DO PrintRow^sapiUtils(akey,desc,val)
;;
;; Purpose  : Prints a single formatted data row in the TBox status
;;            table. The akey string is left-aligned in the first
;;            column, the description string is left-aligned in the
;;            second column, and the value is right-aligned in the
;;            third column:
;;
;;              | ^TBEAVT | Total triplet facts |  145 |
;;
;;            Strings longer than the column width are truncated via
;;            $EXTRACT. Column widths are read from PrintW so the
;;            row stays aligned automatically if widths change.
;;
;; Parameters
;;   akey    : (IN) String shown in the first column
;;                 e.g. "^TBEAVT" or "^TBDR(210)"
;;   desc   : (IN) String shown in the second column
;;                 e.g. "Total triplet facts"
;;   val    : (IN) Numeric or string value shown right-aligned
;;                 in the third column e.g. 145
;;
;; Returns  : Nothing (procedure). Output written to current device.
;;------------------------------------------------------------------
    NEW wKey,wDesc,wVal
    DO PrintW(.wKey,.wDesc,.wVal)

    WRITE !,"  | "
    WRITE $EXTRACT(akey_$JUSTIFY("",wKey),1,wKey)
    WRITE " | "
    WRITE $EXTRACT(desc_$JUSTIFY("",wDesc),1,wDesc)
    WRITE " | "
    WRITE $JUSTIFY(val,wVal)
    WRITE " |"
    QUIT


PrintSection(label)
;;------------------------------------------------------------------
;; Routine  : PrintSection^sapiUtils — Procedure (private)
;; Call     : DO PrintSection^sapiUtils(label)
;;
;; Purpose  : Prints a section header block used to introduce a group
;;            of related rows in the TBox status table. The label
;;            appears in the first column, preceded by a blank row
;;            and bracketed by divider lines above and below:
;;              +________________________+________________________+________+
;;              |                        |                        |        |
;;              | Assertions             |                        |        |
;;              +________________________+________________________+________+
;;            Column widths are read from PrintW so the block
;;            stays aligned automatically if widths change.
;;
;; Parameters
;;   label  : (IN) Section title string shown in the first column
;;                 e.g. "Assertions", "Attributes", "Data Type Values"
;;
;; Returns  : Nothing (procedure). Output written to current device.
;;------------------------------------------------------------------
    NEW wKey,wDesc,wVal,emp
    DO PrintW(.wKey,.wDesc,.wVal)

    SET emp="  | "_$JUSTIFY("",wKey)_" | "_$JUSTIFY("",wDesc)_" | "_$JUSTIFY("",wVal)_" |"

    WRITE !,$$PrintDIV
    WRITE !,emp
    WRITE !,"  | "_$EXTRACT(label_$JUSTIFY("",wKey),1,wKey)
    WRITE " | "_$JUSTIFY("",wDesc)
    WRITE " | "_$JUSTIFY("",wVal)_" |"
    WRITE !,$$PrintDIV
    QUIT


PrintNamespaceSection(label,val)
;;------------------------------------------------------------------
;; Routine  : PrintNamespaceSection^sapiUtils — Procedure (private)
;; Call     : DO PrintNamespaceSection^sapiUtils(label,val)
;;
;; Purpose  : Prints a namespace section header block used to
;;            introduce a group of data type rows in the TBox status
;;            table. The namespace label appears in the second column
;;            and the total attribute count in the third column,
;;            bracketed by divider lines above and below:
;;
;;              +________________________+________________________+________+
;;              |                        | sys.attr               |      9 |
;;              +________________________+________________________+________+
;;
;;            Column widths are read from PrintW so the block
;;            stays aligned automatically if widths change.
;;
;; Parameters
;;   label  : (IN) Namespace prefix string shown in the description
;;                 column e.g. "sys.attr" or "sandbox.movie"
;;   val    : (IN) Numeric value shown in the value column e.g.
;;                 total attribute count for this namespace
;;
;; Returns  : Nothing (procedure). Output written to current device.
;;------------------------------------------------------------------
    NEW wKey,wDesc,wVal
    DO PrintW(.wKey,.wDesc,.wVal)

    WRITE !,$$PrintDIV
    WRITE !,"  | "_$JUSTIFY("",wKey)
    WRITE " | "_$EXTRACT(label_$JUSTIFY("",wDesc),1,wDesc)
    WRITE " | "_$JUSTIFY(val,wVal)_" |"
    WRITE !,$$PrintDIV
    QUIT
