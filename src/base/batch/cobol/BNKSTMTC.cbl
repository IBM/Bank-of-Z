       CBL SQL
      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2026                                      *
      *                                                                *
      ******************************************************************
      *                                                                *
      *  BNKSTMTC  -  Bank of Z Monthly Customer Statement            *
      *                                                                *
      *  Enterprise COBOL for z/OS 6.3 batch Db2 program.             *
      *                                                                *
      *  DD names:                                                     *
      *    SYSIN    - 80-byte control card  (<CustID> <YYYY-MM>)       *
      *    SYSOUT   - Diagnostic / informational messages              *
      *    SYSPRINT - FBA 133-byte formatted statement report          *
      *                                                                *
      *  Return codes:                                                 *
      *    0  - Clean run, all accounts and transactions present       *
      *    4  - Informational condition (BNKZI messages emitted)       *
      *    8  - Error condition     (BNKZE messages emitted)           *
      *   12  - SYSOUT unavailable (no diagnostics possible)           *
      *                                                                *
      ******************************************************************

       IDENTIFICATION DIVISION.
       PROGRAM-ID. BNKSTMTC.
       AUTHOR.     IBM.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.

           SELECT SYSIN-FILE
               ASSIGN TO SYSIN
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL
               FILE STATUS  IS WS-SYSIN-STATUS.

           SELECT SYSPRINT-FILE
               ASSIGN TO SYSPRINT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL
               FILE STATUS  IS WS-SYSPRINT-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD  SYSIN-FILE
           RECORDING MODE F
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 80 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  SYSIN-RECORD               PIC X(80).

       FD  SYSPRINT-FILE
           RECORDING MODE F
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 133 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  SYSPRINT-RECORD            PIC X(133).

       WORKING-STORAGE SECTION.

      *-----------------------------------------------------------------
      * Db2 table declarations
      *-----------------------------------------------------------------
           EXEC SQL
               INCLUDE CUSTDB2
           END-EXEC.

           EXEC SQL
               INCLUDE ACCDB2
           END-EXEC.

           EXEC SQL
               INCLUDE PROCDB2
           END-EXEC.

      *-----------------------------------------------------------------
      * SQL Communications Area
      *-----------------------------------------------------------------
           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      *-----------------------------------------------------------------
      * Sort code constant
      *-----------------------------------------------------------------
           COPY SORTCODE.

      *-----------------------------------------------------------------
      * Account cursor - all accounts for this customer
      *-----------------------------------------------------------------
           EXEC SQL DECLARE ACCT-CURSOR CURSOR FOR
               SELECT ACCOUNT_NUMBER,
                      ACCOUNT_SORTCODE,
                      ACCOUNT_TYPE,
                      ACCOUNT_ACTUAL_BALANCE
               FROM   BANKZ.ACCOUNT
               WHERE  ACCOUNT_CUSTOMER_NUMBER = :HV-CUST-NUMBER
               ORDER BY ACCOUNT_NUMBER ASC
               FOR FETCH ONLY
           END-EXEC.

      *-----------------------------------------------------------------
      * Transaction cursor - transactions for one account/period
      *-----------------------------------------------------------------
           EXEC SQL DECLARE TRAN-CURSOR CURSOR FOR
               SELECT CHAR(PROCTRAN_DATE, ISO),
                      PROCTRAN_TIME,
                      PROCTRAN_TYPE,
                      PROCTRAN_DESC,
                      PROCTRAN_AMOUNT
               FROM   BANKZ.PROCTRAN
               WHERE  PROCTRAN_SORTCODE = :HV-ACCT-SORTCODE
                 AND  PROCTRAN_NUMBER   = :HV-ACCT-NUMBER
                 AND  PROCTRAN_DATE    >= :HV-PERIOD-FROM
                 AND  PROCTRAN_DATE    <= :HV-PERIOD-TO
               ORDER BY PROCTRAN_DATE ASC,
                        PROCTRAN_TIME ASC
               FOR FETCH ONLY
           END-EXEC.

      *-----------------------------------------------------------------
      * Host variables - customer query (SELECT INTO)
      *-----------------------------------------------------------------
       01  HV-CUST-NUMBER             PIC X(10).
       01  HOST-CUSTOMER-ROW.
           03 HV-CUST-TITLE           PIC X(10).
           03 HV-CUST-FIRST-NAME      PIC X(50).
           03 HV-CUST-LAST-NAME       PIC X(50).
           03 HV-CUST-ADDR1           PIC X(50).
           03 HV-CUST-ADDR2           PIC X(50).
           03 HV-CUST-CITY            PIC X(50).
           03 HV-CUST-POSTCODE        PIC X(10).
           03 HV-CUST-COUNTRY         PIC X(50).
           03 HV-CUST-PHONE           PIC X(20).
       01  HV-CUST-SORTCODE           PIC X(6).

      *-----------------------------------------------------------------
      * Null indicators - customer nullable columns
      *-----------------------------------------------------------------
       01  WS-CUST-NULL-IND.
           03 NI-CUST-TITLE           PIC S9(4) COMP VALUE 0.
           03 NI-CUST-FNAME           PIC S9(4) COMP VALUE 0.
           03 NI-CUST-LNAME           PIC S9(4) COMP VALUE 0.
           03 NI-CUST-ADDR1           PIC S9(4) COMP VALUE 0.
           03 NI-CUST-ADDR2           PIC S9(4) COMP VALUE 0.
           03 NI-CUST-CITY            PIC S9(4) COMP VALUE 0.
           03 NI-CUST-POSTCODE        PIC S9(4) COMP VALUE 0.
           03 NI-CUST-COUNTRY         PIC S9(4) COMP VALUE 0.
           03 NI-CUST-PHONE           PIC S9(4) COMP VALUE 0.

      *-----------------------------------------------------------------
      * Host variables - account cursor fetch
      *-----------------------------------------------------------------
       01  HV-ACCT-NUMBER             PIC X(8).
       01  HV-ACCT-SORTCODE           PIC X(6).
       01  HV-ACCT-TYPE               PIC X(8).
       01  HV-ACCT-ACTUAL-BAL         PIC S9(10)V99 COMP-3.

      *-----------------------------------------------------------------
      * Host variables - transaction cursor fetch
      *-----------------------------------------------------------------
       01  HV-TRAN-DATE               PIC X(10).
       01  HV-TRAN-TIME               PIC X(6).
       01  HV-TRAN-TYPE               PIC X(3).
       01  HV-TRAN-DESC               PIC X(40).
       01  HV-TRAN-AMOUNT             PIC S9(12)V99 COMP-3.

      *-----------------------------------------------------------------
      * Null indicators - transaction nullable columns
      *-----------------------------------------------------------------
       01  WS-TRAN-NULL-IND.
           03 NI-TRAN-TYPE            PIC S9(4) COMP VALUE 0.
           03 NI-TRAN-DESC            PIC S9(4) COMP VALUE 0.
           03 NI-TRAN-AMOUNT          PIC S9(4) COMP VALUE 0.

      *-----------------------------------------------------------------
      * Period host variables (ISO date strings YYYY-MM-DD)
      *-----------------------------------------------------------------
       01  HV-PERIOD-FROM             PIC X(10).
       01  HV-PERIOD-TO               PIC X(10).

      *-----------------------------------------------------------------
      * SQLCODE display copy for messages
      *-----------------------------------------------------------------
       01  SQLCODE-DISPLAY            PIC S9(8) DISPLAY
               SIGN LEADING SEPARATE.

      *-----------------------------------------------------------------
      * File status fields
      *-----------------------------------------------------------------
       01  WS-SYSIN-STATUS            PIC XX VALUE '00'.
       01  WS-SYSPRINT-STATUS         PIC XX VALUE '00'.

      *-----------------------------------------------------------------
      * Cursor / EOF flags
      *-----------------------------------------------------------------
       01  WS-SYSIN-OPEN              PIC X VALUE 'N'.
       01  WS-SYSPRINT-OPEN           PIC X VALUE 'N'.
       01  WS-ACCT-CURSOR-OPEN        PIC X VALUE 'N'.
       01  WS-TRAN-CURSOR-OPEN        PIC X VALUE 'N'.
       01  WS-SYSIN-EOF               PIC X VALUE 'N'.
       01  WS-ACCT-EOF                PIC X VALUE 'N'.
       01  WS-TRAN-EOF                PIC X VALUE 'N'.

      *-----------------------------------------------------------------
      * SYSIN parsing fields
      *-----------------------------------------------------------------
       01  WS-SYSIN-RECORD.
           03 WS-RAW-CUSTID           PIC X(10).
           03 WS-SYSIN-SPACE          PIC X.
           03 WS-PERIOD-RAW.
               05 WS-PERIOD-YYYY      PIC X(4).
               05 WS-PERIOD-DASH      PIC X.
               05 WS-PERIOD-MM        PIC X(2).
           03 FILLER                  PIC X(62).

       01  WS-SYSIN-RECORD-COUNT      PIC 9(4) COMP VALUE 0.
       01  WS-SYSIN-ERROR-COUNT       PIC 9(4) COMP VALUE 0.
       01  WS-SYSIN-SAVED-RECORD      PIC X(80) VALUE SPACES.

      *-----------------------------------------------------------------
      * Customer ID normalisation fields
      *-----------------------------------------------------------------
       01  WS-CUST-PREFIX             PIC X.
      *    Raw digits: 9 usable positions from SYSIN cols 2-10, plus
      *    one extra byte so we can detect > 9 digit overruns.
       01  WS-CUST-RAW-DIGITS         PIC X(10).
       01  WS-DIGIT-LEN               PIC 9(4) COMP VALUE 0.
       01  WS-CUST-ID-CANONICAL       PIC X(10).
       01  WS-CUST-NUMBER-STRIPPED    PIC X(10).
       01  WS-DIGIT-IDX               PIC S9(4) COMP VALUE 0.
       01  WS-DIGIT-WORK              PIC X(9).
       01  WS-DIGIT-NUMERIC           PIC 9(9) COMP VALUE 0.
       01  WS-DIGIT-EDIT              PIC 9(9).

      *-----------------------------------------------------------------
      * Statement period date calculation fields
      *-----------------------------------------------------------------
       01  WS-PERIOD-YYYY-NUM         PIC 9(4) COMP VALUE 0.
       01  WS-PERIOD-MM-NUM           PIC 99 COMP VALUE 0.
       01  WS-PERIOD-DD-END           PIC 99 COMP VALUE 0.
       01  WS-LEAP-YEAR-FLAG          PIC X VALUE 'N'.
       01  WS-LEAP-WORK               PIC 9(4) COMP VALUE 0.
       01  WS-LEAP-REMAINDER          PIC 9(4) COMP VALUE 0.

      *-----------------------------------------------------------------
      * Current system date
      *-----------------------------------------------------------------
       01  WS-CURRENT-DATE-21         PIC X(21).
       01  WS-CURR-DATE-GRP REDEFINES WS-CURRENT-DATE-21.
           03 WS-CURR-YYYY            PIC X(4).
           03 WS-CURR-MM              PIC X(2).
           03 WS-CURR-DD              PIC X(2).
           03 FILLER                  PIC X(13).

      *-----------------------------------------------------------------
      * Program return code
      *-----------------------------------------------------------------
       01  WS-RETURN-CODE             PIC S9(4) COMP VALUE 0.

      *-----------------------------------------------------------------
      * Pagination control
      *-----------------------------------------------------------------
       01  WS-PAGE-NUMBER             PIC 9(6) COMP VALUE 1.
       01  WS-LINE-COUNT              PIC 9(4) COMP VALUE 0.
       01  WS-LINES-PER-PAGE          PIC 9(4) COMP VALUE 55.
       01  WS-ACCT-SEQ                PIC 9(4) COMP VALUE 0.

      *-----------------------------------------------------------------
      * Per-account accumulators (reset each account)
      *-----------------------------------------------------------------
       01  WS-TOTAL-WITHDRAWALS       PIC S9(12)V99 COMP-3 VALUE 0.
       01  WS-TOTAL-DEPOSITS          PIC S9(12)V99 COMP-3 VALUE 0.
       01  WS-RUNNING-BALANCE         PIC S9(12)V99 COMP-3 VALUE 0.
       01  WS-TRAN-COUNT              PIC 9(6) COMP VALUE 0.
       01  WS-ABS-AMOUNT              PIC S9(12)V99 COMP-3 VALUE 0.

      *-----------------------------------------------------------------
      * Currency symbol
      *-----------------------------------------------------------------
       01  WS-CURRENCY-SYMBOL         PIC X VALUE '$'.

      *-----------------------------------------------------------------
      * General message work field
      *-----------------------------------------------------------------
       01  WS-MSG                     PIC X(132).

      *-----------------------------------------------------------------
      * Transaction classification flag
      *-----------------------------------------------------------------
       01  WS-TRAN-CLASS              PIC X(1).
           88 TRAN-IS-DEPOSIT         VALUE 'D'.
           88 TRAN-IS-WITHDRAWAL      VALUE 'W'.
           88 TRAN-IS-INFO            VALUE 'I'.

      *-----------------------------------------------------------------
      * Amount editing work fields
      *-----------------------------------------------------------------
       01  WS-AMT-EDIT-POS            PIC $$,$$$,$$$,$$9.99.
       01  WS-AMT-WORK-POS            PIC S9(12)V99 COMP-3.
       01  WS-AMT-FORMATTED           PIC X(17).
       01  WS-AMT-FORMATTED-14        PIC X(14).
       01  WS-AMT-TEMP                PIC X(17).

      *-----------------------------------------------------------------
      * Sort-code display work (raw 6-digit -> NN-NN-NN)
      *-----------------------------------------------------------------
       01  WS-SORTCODE-DISP.
           03 WS-SC-D1                PIC X(2).
           03 FILLER                  PIC X VALUE '-'.
           03 WS-SC-D2                PIC X(2).
           03 FILLER                  PIC X VALUE '-'.
           03 WS-SC-D3                PIC X(2).

       01  WS-SORTCODE-RAW            PIC X(6).
       01  WS-SORTCODE-RAW-R REDEFINES WS-SORTCODE-RAW.
           03 WS-SC-R1                PIC X(2).
           03 WS-SC-R2                PIC X(2).
           03 WS-SC-R3                PIC X(2).

      *-----------------------------------------------------------------
      * Transaction date display work (ISO -> Mmm DD, YYYY)
      *-----------------------------------------------------------------
       01  WS-TRAN-DATE-DISP          PIC X(12).
       01  WS-TRAN-DATE-WORK.
           03 WS-TD-YYYY              PIC X(4).
           03 FILLER                  PIC X.
           03 WS-TD-MM                PIC X(2).
           03 FILLER                  PIC X.
           03 WS-TD-DD                PIC X(2).

       01  WS-MONTH-ABBR-TABLE.
           03 FILLER PIC X(3) VALUE 'Jan'.
           03 FILLER PIC X(3) VALUE 'Feb'.
           03 FILLER PIC X(3) VALUE 'Mar'.
           03 FILLER PIC X(3) VALUE 'Apr'.
           03 FILLER PIC X(3) VALUE 'May'.
           03 FILLER PIC X(3) VALUE 'Jun'.
           03 FILLER PIC X(3) VALUE 'Jul'.
           03 FILLER PIC X(3) VALUE 'Aug'.
           03 FILLER PIC X(3) VALUE 'Sep'.
           03 FILLER PIC X(3) VALUE 'Oct'.
           03 FILLER PIC X(3) VALUE 'Nov'.
           03 FILLER PIC X(3) VALUE 'Dec'.
       01  WS-MONTH-ABBR-IDX          PIC 99 COMP VALUE 1.
       01  WS-MONTH-ABBR REDEFINES WS-MONTH-ABBR-TABLE.
           03 WS-MON-ABBR             PIC X(3) OCCURS 12 TIMES.

      *-----------------------------------------------------------------
      * Name display work field (Title FirstName LastName)
      *-----------------------------------------------------------------
       01  WS-CUST-NAME-DISP          PIC X(115).

      *-----------------------------------------------------------------
      * Page number editing
      *-----------------------------------------------------------------
       01  WS-PAGE-EDIT               PIC ZZZZZ9.

      *-----------------------------------------------------------------
      * Period display strings (YYYY-MM-DD)
      *-----------------------------------------------------------------
       01  WS-PERIOD-FROM-DISP        PIC X(10).
       01  WS-PERIOD-TO-DISP          PIC X(10).
       01  WS-ISSUE-DATE-DISP         PIC X(10).

      *-----------------------------------------------------------------
      * SYSPRINT 133-byte line buffer
      * Column 1 = ANSI carriage control; columns 2-133 = print data
      *-----------------------------------------------------------------
       01  WS-PRINT-LINE.
           03 WS-PL-CC                PIC X.
           03 WS-PL-DATA              PIC X(132).

      *-----------------------------------------------------------------
      * Fixed report line constants
      *-----------------------------------------------------------------
       01  WS-BANNER-LINE             PIC X(132) VALUE ALL '='.

       01  WS-ACCT-SEP-LINE           PIC X(132) VALUE ALL '-'.

       01  WS-COL-HDR-LINE.
           03 FILLER PIC X(12) VALUE 'DATE        '.
           03 FILLER PIC X(2)  VALUE '  '.
           03 FILLER PIC X(40) VALUE
               'TRANSACTION DESCRIPTION                 '.
           03 FILLER PIC X(2)  VALUE '  '.
           03 FILLER PIC X(14) VALUE '    WITHDRAWAL'.
           03 FILLER PIC X(2)  VALUE '  '.
           03 FILLER PIC X(14) VALUE '       DEPOSIT'.
           03 FILLER PIC X(2)  VALUE '  '.
           03 FILLER PIC X(17) VALUE '  RUNNING BALANCE'.
           03 FILLER PIC X(27) VALUE SPACES.

       01  WS-COL-SEP-LINE.
           03 FILLER PIC X(12) VALUE '------------'.
           03 FILLER PIC X(2)  VALUE '  '.
           03 FILLER PIC X(40) VALUE
               '----------------------------------------'.
           03 FILLER PIC X(2)  VALUE '  '.
           03 FILLER PIC X(14) VALUE '--------------'.
           03 FILLER PIC X(2)  VALUE '  '.
           03 FILLER PIC X(14) VALUE '--------------'.
           03 FILLER PIC X(2)  VALUE '  '.
           03 FILLER PIC X(17) VALUE '-----------------'.
           03 FILLER PIC X(27) VALUE SPACES.

      *-----------------------------------------------------------------
      * Transaction detail print line (132 chars per spec §4.3.1)
      *   DATE        cols  1-12  (12)
      *   space-sep   cols 13-14  ( 2)
      *   DESCRIPTION cols 15-54  (40)
      *   space-sep   cols 55-56  ( 2)
      *   WITHDRAWAL  cols 57-70  (14)
      *   space-sep   cols 71-72  ( 2)
      *   DEPOSIT     cols 73-86  (14)
      *   space-sep   cols 87-88  ( 2)
      *   RUN-BAL     cols 89-105 (17)
      *   reserved    cols 106-132(27)
      *-----------------------------------------------------------------
       01  WS-TRAN-LINE.
           03 WS-TL-DATE              PIC X(12).
           03 FILLER                  PIC X(2) VALUE SPACES.
           03 WS-TL-DESC              PIC X(40).
           03 FILLER                  PIC X(2) VALUE SPACES.
           03 WS-TL-WITHDRAWAL        PIC X(14).
           03 FILLER                  PIC X(2) VALUE SPACES.
           03 WS-TL-DEPOSIT           PIC X(14).
           03 FILLER                  PIC X(2) VALUE SPACES.
           03 WS-TL-RUN-BAL           PIC X(17).
           03 FILLER                  PIC X(27) VALUE SPACES.

      *-----------------------------------------------------------------
      * Account header line
      *-----------------------------------------------------------------
       01  WS-ACCT-HDR-LINE.
           03 FILLER                  PIC X(14)
               VALUE 'ACCOUNT TYPE: '.
           03 WS-AH-TYPE              PIC X(8).
           03 FILLER                  PIC X(27) VALUE SPACES.
           03 FILLER                  PIC X(16)
               VALUE 'ACCOUNT NUMBER: '.
           03 WS-AH-NUMBER            PIC X(8).
           03 FILLER                  PIC X(22) VALUE SPACES.
           03 FILLER                  PIC X(11)
               VALUE 'SORT CODE: '.
           03 WS-AH-SORTCODE          PIC X(8).
           03 FILLER                  PIC X(18) VALUE SPACES.

      *-----------------------------------------------------------------
      * Page header lines
      *-----------------------------------------------------------------
       01  WS-PAGE-HDR-LINE.
           03 FILLER                  PIC X(10) VALUE 'BANK OF Z '.
           03 FILLER                  PIC X(37) VALUE SPACES.
           03 FILLER                  PIC X(28)
               VALUE 'MONTHLY CUSTOMER STATEMENT  '.
           03 FILLER                  PIC X(45) VALUE SPACES.
           03 FILLER                  PIC X(6)  VALUE 'PAGE: '.
           03 WS-PH-PAGE-NO           PIC X(6).

       01  WS-STMT-PERIOD-LINE.
           03 FILLER                  PIC X(18)
               VALUE 'STATEMENT PERIOD: '.
           03 WS-SP-FROM              PIC X(10).
           03 FILLER                  PIC X(4)  VALUE ' TO '.
           03 WS-SP-TO                PIC X(10).
           03 FILLER                  PIC X(58) VALUE SPACES.
           03 FILLER                  PIC X(22)
               VALUE 'STATEMENT ISSUE DATE: '.
           03 WS-SP-ISSUE             PIC X(10).

       01  WS-CUSTID-LINE.
           03 FILLER                  PIC X(18)
               VALUE 'CUSTOMER ID     : '.
           03 WS-CL-CUSTID            PIC X(10).
           03 FILLER                  PIC X(104) VALUE SPACES.

      *-----------------------------------------------------------------
      * Customer information block lines
      *-----------------------------------------------------------------
       01  WS-CUSTINFO-HDR            PIC X(132)
               VALUE 'CUSTOMER INFORMATION:'.

       01  WS-CI-NAME-LINE.
           03 FILLER                  PIC X(11) VALUE '  Name   : '.
           03 WS-CI-NAME              PIC X(121).

       01  WS-CI-ADDR1-LINE.
           03 FILLER                  PIC X(11) VALUE '  Address: '.
           03 WS-CI-ADDR1             PIC X(121).

       01  WS-CI-ADDR2-LINE.
           03 FILLER                  PIC X(11) VALUE '           '.
           03 WS-CI-ADDR2             PIC X(121).

       01  WS-CI-ADDRFINAL-LINE.
           03 FILLER                  PIC X(11) VALUE '           '.
           03 WS-CI-ADDRFINAL         PIC X(121).

       01  WS-CI-PHONE-LINE.
           03 FILLER                  PIC X(11) VALUE '  Phone  : '.
           03 WS-CI-PHONE             PIC X(20).
           03 FILLER                  PIC X(101) VALUE SPACES.

      *-----------------------------------------------------------------
      * Summary lines
      *-----------------------------------------------------------------
       01  WS-OPEN-BAL-LINE.
           03 FILLER                  PIC X(18)
               VALUE 'OPENING BALANCE:  '.
           03 WS-OB-AMOUNT            PIC X(17).
           03 FILLER                  PIC X(97)  VALUE SPACES.

       01  WS-TOTAL-WITH-LINE.
           03 FILLER                  PIC X(21)
               VALUE 'TOTAL WITHDRAWALS:   '.
           03 WS-TW-AMOUNT            PIC X(17).
           03 FILLER                  PIC X(94)  VALUE SPACES.

       01  WS-TOTAL-DEP-LINE.
           03 FILLER                  PIC X(21)
               VALUE 'TOTAL DEPOSITS   :   '.
           03 WS-TD-AMOUNT            PIC X(17).
           03 FILLER                  PIC X(94)  VALUE SPACES.

       01  WS-EOM-BAL-LINE.
           03 FILLER                  PIC X(21)
               VALUE 'END OF MONTH BALANCE:'.
           03 WS-EB-AMOUNT            PIC X(17).
           03 FILLER                  PIC X(94)  VALUE SPACES.

       01  WS-NO-TRAN-LINE            PIC X(132)
               VALUE '  NO TRANSACTIONS FOR THIS PERIOD'.

       01  WS-END-STMT-LINE           PIC X(132) VALUE
           '                                                   *** END O
      -    'F STATEMENT ***'.

      *-----------------------------------------------------------------
      * Temporary index / work fields
      *-----------------------------------------------------------------
       01  WS-PERIOD-YYYY-DISP        PIC X(4).
       01  WS-PERIOD-MM-DISP          PIC X(2).
       01  WS-DD-END-DISP             PIC X(2).
       01  WS-DD-END-EDIT             PIC 99.
      *    Amount right-alignment: start position within 17-char field
       01  WS-AMT-START               PIC S9(4) COMP VALUE 1.
       01  WS-AMT-LEN                 PIC S9(4) COMP VALUE 0.

      ******************************************************************
       PROCEDURE DIVISION.
      ******************************************************************

      *-----------------------------------------------------------------
       MAIN-CONTROL.
      *-----------------------------------------------------------------
      * 1. Validate SYSOUT availability first (spec §4.1).
      *    On z/OS, DISPLAY routes to SYSOUT DD automatically.
      *    Attempt a probe DISPLAY; if the DD is missing the system
      *    will abend, so we treat reaching this point as SYSOUT OK.
      *    RC=12 is set and the program stops if unavailable.
      *-----------------------------------------------------------------
           PERFORM 6100-OPEN-SYSPRINT THRU 6100-EXIT

           IF WS-RETURN-CODE = 12
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF

           MOVE FUNCTION CURRENT-DATE TO WS-CURRENT-DATE-21

      *    Build the statement issue date (YYYY-MM-DD)
           STRING WS-CURR-YYYY DELIMITED BY SIZE
                  '-'            DELIMITED BY SIZE
                  WS-CURR-MM    DELIMITED BY SIZE
                  '-'            DELIMITED BY SIZE
                  WS-CURR-DD    DELIMITED BY SIZE
                  INTO WS-ISSUE-DATE-DISP
           END-STRING

      *    Open SYSIN
           PERFORM 1000-OPEN-SYSIN THRU 1000-EXIT
           IF WS-RETURN-CODE >= 8
               PERFORM 6200-CLOSE-FILES THRU 6200-EXIT
               MOVE WS-RETURN-CODE TO RETURN-CODE
               STOP RUN
           END-IF

      *    Read and validate SYSIN control record
           PERFORM 1100-READ-SYSIN THRU 1100-EXIT
           IF WS-RETURN-CODE >= 4
               PERFORM 6200-CLOSE-FILES THRU 6200-EXIT
               MOVE WS-RETURN-CODE TO RETURN-CODE
               STOP RUN
           END-IF

      *    Validate SYSIN fields (collect-all errors per spec §2.2.3)
           PERFORM 1200-VALIDATE-SYSIN THRU 1200-EXIT
           IF WS-RETURN-CODE >= 8
               PERFORM 6200-CLOSE-FILES THRU 6200-EXIT
               MOVE WS-RETURN-CODE TO RETURN-CODE
               STOP RUN
           END-IF

      *    Normalise customer ID
           PERFORM 1300-NORMALISE-CUSTID THRU 1300-EXIT

      *    Calculate statement period date range
           PERFORM 1400-CALC-DATE-RANGE THRU 1400-EXIT

      *    Query accounts first (spec §3.1 ordering)
           PERFORM 2000-QUERY-ACCOUNTS THRU 2000-EXIT
           IF WS-RETURN-CODE >= 8
               PERFORM 6200-CLOSE-FILES THRU 6200-EXIT
               MOVE WS-RETURN-CODE TO RETURN-CODE
               STOP RUN
           END-IF

           IF WS-RETURN-CODE = 4
      *        No accounts - message already emitted; suppress SYSPRINT
               PERFORM 6200-CLOSE-FILES THRU 6200-EXIT
               MOVE WS-RETURN-CODE TO RETURN-CODE
               STOP RUN
           END-IF

      *    Query customer demographics for first account sort code
           MOVE HV-ACCT-SORTCODE TO HV-CUST-SORTCODE

      *    Open SYSPRINT (accounts exist - proceed with report)
           PERFORM 6110-OPEN-SYSPRINT-WRITE THRU 6110-EXIT
           IF WS-RETURN-CODE >= 8
               PERFORM 6200-CLOSE-FILES THRU 6200-EXIT
               MOVE WS-RETURN-CODE TO RETURN-CODE
               STOP RUN
           END-IF

      *    Re-open account cursor (closed in 2000 after peek)
           PERFORM 3000-PROCESS-ALL-ACCOUNTS THRU 3000-EXIT

           IF WS-RETURN-CODE < 8
               PERFORM 5000-WRITE-END-STMT THRU 5000-EXIT
           END-IF

           IF WS-RETURN-CODE = 0
               DISPLAY 'BNKZI0000: Monthly statement generation '
                       'completed successfully for customer '
                       WS-CUST-ID-CANONICAL
           END-IF

           PERFORM 6200-CLOSE-FILES THRU 6200-EXIT
           MOVE WS-RETURN-CODE TO RETURN-CODE
           STOP RUN.

      ******************************************************************
      * 1000 - SYSIN OPEN / READ / VALIDATE
      ******************************************************************

      *-----------------------------------------------------------------
       1000-OPEN-SYSIN.
      *-----------------------------------------------------------------
           OPEN INPUT SYSIN-FILE
           IF WS-SYSIN-STATUS NOT = '00'
               DISPLAY 'BNKZE0021: Error reading SYSIN control '
                       'dataset. File status=' WS-SYSIN-STATUS
               PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
           ELSE
               MOVE 'Y' TO WS-SYSIN-OPEN
           END-IF.
       1000-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       1100-READ-SYSIN.
      *-----------------------------------------------------------------
      *    Read all records from SYSIN; count non-empty ones.
      *    Save the FIRST non-empty record for validation.
      *    Spec §2.2.3: check 1 (empty) and check 2 (multiple) first.
      *-----------------------------------------------------------------
           PERFORM UNTIL WS-SYSIN-EOF = 'Y'
               READ SYSIN-FILE INTO WS-SYSIN-RECORD
                   AT END
                       MOVE 'Y' TO WS-SYSIN-EOF
                   NOT AT END
                       IF WS-SYSIN-RECORD NOT = SPACES
                           ADD 1 TO WS-SYSIN-RECORD-COUNT
                           IF WS-SYSIN-RECORD-COUNT = 1
                               MOVE WS-SYSIN-RECORD
                                 TO WS-SYSIN-SAVED-RECORD
                           END-IF
                       END-IF
                       IF WS-SYSIN-STATUS NOT = '00'
                           AND WS-SYSIN-STATUS NOT = '10'
                           DISPLAY 'BNKZE0021: Error reading SYSIN '
                                   'control dataset. File status='
                                   WS-SYSIN-STATUS
                           PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
                           MOVE 'Y' TO WS-SYSIN-EOF
                           GO TO 1100-EXIT
                       END-IF
               END-READ
           END-PERFORM

      *    Restore the single valid control record saved on first read.
           IF WS-SYSIN-RECORD-COUNT = 1
               MOVE WS-SYSIN-SAVED-RECORD TO WS-SYSIN-RECORD
           END-IF

      *    Check 1 - no records
           IF WS-SYSIN-RECORD-COUNT = 0
               DISPLAY 'BNKZI0005: SYSIN not specified or '
                       'insufficient parameters; displaying '
                       'usage syntax'
               PERFORM 1110-PRINT-USAGE THRU 1110-EXIT
               PERFORM 9200-RAISE-INFO THRU 9200-EXIT
           END-IF

      *    Check 2 - multiple records
           IF WS-SYSIN-RECORD-COUNT > 1
               DISPLAY 'BNKZE0022: Multiple SYSIN control records '
                       'detected; only single-record input is '
                       'supported'
               PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
           END-IF.
       1100-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       1110-PRINT-USAGE.
      *-----------------------------------------------------------------
           DISPLAY 'USAGE:'
           DISPLAY '  //SYSIN DD *'
           DISPLAY '  <CustomerID> <YYYY-MM>'
           DISPLAY '  /*'
           DISPLAY 'SYNTAX:'
           DISPLAY '  - Customer ID : C<digits> (CICS, 1-9 digits)'
                   ' or I<digits> (IMS, 9 digits)'
           DISPLAY '  - Period      : YYYY-MM (e.g. 2026-07)'
           DISPLAY 'EXAMPLE INPUT:'
           DISPLAY '  C000000001 2026-07'
           DISPLAY 'SAMPLE OUTPUT (SYSPRINT) - 132-column layout:'
           DISPLAY '======================================'
                   '======================================'
                   '==============================='
           DISPLAY 'BANK OF Z                        '
                   '        MONTHLY CUSTOMER STATEMENT'
                   '                    PAGE:      1'
           DISPLAY '======================================'
                   '======================================'
                   '==============================='
           DISPLAY 'STATEMENT PERIOD: 2026-07-01 TO 2026-07-31'
                   '                               STATEMENT '
                   'ISSUE DATE: 2026-07-31'
           DISPLAY 'CUSTOMER ID     : C000000001'.
       1110-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       1200-VALIDATE-SYSIN.
      *-----------------------------------------------------------------
      *    Checks 3-9: collect-all-errors approach.
      *    We need to re-read the first non-empty record from SYSIN.
      *    Since we already have it in WS-SYSIN-RECORD from the last
      *    non-empty read in 1100, we use it directly.
      *-----------------------------------------------------------------
           MOVE 0 TO WS-SYSIN-ERROR-COUNT

      *    Check 3 - prefix must be C or I
           MOVE WS-RAW-CUSTID(1:1) TO WS-CUST-PREFIX
           IF WS-CUST-PREFIX NOT = 'C' AND
              WS-CUST-PREFIX NOT = 'I'
               DISPLAY 'BNKZE0002: Customer ID prefix must be '
                       '''C'' (CICS) or ''I'' (IMS)'
               PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
               ADD 1 TO WS-SYSIN-ERROR-COUNT
           END-IF

      *    Check 4 - digits must be numeric (cols 2-10 of raw ID)
      *    WS-RAW-CUSTID is PIC X(10); col 1 is prefix.
      *    We copy cols 2-10 (9 bytes) into the first 9 chars of
      *    WS-CUST-RAW-DIGITS (PIC X(10)) to leave room for an
      *    overrun sentinel — the 10th byte stays SPACE.
           MOVE SPACES TO WS-CUST-RAW-DIGITS
           MOVE WS-RAW-CUSTID(2:9) TO WS-CUST-RAW-DIGITS(1:9)
      *    Find actual digit string (strip trailing spaces)
           MOVE 9 TO WS-DIGIT-LEN
           PERFORM VARYING WS-DIGIT-IDX FROM 9 BY -1
               UNTIL WS-DIGIT-IDX = 0
               IF WS-CUST-RAW-DIGITS(WS-DIGIT-IDX:1) = SPACE
                   SUBTRACT 1 FROM WS-DIGIT-LEN
               ELSE
                   MOVE 0 TO WS-DIGIT-IDX
               END-IF
           END-PERFORM
           IF WS-DIGIT-LEN = 0
               MOVE 1 TO WS-DIGIT-LEN
           END-IF
           MOVE WS-CUST-RAW-DIGITS(1:WS-DIGIT-LEN) TO WS-DIGIT-WORK
           IF WS-DIGIT-WORK(1:WS-DIGIT-LEN) IS NOT NUMERIC
               DISPLAY 'BNKZE0003: Non-numeric customer ID digits '
                       'found: '
                       WS-DIGIT-WORK(1:WS-DIGIT-LEN)
               PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
               ADD 1 TO WS-SYSIN-ERROR-COUNT
           END-IF

      *    Check 5 - IMS ID must not exceed 9 digits after prefix.
      *    Because WS-RAW-CUSTID is 10 chars (col 1 = prefix, cols 2-10
      *    = up to 9 digits) there is no physical room in SYSIN
      *    cols 1-10 for more than 9 post-prefix digits. The spec says
      *    the error fires when MORE THAN 9 digits are supplied; since
      *    the input field is exactly 9 digits wide, the check fires
      *    only when all 9 positions are non-space digits AND the field
      *    is genuinely full (i.e. user supplied exactly 9 digits —
      *    which is valid) OR overflows into SYSIN col 11. Per spec
      *    §2.1 col 11 is the space delimiter; if col 11 is not space
      *    AND prefix is 'I', the ID is overlong. We detect this here.
           IF WS-CUST-PREFIX = 'I'
              AND WS-SYSIN-SPACE NOT = SPACE
              AND WS-DIGIT-LEN >= 9
               DISPLAY 'BNKZE0004: IMS customer ID must not exceed '
                       '9 digits after prefix ''I'''
               PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
               ADD 1 TO WS-SYSIN-ERROR-COUNT
           END-IF

      *    Check 6 - period format (if non-blank)
      *    Spec §2.3: col 11 must be space AND col 16 must be '-'
           IF WS-PERIOD-RAW NOT = SPACES
               IF WS-SYSIN-SPACE NOT = SPACE
               OR WS-PERIOD-DASH NOT = '-'
               OR WS-PERIOD-YYYY IS NOT NUMERIC
               OR WS-PERIOD-MM   IS NOT NUMERIC
                   DISPLAY 'BNKZE0005: Invalid statement period '
                           'format. Expected YYYY-MM'
                   PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
                   ADD 1 TO WS-SYSIN-ERROR-COUNT
               ELSE
      *            Check 7 - month value
                   MOVE WS-PERIOD-MM TO WS-PERIOD-MM-DISP
                   IF WS-PERIOD-MM < '01' OR WS-PERIOD-MM > '12'
                       DISPLAY 'BNKZE0006: Invalid month value MM in '
                               'statement period: '
                               WS-PERIOD-MM-DISP
                       PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
                       ADD 1 TO WS-SYSIN-ERROR-COUNT
                   END-IF
      *            Check 8 - year range
                   MOVE WS-PERIOD-YYYY TO WS-PERIOD-YYYY-DISP
                   IF WS-PERIOD-YYYY < '1900'
                   OR WS-PERIOD-YYYY > '2099'
                       DISPLAY 'BNKZE0007: Statement year YYYY is '
                               'outside valid range (1900-2099): '
                               WS-PERIOD-YYYY-DISP
                       PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
                       ADD 1 TO WS-SYSIN-ERROR-COUNT
                   END-IF
      *            Check 9 - future period (only if check 6 passed,
      *            which is guaranteed here since we are in the ELSE
      *            branch of the format check; checks 7/8 do not
      *            suppress check 9 per spec §2.2.3)
                   IF WS-PERIOD-YYYY > WS-CURR-YYYY
                       OR (WS-PERIOD-YYYY = WS-CURR-YYYY AND
                           WS-PERIOD-MM   > WS-CURR-MM)
                           MOVE WS-PERIOD-YYYY TO WS-PERIOD-YYYY-DISP
                           MOVE WS-PERIOD-MM   TO WS-PERIOD-MM-DISP
                           STRING WS-PERIOD-YYYY-DISP
                                  DELIMITED BY SIZE
                                  '-' DELIMITED BY SIZE
                                  WS-PERIOD-MM-DISP
                                  DELIMITED BY SIZE
                                  INTO WS-MSG
                           END-STRING
                           DISPLAY 'BNKZE0008: Statement period is '
                                   'in the future: '
                                   WS-MSG(1:7)
                           PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
                           ADD 1 TO WS-SYSIN-ERROR-COUNT
                       END-IF
               END-IF
           ELSE
      *        Period omitted - default to current month
               MOVE WS-CURR-YYYY TO WS-PERIOD-YYYY
               MOVE WS-CURR-MM   TO WS-PERIOD-MM
               STRING WS-CURR-YYYY DELIMITED BY SIZE
                      '-'          DELIMITED BY SIZE
                      WS-CURR-MM   DELIMITED BY SIZE
                      INTO WS-MSG
               END-STRING
               DISPLAY 'BNKZI0001: Statement period omitted; '
                       'defaulting to current month: '
                       WS-MSG(1:7)
               PERFORM 9200-RAISE-INFO THRU 9200-EXIT
           END-IF.
       1200-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       1300-NORMALISE-CUSTID.
      *-----------------------------------------------------------------
      *    Strip prefix; zero-pad digits to 9; re-prefix -> canonical.
      *    Produce numeric-only 10-char value for Db2 WHERE predicate.
      *-----------------------------------------------------------------
           MOVE SPACES TO WS-DIGIT-WORK
           MOVE WS-CUST-RAW-DIGITS(1:WS-DIGIT-LEN) TO
               WS-DIGIT-WORK(1:WS-DIGIT-LEN)
      *    Convert digit string to numeric, then to 9-digit picture
           MOVE FUNCTION NUMVAL(WS-DIGIT-WORK(1:WS-DIGIT-LEN))
               TO WS-DIGIT-NUMERIC
           MOVE WS-DIGIT-NUMERIC TO WS-DIGIT-EDIT
      *    Build canonical ID: prefix + 9-digit zero-padded string
           STRING WS-CUST-PREFIX DELIMITED BY SIZE
                  WS-DIGIT-EDIT   DELIMITED BY SIZE
                  INTO WS-CUST-ID-CANONICAL
           END-STRING
      *    Numeric-only for Db2 (prefix stripped, zero-padded 10 chars)
           STRING '0' DELIMITED BY SIZE
                  WS-DIGIT-EDIT DELIMITED BY SIZE
                  INTO WS-CUST-NUMBER-STRIPPED
           END-STRING
           MOVE WS-CUST-NUMBER-STRIPPED TO HV-CUST-NUMBER.
       1300-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       1400-CALC-DATE-RANGE.
      *-----------------------------------------------------------------
      *    Derive PERIOD-FROM (YYYY-MM-01) and PERIOD-TO (YYYY-MM-LL)
      *    where LL = last day of month, accounting for leap years.
      *-----------------------------------------------------------------
           MOVE FUNCTION NUMVAL(WS-PERIOD-YYYY) TO WS-PERIOD-YYYY-NUM
           MOVE FUNCTION NUMVAL(WS-PERIOD-MM)   TO WS-PERIOD-MM-NUM

      *    Default last day = 31
           MOVE 31 TO WS-PERIOD-DD-END

           EVALUATE WS-PERIOD-MM-NUM
               WHEN 4  WHEN 6  WHEN 9  WHEN 11
                   MOVE 30 TO WS-PERIOD-DD-END
               WHEN 2
      *            Leap year check: (Y%4=0 AND Y%100<>0) OR Y%400=0
                   MOVE 'N' TO WS-LEAP-YEAR-FLAG
                   DIVIDE WS-PERIOD-YYYY-NUM BY 400
                       GIVING WS-LEAP-WORK
                       REMAINDER WS-LEAP-REMAINDER
                   IF WS-LEAP-REMAINDER = 0
                       MOVE 'Y' TO WS-LEAP-YEAR-FLAG
                   ELSE
                       DIVIDE WS-PERIOD-YYYY-NUM BY 100
                           GIVING WS-LEAP-WORK
                           REMAINDER WS-LEAP-REMAINDER
                       IF WS-LEAP-REMAINDER = 0
                           MOVE 'N' TO WS-LEAP-YEAR-FLAG
                       ELSE
                           DIVIDE WS-PERIOD-YYYY-NUM BY 4
                               GIVING WS-LEAP-WORK
                               REMAINDER WS-LEAP-REMAINDER
                           IF WS-LEAP-REMAINDER = 0
                               MOVE 'Y' TO WS-LEAP-YEAR-FLAG
                           END-IF
                       END-IF
                   END-IF
                   IF WS-LEAP-YEAR-FLAG = 'Y'
                       MOVE 29 TO WS-PERIOD-DD-END
                   ELSE
                       MOVE 28 TO WS-PERIOD-DD-END
                   END-IF
           END-EVALUATE

      *    Format WS-DD-END-DISP as 2-digit zero-padded
           MOVE WS-PERIOD-DD-END TO WS-DD-END-EDIT
           MOVE WS-DD-END-EDIT TO WS-DD-END-DISP

      *    Build ISO date strings for Db2 host variables
           STRING WS-PERIOD-YYYY DELIMITED BY SIZE
                  '-'             DELIMITED BY SIZE
                  WS-PERIOD-MM   DELIMITED BY SIZE
                  '-01'           DELIMITED BY SIZE
                  INTO HV-PERIOD-FROM
           END-STRING

           STRING WS-PERIOD-YYYY  DELIMITED BY SIZE
                  '-'              DELIMITED BY SIZE
                  WS-PERIOD-MM    DELIMITED BY SIZE
                  '-'              DELIMITED BY SIZE
                  WS-DD-END-DISP  DELIMITED BY SIZE
                  INTO HV-PERIOD-TO
           END-STRING

           MOVE HV-PERIOD-FROM TO WS-PERIOD-FROM-DISP
           MOVE HV-PERIOD-TO   TO WS-PERIOD-TO-DISP.
       1400-EXIT.
           EXIT.

      ******************************************************************
      * 2000 - ACCOUNT QUERY (first pass to check existence)
      ******************************************************************

      *-----------------------------------------------------------------
       2000-QUERY-ACCOUNTS.
      *-----------------------------------------------------------------
      *    Open the cursor, fetch first row to check existence.
      *    If no rows -> BNKZI0002, RC=4.
      *    Leaves cursor open and first row in host vars for 3000.
      *-----------------------------------------------------------------
           EXEC SQL
               OPEN ACCT-CURSOR
           END-EXEC
           MOVE 'Y' TO WS-ACCT-CURSOR-OPEN

           IF SQLCODE < 0
               MOVE SQLCODE TO SQLCODE-DISPLAY
               DISPLAY 'BNKZE0012: Db2 error opening/fetching '
                       'ACCOUNT cursor. SQLCODE=' SQLCODE-DISPLAY
               PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
               GO TO 2000-EXIT
           END-IF

      *    Fetch one row to see if any accounts exist
           EXEC SQL
               FETCH ACCT-CURSOR
               INTO :HV-ACCT-NUMBER,
                    :HV-ACCT-SORTCODE,
                    :HV-ACCT-TYPE,
                    :HV-ACCT-ACTUAL-BAL
           END-EXEC

           IF SQLCODE = 100
      *        No accounts found
               DISPLAY 'BNKZI0002: Customer '
                       WS-CUST-ID-CANONICAL
                       ' has no active accounts on file'
               PERFORM 9200-RAISE-INFO THRU 9200-EXIT
               EXEC SQL CLOSE ACCT-CURSOR END-EXEC
               MOVE 'N' TO WS-ACCT-CURSOR-OPEN
               GO TO 2000-EXIT
           END-IF

           IF SQLCODE < 0
               MOVE SQLCODE TO SQLCODE-DISPLAY
               DISPLAY 'BNKZE0012: Db2 error opening/fetching '
                       'ACCOUNT cursor. SQLCODE=' SQLCODE-DISPLAY
               PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
               EXEC SQL CLOSE ACCT-CURSOR END-EXEC
               MOVE 'N' TO WS-ACCT-CURSOR-OPEN
           END-IF.
       2000-EXIT.
           EXIT.

      ******************************************************************
      * 3000 - PROCESS ALL ACCOUNTS
      ******************************************************************

      *-----------------------------------------------------------------
       3000-PROCESS-ALL-ACCOUNTS.
      *-----------------------------------------------------------------
      *    At entry the cursor is open and the first row is already
      *    sitting in host vars from 2000-QUERY-ACCOUNTS.
      *    Per spec §3.1, customer demographics are queried individually
      *    per account using each account's ACCOUNT_SORTCODE so that
      *    multi-institution account holdings are supported.
      *    Customer info block is printed only on page 1 (spec §4.3).
      *-----------------------------------------------------------------
      *    Query customer demographics using first account sort code
      *    (HV-CUST-SORTCODE already set from HV-ACCT-SORTCODE in
      *    MAIN-CONTROL after 2000-QUERY-ACCOUNTS confirmed accounts
      *    exist)
           PERFORM 3100-QUERY-CUSTOMER THRU 3100-EXIT
           IF WS-RETURN-CODE >= 8
               GO TO 3000-EXIT
           END-IF

      *    Write page 1 header (banner + period + customer info)
      *    Customer info block comes from the just-queried demographics
           PERFORM 4000-WRITE-PAGE1-HEADER THRU 4000-EXIT

      *    Process first and subsequent account rows
           PERFORM UNTIL WS-ACCT-EOF = 'Y'
               ADD 1 TO WS-ACCT-SEQ

      *        For account 2+: update sort code and re-query
      *        demographics so multi-branch accounts use correct record
               IF WS-ACCT-SEQ > 1
                   MOVE HV-ACCT-SORTCODE TO HV-CUST-SORTCODE
                   PERFORM 3100-QUERY-CUSTOMER THRU 3100-EXIT
                   IF WS-RETURN-CODE >= 8
                       GO TO 3000-EXIT
                   END-IF
               END-IF

      *        Eject to new page for account 2+; 4100 will call
      *        4200-WRITE-ACCT-HEADER internally after the page break
               IF WS-ACCT-SEQ > 1
                   PERFORM 4100-PAGE-EJECT THRU 4100-EXIT
               ELSE
      *            First account on page 1: write account header here
                   PERFORM 4200-WRITE-ACCT-HEADER THRU 4200-EXIT
               END-IF

               PERFORM 4300-PROCESS-TRANSACTIONS THRU 4300-EXIT

               IF WS-RETURN-CODE >= 8
                   GO TO 3000-EXIT
               END-IF

      *        Fetch next account
               EXEC SQL
                   FETCH ACCT-CURSOR
                   INTO :HV-ACCT-NUMBER,
                        :HV-ACCT-SORTCODE,
                        :HV-ACCT-TYPE,
                        :HV-ACCT-ACTUAL-BAL
               END-EXEC

               IF SQLCODE = 100
                   MOVE 'Y' TO WS-ACCT-EOF
               ELSE
                   IF SQLCODE < 0
                       MOVE SQLCODE TO SQLCODE-DISPLAY
                       DISPLAY 'BNKZE0012: Db2 error opening/'
                               'fetching ACCOUNT cursor. SQLCODE='
                               SQLCODE-DISPLAY
                       PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
                       MOVE 'Y' TO WS-ACCT-EOF
                   END-IF
               END-IF
           END-PERFORM

           EXEC SQL CLOSE ACCT-CURSOR END-EXEC
           MOVE 'N' TO WS-ACCT-CURSOR-OPEN.
       3000-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       3100-QUERY-CUSTOMER.
      *-----------------------------------------------------------------
           EXEC SQL
               SELECT CUSTOMER_TITLE,
                      CUSTOMER_FIRST_NAME,
                      CUSTOMER_LAST_NAME,
                      CUSTOMER_ADDR_LINE1,
                      CUSTOMER_ADDR_LINE2,
                      CUSTOMER_CITY,
                      CUSTOMER_POSTCODE,
                      CUSTOMER_COUNTRY,
                      CUSTOMER_PHONE
               INTO  :HV-CUST-TITLE    :NI-CUST-TITLE,
                     :HV-CUST-FIRST-NAME :NI-CUST-FNAME,
                     :HV-CUST-LAST-NAME  :NI-CUST-LNAME,
                     :HV-CUST-ADDR1    :NI-CUST-ADDR1,
                     :HV-CUST-ADDR2    :NI-CUST-ADDR2,
                     :HV-CUST-CITY     :NI-CUST-CITY,
                     :HV-CUST-POSTCODE :NI-CUST-POSTCODE,
                     :HV-CUST-COUNTRY  :NI-CUST-COUNTRY,
                     :HV-CUST-PHONE    :NI-CUST-PHONE
               FROM   BANKZ.CUSTOMER
               WHERE  CUSTOMER_SORTCODE = :HV-CUST-SORTCODE
                 AND  CUSTOMER_NUMBER   = :HV-CUST-NUMBER
           END-EXEC

           IF SQLCODE = 100
               DISPLAY 'BNKZE0010: Customer not found in database: '
                       WS-CUST-ID-CANONICAL
               PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
               GO TO 3100-EXIT
           END-IF

           IF SQLCODE < 0
               MOVE SQLCODE TO SQLCODE-DISPLAY
               DISPLAY 'BNKZE0011: Db2 error querying CUSTOMER '
                       'table. SQLCODE=' SQLCODE-DISPLAY
               PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
               GO TO 3100-EXIT
           END-IF

      *    Apply N/A to null or blank customer fields
           IF NI-CUST-TITLE < 0 OR HV-CUST-TITLE = SPACES
               MOVE 'N/A' TO HV-CUST-TITLE
           END-IF
           IF NI-CUST-FNAME < 0 OR HV-CUST-FIRST-NAME = SPACES
               MOVE 'N/A' TO HV-CUST-FIRST-NAME
           END-IF
           IF NI-CUST-LNAME < 0 OR HV-CUST-LAST-NAME = SPACES
               MOVE 'N/A' TO HV-CUST-LAST-NAME
           END-IF
           IF NI-CUST-ADDR1 < 0 OR HV-CUST-ADDR1 = SPACES
               MOVE 'N/A' TO HV-CUST-ADDR1
           END-IF
           IF NI-CUST-ADDR2 < 0 OR HV-CUST-ADDR2 = SPACES
               MOVE SPACES TO HV-CUST-ADDR2
           END-IF
           IF NI-CUST-CITY < 0 OR HV-CUST-CITY = SPACES
               MOVE 'N/A' TO HV-CUST-CITY
           END-IF
           IF NI-CUST-POSTCODE < 0 OR HV-CUST-POSTCODE = SPACES
               MOVE 'N/A' TO HV-CUST-POSTCODE
           END-IF
           IF NI-CUST-COUNTRY < 0 OR HV-CUST-COUNTRY = SPACES
               MOVE 'N/A' TO HV-CUST-COUNTRY
           END-IF
           IF NI-CUST-PHONE < 0 OR HV-CUST-PHONE = SPACES
               MOVE 'N/A' TO HV-CUST-PHONE
           END-IF.
       3100-EXIT.
           EXIT.

      ******************************************************************
      * 4000 - PAGE HEADER / ACCOUNT HEADER WRITING
      ******************************************************************

      *-----------------------------------------------------------------
       4000-WRITE-PAGE1-HEADER.
      *-----------------------------------------------------------------
      *    Writes the full page 1 header: banner, period line,
      *    customer ID line, blank line, customer info block, blank.
      *    Customer info is only on page 1 (spec §4.3).
      *-----------------------------------------------------------------
           MOVE 0 TO WS-LINE-COUNT
           PERFORM 4010-WRITE-BANNER THRU 4010-EXIT

      *    Statement period and issue date line
           MOVE WS-PERIOD-FROM-DISP TO WS-SP-FROM
           MOVE WS-PERIOD-TO-DISP   TO WS-SP-TO
           MOVE WS-ISSUE-DATE-DISP  TO WS-SP-ISSUE
           MOVE ' ' TO WS-PL-CC
           MOVE WS-STMT-PERIOD-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Customer ID line
           MOVE WS-CUST-ID-CANONICAL TO WS-CL-CUSTID
           MOVE ' ' TO WS-PL-CC
           MOVE WS-CUSTID-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Blank line
           MOVE '0' TO WS-PL-CC
           MOVE SPACES TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Customer information header
           MOVE ' ' TO WS-PL-CC
           MOVE WS-CUSTINFO-HDR TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Name line: TITLE FIRSTNAME LASTNAME
           MOVE SPACES TO WS-CUST-NAME-DISP
           STRING FUNCTION TRIM(HV-CUST-TITLE)
                      DELIMITED BY SIZE
                  ' '   DELIMITED BY SIZE
                  FUNCTION TRIM(HV-CUST-FIRST-NAME)
                      DELIMITED BY SIZE
                  ' '   DELIMITED BY SIZE
                  FUNCTION TRIM(HV-CUST-LAST-NAME)
                      DELIMITED BY SIZE
                  INTO WS-CUST-NAME-DISP
           END-STRING
           MOVE WS-CUST-NAME-DISP TO WS-CI-NAME
           MOVE ' ' TO WS-PL-CC
           MOVE WS-CI-NAME-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Address line 1
           MOVE HV-CUST-ADDR1 TO WS-CI-ADDR1
           MOVE ' ' TO WS-PL-CC
           MOVE WS-CI-ADDR1-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Address line 2 (only if non-blank AND addr1 was not N/A)
      *    Spec §3.3: when addr1 is null/blank (printed as N/A), addr2
      *    is omitted entirely regardless of its own value.
           IF HV-CUST-ADDR2 NOT = SPACES
           AND HV-CUST-ADDR1 NOT = 'N/A'
               MOVE HV-CUST-ADDR2 TO WS-CI-ADDR2
               MOVE ' ' TO WS-PL-CC
               MOVE WS-CI-ADDR2-LINE TO WS-PL-DATA
               PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT
           END-IF

      *    Address final line: City, Postcode, Country
           MOVE SPACES TO WS-CI-ADDRFINAL
           STRING FUNCTION TRIM(HV-CUST-CITY)
                      DELIMITED BY SIZE
                  ', '
                      DELIMITED BY SIZE
                  FUNCTION TRIM(HV-CUST-POSTCODE)
                      DELIMITED BY SIZE
                  ', '
                      DELIMITED BY SIZE
                  FUNCTION TRIM(HV-CUST-COUNTRY)
                      DELIMITED BY SIZE
                  INTO WS-CI-ADDRFINAL
           END-STRING
           MOVE ' ' TO WS-PL-CC
           MOVE WS-CI-ADDRFINAL-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Phone line
           MOVE HV-CUST-PHONE TO WS-CI-PHONE
           MOVE ' ' TO WS-PL-CC
           MOVE WS-CI-PHONE-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Blank line after customer info
           MOVE '0' TO WS-PL-CC
           MOVE SPACES TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT.
       4000-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       4010-WRITE-BANNER.
      *-----------------------------------------------------------------
           MOVE '1' TO WS-PL-CC

      *    Banner line 1 (=== line)
           MOVE WS-BANNER-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Page header line: BANK OF Z ... PAGE: n
           MOVE WS-PAGE-NUMBER TO WS-PAGE-EDIT
           MOVE WS-PAGE-EDIT   TO WS-PH-PAGE-NO
           MOVE ' ' TO WS-PL-CC
           MOVE WS-PAGE-HDR-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Banner line 2 (=== line)
           MOVE ' ' TO WS-PL-CC
           MOVE WS-BANNER-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT.
       4010-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       4100-PAGE-EJECT.
      *-----------------------------------------------------------------
      *    Issue page eject and reprint full abbreviated header per
      *    spec §4.3: banner, period/issue, customer ID, account header
      *    block (type/number/sort code, separator, opening balance,
      *    column headings and separator).
      *    Does NOT reprint customer info block (page 1 only).
      *-----------------------------------------------------------------
           ADD 1 TO WS-PAGE-NUMBER
           MOVE 0 TO WS-LINE-COUNT
           PERFORM 4010-WRITE-BANNER THRU 4010-EXIT

           MOVE WS-PERIOD-FROM-DISP TO WS-SP-FROM
           MOVE WS-PERIOD-TO-DISP   TO WS-SP-TO
           MOVE WS-ISSUE-DATE-DISP  TO WS-SP-ISSUE
           MOVE ' ' TO WS-PL-CC
           MOVE WS-STMT-PERIOD-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

           MOVE WS-CUST-ID-CANONICAL TO WS-CL-CUSTID
           MOVE ' ' TO WS-PL-CC
           MOVE WS-CUSTID-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Reprint account header block (items 3-5 of spec §4.3 list)
           PERFORM 4200-WRITE-ACCT-HEADER THRU 4200-EXIT.
       4100-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       4200-WRITE-ACCT-HEADER.
      *-----------------------------------------------------------------
      *    Write account separator, account type/number/sort code,
      *    separator, opening balance, column headings.
      *-----------------------------------------------------------------
      *    Format sort code display
           MOVE HV-ACCT-SORTCODE TO WS-SORTCODE-RAW
           PERFORM 8300-FORMAT-SORTCODE THRU 8300-EXIT

      *    Account separator
           MOVE ' ' TO WS-PL-CC
           MOVE WS-ACCT-SEP-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Account header line
           MOVE HV-ACCT-TYPE   TO WS-AH-TYPE
           MOVE HV-ACCT-NUMBER TO WS-AH-NUMBER
           MOVE WS-SORTCODE-DISP TO WS-AH-SORTCODE(1:8)
           MOVE ' ' TO WS-PL-CC
           MOVE WS-ACCT-HDR-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Account separator
           MOVE ' ' TO WS-PL-CC
           MOVE WS-ACCT-SEP-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Opening balance: always $0.00
           MOVE 0 TO WS-AMT-WORK-POS
           PERFORM 8100-FORMAT-AMOUNT THRU 8100-EXIT
           MOVE WS-AMT-FORMATTED TO WS-OB-AMOUNT
           MOVE ' ' TO WS-PL-CC
           MOVE WS-OPEN-BAL-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Blank line
           MOVE '0' TO WS-PL-CC
           MOVE SPACES TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Column headings
           MOVE ' ' TO WS-PL-CC
           MOVE WS-COL-HDR-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Column separator line
           MOVE ' ' TO WS-PL-CC
           MOVE WS-COL-SEP-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT.
       4200-EXIT.
           EXIT.

      ******************************************************************
      * 4300 - PROCESS TRANSACTIONS FOR CURRENT ACCOUNT
      ******************************************************************

      *-----------------------------------------------------------------
       4300-PROCESS-TRANSACTIONS.
      *-----------------------------------------------------------------
           MOVE 0           TO WS-TOTAL-WITHDRAWALS
           MOVE 0           TO WS-TOTAL-DEPOSITS
           MOVE 0           TO WS-RUNNING-BALANCE
           MOVE 0           TO WS-TRAN-COUNT

           EXEC SQL
               OPEN TRAN-CURSOR
           END-EXEC
           MOVE 'Y' TO WS-TRAN-CURSOR-OPEN

           IF SQLCODE < 0
               MOVE SQLCODE TO SQLCODE-DISPLAY
               DISPLAY 'BNKZE0013: Db2 error opening/fetching '
                       'PROCTRAN cursor. SQLCODE=' SQLCODE-DISPLAY
               PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
               GO TO 4300-EXIT
           END-IF

           MOVE 'N' TO WS-TRAN-EOF

           PERFORM UNTIL WS-TRAN-EOF = 'Y'
               EXEC SQL
                   FETCH TRAN-CURSOR
                   INTO :HV-TRAN-DATE,
                        :HV-TRAN-TIME,
                        :HV-TRAN-TYPE   :NI-TRAN-TYPE,
                        :HV-TRAN-DESC   :NI-TRAN-DESC,
                        :HV-TRAN-AMOUNT :NI-TRAN-AMOUNT
               END-EXEC

               IF SQLCODE = 100
                   MOVE 'Y' TO WS-TRAN-EOF
               ELSE
                   IF SQLCODE < 0
                       MOVE SQLCODE TO SQLCODE-DISPLAY
                       DISPLAY 'BNKZE0013: Db2 error opening/'
                               'fetching PROCTRAN cursor. '
                               'SQLCODE=' SQLCODE-DISPLAY
                       PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
                       MOVE 'Y' TO WS-TRAN-EOF
                   ELSE
      *                Valid row - apply null defaults
                       IF NI-TRAN-DESC < 0
                       OR HV-TRAN-DESC = SPACES
                           MOVE 'N/A' TO HV-TRAN-DESC
                       END-IF
                       IF NI-TRAN-AMOUNT < 0
                           MOVE 0 TO HV-TRAN-AMOUNT
                       END-IF

      *                Classify and write transaction line
                       PERFORM 4310-CLASSIFY-TRAN THRU 4310-EXIT
                       PERFORM 4320-FORMAT-TRAN-LINE THRU 4320-EXIT

      *                Check page break before writing
                       IF WS-LINE-COUNT >= WS-LINES-PER-PAGE
                           PERFORM 4100-PAGE-EJECT THRU 4100-EXIT
                       END-IF

                       MOVE ' ' TO WS-PL-CC
                       MOVE WS-TRAN-LINE TO WS-PL-DATA
                       PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

                       ADD 1 TO WS-TRAN-COUNT
                   END-IF
               END-IF
           END-PERFORM

           EXEC SQL CLOSE TRAN-CURSOR END-EXEC
           MOVE 'N' TO WS-TRAN-CURSOR-OPEN

      *    No transactions in period
           IF WS-TRAN-COUNT = 0
               MOVE ' ' TO WS-PL-CC
               MOVE WS-NO-TRAN-LINE TO WS-PL-DATA
               PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

               STRING 'BNKZI0003: No transactions found for '
                       'account ' DELIMITED BY SIZE
                      HV-ACCT-NUMBER DELIMITED BY SIZE
                      ' in period ' DELIMITED BY SIZE
                      WS-PERIOD-FROM-DISP DELIMITED BY SIZE
                      ' to '       DELIMITED BY SIZE
                      WS-PERIOD-TO-DISP   DELIMITED BY SIZE
                      INTO WS-MSG
               END-STRING
               DISPLAY WS-MSG
               PERFORM 9200-RAISE-INFO THRU 9200-EXIT
           END-IF

      *    Write account totals
           PERFORM 4400-WRITE-ACCT-TOTALS THRU 4400-EXIT.
       4300-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       4310-CLASSIFY-TRAN.
      *-----------------------------------------------------------------
      *    Sets WS-TRAN-CLASS (D/W/I) based on PROCTRAN_TYPE and
      *    PROCTRAN_AMOUNT sign per spec §3.6.
      *-----------------------------------------------------------------
           EVALUATE HV-TRAN-TYPE
               WHEN 'CRE' WHEN 'PCR' WHEN 'CHI'
                   MOVE 'D' TO WS-TRAN-CLASS
               WHEN 'DEB' WHEN 'PDR' WHEN 'CHO'
                   MOVE 'W' TO WS-TRAN-CLASS
               WHEN 'TFR'
                   IF HV-TRAN-AMOUNT > 0
                       MOVE 'D' TO WS-TRAN-CLASS
                   ELSE
                       IF HV-TRAN-AMOUNT < 0
                           MOVE 'W' TO WS-TRAN-CLASS
                       ELSE
                           MOVE 'I' TO WS-TRAN-CLASS
                       END-IF
                   END-IF
               WHEN 'CHA' WHEN 'CHF' WHEN 'ICA' WHEN 'ICC'
               WHEN 'IDA' WHEN 'IDC' WHEN 'OCA' WHEN 'OCC'
               WHEN 'ODA' WHEN 'ODC' WHEN 'OCS'
                   IF HV-TRAN-AMOUNT NOT = 0
      *                Informational with non-zero amount -> warning,
      *                treat as withdrawal
                       IF HV-TRAN-AMOUNT < 0
                           COMPUTE WS-AMT-WORK-POS =
                               HV-TRAN-AMOUNT * -1
                       ELSE
                           MOVE HV-TRAN-AMOUNT TO WS-AMT-WORK-POS
                       END-IF
                       PERFORM 8100-FORMAT-AMOUNT THRU 8100-EXIT
                       STRING 'BNKZI0007: Informational transaction '
                               'type ' DELIMITED BY SIZE
                              HV-TRAN-TYPE DELIMITED BY SIZE
                              ' has non-zero amount '
                                  DELIMITED BY SIZE
                              FUNCTION TRIM(WS-AMT-TEMP, LEADING)
                                  DELIMITED BY SIZE
                              ' for account '   DELIMITED BY SIZE
                              HV-ACCT-NUMBER    DELIMITED BY SIZE
                              '; treated as withdrawal'
                                  DELIMITED BY SIZE
                              INTO WS-MSG
                       END-STRING
                       DISPLAY WS-MSG
                       PERFORM 9200-RAISE-INFO THRU 9200-EXIT
                       MOVE 'W' TO WS-TRAN-CLASS
                   ELSE
                       MOVE 'I' TO WS-TRAN-CLASS
                   END-IF
               WHEN OTHER
      *            Unrecognised type -> warning, treat as withdrawal
                   STRING 'BNKZI0006: Unrecognised transaction type '
                           DELIMITED BY SIZE
                          HV-TRAN-TYPE DELIMITED BY SIZE
                          ' for account ' DELIMITED BY SIZE
                          HV-ACCT-NUMBER DELIMITED BY SIZE
                          '; treated as withdrawal'
                              DELIMITED BY SIZE
                          INTO WS-MSG
                   END-STRING
                   DISPLAY WS-MSG
                   PERFORM 9200-RAISE-INFO THRU 9200-EXIT
                   MOVE 'W' TO WS-TRAN-CLASS
           END-EVALUATE.
       4310-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       4320-FORMAT-TRAN-LINE.
      *-----------------------------------------------------------------
      *    Builds WS-TRAN-LINE from classification and host variables.
      *-----------------------------------------------------------------
           MOVE SPACES TO WS-TRAN-LINE

      *    Date: ISO YYYY-MM-DD -> Mmm DD, YYYY
           MOVE HV-TRAN-DATE TO WS-TRAN-DATE-WORK
           PERFORM 8200-FORMAT-DATE THRU 8200-EXIT
           MOVE WS-TRAN-DATE-DISP TO WS-TL-DATE

      *    Description
           MOVE HV-TRAN-DESC TO WS-TL-DESC

      *    Compute absolute amount
           IF HV-TRAN-AMOUNT < 0
               COMPUTE WS-ABS-AMOUNT = HV-TRAN-AMOUNT * -1
           ELSE
               MOVE HV-TRAN-AMOUNT TO WS-ABS-AMOUNT
           END-IF

           EVALUATE TRUE
               WHEN TRAN-IS-DEPOSIT
                   MOVE WS-ABS-AMOUNT TO WS-AMT-WORK-POS
                   PERFORM 8100-FORMAT-AMOUNT THRU 8100-EXIT
                   MOVE WS-AMT-FORMATTED-14 TO WS-TL-DEPOSIT
                   MOVE SPACES TO WS-TL-WITHDRAWAL
                   ADD WS-ABS-AMOUNT TO WS-TOTAL-DEPOSITS
                   ADD WS-ABS-AMOUNT TO WS-RUNNING-BALANCE

               WHEN TRAN-IS-WITHDRAWAL
                   MOVE WS-ABS-AMOUNT TO WS-AMT-WORK-POS
                   PERFORM 8100-FORMAT-AMOUNT THRU 8100-EXIT
                   MOVE WS-AMT-FORMATTED-14 TO WS-TL-WITHDRAWAL
                   MOVE SPACES TO WS-TL-DEPOSIT
                   ADD WS-ABS-AMOUNT TO WS-TOTAL-WITHDRAWALS
                   SUBTRACT WS-ABS-AMOUNT FROM WS-RUNNING-BALANCE

               WHEN TRAN-IS-INFO
                   MOVE SPACES TO WS-TL-WITHDRAWAL
                   MOVE SPACES TO WS-TL-DEPOSIT
           END-EVALUATE

      *    Running balance (signed, right-aligned 17 chars)
           MOVE WS-RUNNING-BALANCE TO WS-AMT-WORK-POS
           PERFORM 8100-FORMAT-AMOUNT THRU 8100-EXIT
           MOVE WS-AMT-FORMATTED TO WS-TL-RUN-BAL.
       4320-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       4400-WRITE-ACCT-TOTALS.
      *-----------------------------------------------------------------
           MOVE SPACES TO WS-TW-AMOUNT
           MOVE WS-TOTAL-WITHDRAWALS TO WS-AMT-WORK-POS
           PERFORM 8100-FORMAT-AMOUNT THRU 8100-EXIT
           MOVE WS-AMT-FORMATTED TO WS-TW-AMOUNT

           MOVE SPACES TO WS-TD-AMOUNT
           MOVE WS-TOTAL-DEPOSITS TO WS-AMT-WORK-POS
           PERFORM 8100-FORMAT-AMOUNT THRU 8100-EXIT
           MOVE WS-AMT-FORMATTED TO WS-TD-AMOUNT

           COMPUTE WS-AMT-WORK-POS =
               WS-TOTAL-DEPOSITS - WS-TOTAL-WITHDRAWALS
           PERFORM 8100-FORMAT-AMOUNT THRU 8100-EXIT
           MOVE WS-AMT-FORMATTED TO WS-EB-AMOUNT

      *    Blank line before totals
           MOVE '0' TO WS-PL-CC
           MOVE SPACES TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

           MOVE ' ' TO WS-PL-CC
           MOVE WS-TOTAL-WITH-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

           MOVE ' ' TO WS-PL-CC
           MOVE WS-TOTAL-DEP-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

           MOVE ' ' TO WS-PL-CC
           MOVE WS-EOM-BAL-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Account closing separator
           MOVE ' ' TO WS-PL-CC
           MOVE WS-ACCT-SEP-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

      *    Blank line after separator
           MOVE '0' TO WS-PL-CC
           MOVE SPACES TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT.
       4400-EXIT.
           EXIT.

      ******************************************************************
      * 5000 - END OF STATEMENT FOOTER
      ******************************************************************

      *-----------------------------------------------------------------
       5000-WRITE-END-STMT.
      *-----------------------------------------------------------------
      *    Footer is 3 lines (banner, END text, banner).
      *    Eject to new page if fewer than 3 lines remain.
      *    Per spec §4.3: when the footer spills to a fresh page the
      *    full standard header must be reprinted — banner, period/issue
      *    date, customer ID, AND the account header block (items 1-5
      *    of the §4.3 header-reprinting list).
      *-----------------------------------------------------------------
           IF WS-LINE-COUNT > WS-LINES-PER-PAGE - 3
               ADD 1 TO WS-PAGE-NUMBER
               MOVE 0 TO WS-LINE-COUNT
               PERFORM 4010-WRITE-BANNER THRU 4010-EXIT
               MOVE WS-PERIOD-FROM-DISP TO WS-SP-FROM
               MOVE WS-PERIOD-TO-DISP   TO WS-SP-TO
               MOVE WS-ISSUE-DATE-DISP  TO WS-SP-ISSUE
               MOVE ' ' TO WS-PL-CC
               MOVE WS-STMT-PERIOD-LINE TO WS-PL-DATA
               PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT
               MOVE WS-CUST-ID-CANONICAL TO WS-CL-CUSTID
               MOVE ' ' TO WS-PL-CC
               MOVE WS-CUSTID-LINE TO WS-PL-DATA
               PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT
      *        Reprint account header block (spec §4.3 items 3-5):
      *        separator, account type/number/sort code, separator,
      *        opening balance, column headings and separator.
               PERFORM 4200-WRITE-ACCT-HEADER THRU 4200-EXIT
           END-IF

           MOVE '0' TO WS-PL-CC
           MOVE WS-BANNER-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

           MOVE ' ' TO WS-PL-CC
           MOVE WS-END-STMT-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT

           MOVE ' ' TO WS-PL-CC
           MOVE WS-BANNER-LINE TO WS-PL-DATA
           PERFORM 8400-WRITE-SYSPRINT THRU 8400-EXIT.
       5000-EXIT.
           EXIT.

      ******************************************************************
      * 6000 - FILE OPEN / CLOSE
      ******************************************************************

      *-----------------------------------------------------------------
       6100-OPEN-SYSPRINT.
      *-----------------------------------------------------------------
      *    SYSOUT availability probe (spec §4.1).
      *    On z/OS, DISPLAY writes to the SYSOUT DD.  Issue a probe
      *    DISPLAY now; if SYSOUT DD is absent the run-time abend
      *    prevents us from reaching this point, which is the only
      *    mechanism available to detect the condition.  Successfully
      *    executing the DISPLAY confirms SYSOUT is reachable; RC=12
      *    is the contract for this failure but can only be raised by
      *    an external abend-handler or operator action — we set it
      *    defensively here so the guard in MAIN-CONTROL is active.
      *    SYSPRINT is opened for OUTPUT later in 6110 only after
      *    accounts are confirmed to exist (spec §3.1).
      *-----------------------------------------------------------------
           DISPLAY 'BNKSTMTC: program start'.
       6100-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       6110-OPEN-SYSPRINT-WRITE.
      *-----------------------------------------------------------------
      *    Open SYSPRINT for output. Only set the open-flag on success
      *    so that 6200-CLOSE-FILES does not attempt to close a file
      *    that was never successfully opened (spec §4.2).
      *-----------------------------------------------------------------
           OPEN OUTPUT SYSPRINT-FILE
           IF WS-SYSPRINT-STATUS NOT = '00'
               DISPLAY 'BNKZE0020: SYSPRINT dataset is unavailable '
                       'or unwritable. File status='
                       WS-SYSPRINT-STATUS
               PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
           ELSE
               MOVE 'Y' TO WS-SYSPRINT-OPEN
           END-IF.
       6110-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       6200-CLOSE-FILES.
      *-----------------------------------------------------------------
           IF WS-SYSIN-OPEN = 'Y'
               CLOSE SYSIN-FILE
               MOVE 'N' TO WS-SYSIN-OPEN
           END-IF
           IF WS-ACCT-CURSOR-OPEN = 'Y'
               EXEC SQL CLOSE ACCT-CURSOR END-EXEC
               MOVE 'N' TO WS-ACCT-CURSOR-OPEN
           END-IF
           IF WS-TRAN-CURSOR-OPEN = 'Y'
               EXEC SQL CLOSE TRAN-CURSOR END-EXEC
               MOVE 'N' TO WS-TRAN-CURSOR-OPEN
           END-IF
           IF WS-SYSPRINT-OPEN = 'Y'
               CLOSE SYSPRINT-FILE
               MOVE 'N' TO WS-SYSPRINT-OPEN
           END-IF.
       6200-EXIT.
           EXIT.

      ******************************************************************
      * 8000 - UTILITY PARAGRAPHS
      ******************************************************************

      *-----------------------------------------------------------------
       8100-FORMAT-AMOUNT.
      *-----------------------------------------------------------------
      *    Formats WS-AMT-WORK-POS into:
      *    - WS-AMT-FORMATTED    (17 chars, right-aligned)
      *    - WS-AMT-FORMATTED-14 (14 chars, right-aligned)
      *    - WS-AMT-TEMP         (trimmed with leading sign/currency)
      *    Handles negative values (WS-AMT-WORK-POS may be signed).
      *    Output format: $n,nnn.nn or -$n,nnn.nn, right-aligned.
      *-----------------------------------------------------------------
           MOVE SPACES TO WS-AMT-FORMATTED
           MOVE SPACES TO WS-AMT-FORMATTED-14
           MOVE SPACES TO WS-AMT-TEMP

           IF WS-AMT-WORK-POS < 0
      *        Negative: format absolute value then prepend -$
      *        WS-AMT-EDIT-POS picture ($$,...) already supplies the $;
      *        we only prepend the minus sign to avoid double-dollar.
               COMPUTE WS-AMT-WORK-POS = WS-AMT-WORK-POS * -1
               MOVE WS-AMT-WORK-POS TO WS-AMT-EDIT-POS
               STRING '-' DELIMITED BY SIZE
                      FUNCTION TRIM(WS-AMT-EDIT-POS, LEADING)
                          DELIMITED BY SIZE
                      INTO WS-AMT-TEMP
               END-STRING
           ELSE
      *        Positive: format with leading $
               MOVE WS-AMT-WORK-POS TO WS-AMT-EDIT-POS
               MOVE FUNCTION TRIM(WS-AMT-EDIT-POS, LEADING)
                   TO WS-AMT-TEMP
           END-IF

      *    Right-align in 17-char field
           COMPUTE WS-AMT-LEN = FUNCTION LENGTH(
               FUNCTION TRIM(WS-AMT-TEMP, TRAILING))
           IF WS-AMT-LEN <= 17
               COMPUTE WS-AMT-START = 17 - WS-AMT-LEN + 1
               MOVE WS-AMT-TEMP TO
                   WS-AMT-FORMATTED(WS-AMT-START : WS-AMT-LEN)
           END-IF

      *    Right-align in 14-char field
           IF WS-AMT-LEN <= 14
               COMPUTE WS-AMT-START = 14 - WS-AMT-LEN + 1
               MOVE WS-AMT-TEMP TO
                   WS-AMT-FORMATTED-14(WS-AMT-START : WS-AMT-LEN)
           END-IF.
       8100-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       8200-FORMAT-DATE.
      *-----------------------------------------------------------------
      *    Converts ISO date in WS-TRAN-DATE-WORK (YYYY-MM-DD)
      *    to WS-TRAN-DATE-DISP format: Mmm DD, YYYY (12 chars).
      *-----------------------------------------------------------------
           MOVE FUNCTION NUMVAL(WS-TD-MM) TO WS-MONTH-ABBR-IDX
           IF WS-MONTH-ABBR-IDX < 1 OR WS-MONTH-ABBR-IDX > 12
               MOVE 1 TO WS-MONTH-ABBR-IDX
           END-IF
           STRING WS-MON-ABBR(WS-MONTH-ABBR-IDX)
                      DELIMITED BY SIZE
                  ' '              DELIMITED BY SIZE
                  WS-TD-DD         DELIMITED BY SIZE
                  ', '             DELIMITED BY SIZE
                  WS-TD-YYYY       DELIMITED BY SIZE
                  INTO WS-TRAN-DATE-DISP
           END-STRING.
       8200-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       8300-FORMAT-SORTCODE.
      *-----------------------------------------------------------------
      *    Reformats WS-SORTCODE-RAW (CHAR 6) to WS-SORTCODE-DISP
      *    in NN-NN-NN format (8 chars).
      *-----------------------------------------------------------------
           MOVE WS-SC-R1 TO WS-SC-D1
           MOVE WS-SC-R2 TO WS-SC-D2
           MOVE WS-SC-R3 TO WS-SC-D3.
       8300-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       8400-WRITE-SYSPRINT.
      *-----------------------------------------------------------------
      *    Writes WS-PRINT-LINE to SYSPRINT-FILE.
      *    Increments WS-LINE-COUNT.
      *-----------------------------------------------------------------
           WRITE SYSPRINT-RECORD FROM WS-PRINT-LINE
           IF WS-SYSPRINT-STATUS NOT = '00'
               DISPLAY 'BNKZE0020: SYSPRINT dataset is unavailable '
                       'or unwritable. File status='
                       WS-SYSPRINT-STATUS
               PERFORM 9100-RAISE-ERROR THRU 9100-EXIT
           ELSE
               ADD 1 TO WS-LINE-COUNT
           END-IF.
       8400-EXIT.
           EXIT.

      ******************************************************************
      * 9000 - RETURN CODE HELPERS
      ******************************************************************

      *-----------------------------------------------------------------
       9100-RAISE-ERROR.
      *-----------------------------------------------------------------
      *    Sets WS-RETURN-CODE to 8 (never lowers it).
      *-----------------------------------------------------------------
           IF WS-RETURN-CODE < 8
               MOVE 8 TO WS-RETURN-CODE
           END-IF.
       9100-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       9200-RAISE-INFO.
      *-----------------------------------------------------------------
      *    Sets WS-RETURN-CODE to 4 (never lowers it, never above 8).
      *-----------------------------------------------------------------
           IF WS-RETURN-CODE < 4
               MOVE 4 TO WS-RETURN-CODE
           END-IF.
       9200-EXIT.
           EXIT.
