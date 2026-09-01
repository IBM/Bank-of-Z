       CBL SQL
      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      ******************************************************************
      *                                                                *
      * Enterprise COBOL for z/OS 6.3 batch program.                   *
      ******************************************************************

       IDENTIFICATION DIVISION.
       PROGRAM-ID. BNK1STMT.
       AUTHOR.     IBM.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.

      *    Savings account report
           SELECT SAVRPT
               ASSIGN TO SAVRPT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL
               FILE STATUS  IS WS-SAVRPT-STATUS.

      *    ISA account report
           SELECT ISARPT
               ASSIGN TO ISARPT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL
               FILE STATUS  IS WS-ISARPT-STATUS.

      *    Current account report
           SELECT CURRPT
               ASSIGN TO CURRPT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL
               FILE STATUS  IS WS-CURRPT-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD  SAVRPT
           RECORDING MODE F
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 250 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  SAVRPT-RECORD              PIC X(250).

       FD  ISARPT
           RECORDING MODE F
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 250 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  ISARPT-RECORD              PIC X(250).

       FD  CURRPT
           RECORDING MODE F
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 250 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  CURRPT-RECORD              PIC X(250).

       WORKING-STORAGE SECTION.

      *-----------------------------------------------------------------
      * DB2 table declarations
      *-----------------------------------------------------------------
           EXEC SQL
               INCLUDE CUSTDB2
           END-EXEC.

           EXEC SQL
               INCLUDE ACCDB2
           END-EXEC.

      *-----------------------------------------------------------------
      * Host variables - JOIN columns fetched by cursor
      *-----------------------------------------------------------------
       01  HOST-JOIN-ROW.
      *    Customer columns
           03 HV-CUST-NUMBER           PIC X(10).
           03 HV-CUST-TITLE            PIC X(10).
           03 HV-CUST-FIRST-NAME       PIC X(50).
           03 HV-CUST-LAST-NAME        PIC X(50).
           03 HV-CUST-PHONE            PIC X(20).
      *    Account columns
           03 HV-ACC-NUMBER            PIC X(8).
           03 HV-ACC-TYPE              PIC X(8).
           03 HV-ACC-INT-RATE          PIC S9(4)V99 COMP-3.
           03 HV-ACC-OPENED            PIC X(10).
           03 HV-ACC-OVERDRAFT-LIM     PIC S9(9) COMP.
           03 HV-ACC-AVAIL-BAL         PIC S9(10)V99 COMP-3.
           03 HV-ACC-ACTUAL-BAL        PIC S9(10)V99 COMP-3.
           03 HV-ACC-NEXT-STMT         PIC X(10).

      *-----------------------------------------------------------------
      * Null indicators for nullable COMP-3 columns
      *-----------------------------------------------------------------
       01  WS-NULL-INDICATORS.
           03 NI-INT-RATE              PIC S9(4) COMP VALUE 0.
           03 NI-AVAIL-BAL             PIC S9(4) COMP VALUE 0.
           03 NI-ACTUAL-BAL            PIC S9(4) COMP VALUE 0.

      *-----------------------------------------------------------------
      * SQL Communications Area
      *-----------------------------------------------------------------
           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      *-----------------------------------------------------------------
      * Cursor - INNER JOIN CUSTOMER and ACCOUNT.
      * Returns all account types; COBOL routes each row to the
      * appropriate report file based on ACCOUNT_TYPE value.
      * No WHERE filter on ACCOUNT_TYPE to avoid EBCDIC literal issues.
      *-----------------------------------------------------------------
           EXEC SQL DECLARE STMT-CURSOR CURSOR FOR
               SELECT C.CUSTOMER_NUMBER,
                      C.CUSTOMER_TITLE,
                      C.CUSTOMER_FIRST_NAME,
                      C.CUSTOMER_LAST_NAME,
                      C.CUSTOMER_PHONE,
                      A.ACCOUNT_NUMBER,
                      A.ACCOUNT_TYPE,
                      A.ACCOUNT_INTEREST_RATE,
                      A.ACCOUNT_OPENED,
                      A.ACCOUNT_OVERDRAFT_LIMIT,
                      A.ACCOUNT_AVAILABLE_BALANCE,
                      A.ACCOUNT_ACTUAL_BALANCE,
                      A.ACCOUNT_NEXT_STATEMENT
               FROM   BANKZ.CUSTOMER C
                      INNER JOIN BANKZ.ACCOUNT A
                          ON A.ACCOUNT_CUSTOMER_NUMBER =
                             C.CUSTOMER_NUMBER
               ORDER BY A.ACCOUNT_TYPE,
                        C.CUSTOMER_NUMBER,
                        A.ACCOUNT_NUMBER
               FOR FETCH ONLY
           END-EXEC.

      *-----------------------------------------------------------------
      * Date reformatting overlay (DB2 DATE is YYYY-MM-DD / 10 chars)
      *-----------------------------------------------------------------
       01  DB2-DATE-REFORMAT.
           03 DB2-DATE-REF-YR          PIC 9(4).
           03 FILLER                   PIC X.
           03 DB2-DATE-REF-MNTH        PIC 99.
           03 FILLER                   PIC X.
           03 DB2-DATE-REF-DAY         PIC 99.

      *-----------------------------------------------------------------
      * Date work field (DD/MM/YYYY formatted output)
      *-----------------------------------------------------------------
       01  WS-DATE-WORK                PIC X(10).
       01  WS-DATE-GRP REDEFINES WS-DATE-WORK.
           03 WS-DATE-DD               PIC XX.
           03 WS-DATE-SEP1             PIC X.
           03 WS-DATE-MM               PIC XX.
           03 WS-DATE-SEP2             PIC X.
           03 WS-DATE-YYYY             PIC X(4).

      *-----------------------------------------------------------------
      * File status fields
      *-----------------------------------------------------------------
       01  WS-SAVRPT-STATUS            PIC XX VALUE '00'.
       01  WS-ISARPT-STATUS            PIC XX VALUE '00'.
       01  WS-CURRPT-STATUS            PIC XX VALUE '00'.

      *-----------------------------------------------------------------
      * SQLCODE display copy for messages
      *-----------------------------------------------------------------
       01  SQLCODE-DISPLAY             PIC S9(8) DISPLAY
               SIGN LEADING SEPARATE.

      *-----------------------------------------------------------------
      * Program return code
      *-----------------------------------------------------------------
       01  WS-RETURN-CODE              PIC S9(4) COMP VALUE 0.

      *-----------------------------------------------------------------
      * Cursor / loop control
      *-----------------------------------------------------------------
       01  WS-CURSOR-OPEN              PIC X VALUE 'N'.
       01  WS-CURSOR-EOF               PIC X VALUE 'N'.

      *-----------------------------------------------------------------
      * Per-report distinct customer tracking and accumulators
      *-----------------------------------------------------------------
       01  WS-SAV-PREV-CUST            PIC X(10) VALUE SPACES.
       01  WS-ISA-PREV-CUST            PIC X(10) VALUE SPACES.
       01  WS-CUR-PREV-CUST            PIC X(10) VALUE SPACES.

       01  WS-SAV-CUST-COUNT           PIC 9(6) COMP VALUE 0.
       01  WS-ISA-CUST-COUNT           PIC 9(6) COMP VALUE 0.
       01  WS-CUR-CUST-COUNT           PIC 9(6) COMP VALUE 0.

       01  WS-SAV-TOTAL-AVAIL          PIC S9(15)V99 COMP-3 VALUE 0.
       01  WS-SAV-TOTAL-ACTUAL         PIC S9(15)V99 COMP-3 VALUE 0.
       01  WS-ISA-TOTAL-AVAIL          PIC S9(15)V99 COMP-3 VALUE 0.
       01  WS-ISA-TOTAL-ACTUAL         PIC S9(15)V99 COMP-3 VALUE 0.
       01  WS-CUR-TOTAL-AVAIL          PIC S9(15)V99 COMP-3 VALUE 0.
       01  WS-CUR-TOTAL-ACTUAL         PIC S9(15)V99 COMP-3 VALUE 0.

      *-----------------------------------------------------------------
      * Total rows written per report (for RC=4 detection)
      *-----------------------------------------------------------------
       01  WS-SAV-ROW-COUNT            PIC 9(6) COMP VALUE 0.
       01  WS-ISA-ROW-COUNT            PIC 9(6) COMP VALUE 0.
       01  WS-CUR-ROW-COUNT            PIC 9(6) COMP VALUE 0.

      *-----------------------------------------------------------------
      * Work field for messages
      *-----------------------------------------------------------------
       01  WS-MSG                      PIC X(80).

      *-----------------------------------------------------------------
      * Current date via CURRENT-DATE intrinsic function
      *-----------------------------------------------------------------
       01  WS-CURRENT-DATE             PIC X(21).
       01  WS-CURR-DATE-GRP
               REDEFINES WS-CURRENT-DATE.
           03 WS-CURR-YYYY             PIC 9(4).
           03 WS-CURR-MM               PIC 99.
           03 WS-CURR-DD               PIC 99.
           03 FILLER                   PIC X(13).

      *-----------------------------------------------------------------
      * Formatted run date (DD/MM/YYYY)
      *-----------------------------------------------------------------
       01  WS-RUN-DATE                 PIC X(10).

      *================================================================
      * Report lines - 250 bytes each
      * Layout: 10+1+10+1+50+1+50+1+20+1+8+1+8+1+5+1+10+1+9+1+14+1+14
      *         +1+10 = 231 data bytes + 19 filler = 250
      *================================================================

      *-----------------------------------------------------------------
      * Title lines (one per report type)
      *-----------------------------------------------------------------
       01  WS-SAV-TITLE-LINE.
           03 FILLER  PIC X(40)
               VALUE 'Bank of Z - Savings Account Statement   '.
           03 FILLER  PIC X(210) VALUE SPACES.

       01  WS-ISA-TITLE-LINE.
           03 FILLER  PIC X(40)
               VALUE 'Bank of Z - ISA Account Statement       '.
           03 FILLER  PIC X(210) VALUE SPACES.

       01  WS-CUR-TITLE-LINE.
           03 FILLER  PIC X(40)
               VALUE 'Bank of Z - Current Account Statement   '.
           03 FILLER  PIC X(210) VALUE SPACES.

      *-----------------------------------------------------------------
      * Run-date line
      *-----------------------------------------------------------------
       01  WS-DATE-LINE.
           03 FILLER       PIC X(11) VALUE 'Run Date:  '.
           03 WS-DL-DATE   PIC X(10).
           03 FILLER       PIC X(229) VALUE SPACES.

      *-----------------------------------------------------------------
      * Separator (250 dashes)
      *-----------------------------------------------------------------
       01  WS-SEPARATOR-LINE           PIC X(250) VALUE ALL '-'.

      *-----------------------------------------------------------------
      * Column heading line - positions mirror detail line exactly
      *-----------------------------------------------------------------
       01  WS-COL-HDR.
           03 FILLER  PIC X(10) VALUE 'CUST-NO   '.
           03 FILLER  PIC X     VALUE SPACE.
           03 FILLER  PIC X(10) VALUE 'TITLE     '.
           03 FILLER  PIC X     VALUE SPACE.
           03 FILLER  PIC X(50) VALUE
               'FIRST-NAME                                        '.
           03 FILLER  PIC X     VALUE SPACE.
           03 FILLER  PIC X(50) VALUE
               'LAST-NAME                                         '.
           03 FILLER  PIC X     VALUE SPACE.
           03 FILLER  PIC X(20) VALUE 'PHONE               '.
           03 FILLER  PIC X     VALUE SPACE.
           03 FILLER  PIC X(8)  VALUE 'ACC-NO  '.
           03 FILLER  PIC X     VALUE SPACE.
           03 FILLER  PIC X(8)  VALUE 'TYPE    '.
           03 FILLER  PIC X     VALUE SPACE.
           03 FILLER  PIC X(5)  VALUE 'RATE '.
           03 FILLER  PIC X     VALUE SPACE.
           03 FILLER  PIC X(10) VALUE 'OPENED    '.
           03 FILLER  PIC X     VALUE SPACE.
           03 FILLER  PIC X(9)  VALUE 'OVERDRAFT'.
           03 FILLER  PIC X     VALUE SPACE.
           03 FILLER  PIC X(14) VALUE ' AVAIL-BALANCE'.
           03 FILLER  PIC X     VALUE SPACE.
           03 FILLER  PIC X(14) VALUE 'ACTUAL-BALANCE'.
           03 FILLER  PIC X     VALUE SPACE.
           03 FILLER  PIC X(10) VALUE 'NEXT-STMT '.
           03 FILLER  PIC X(19) VALUE SPACES.

      *-----------------------------------------------------------------
      * Detail line
      *   10+1+10+1+50+1+50+1+20+1+8+1+8+1+5+1+10+1+9+1+14+1+14+1+10
      *   = 231 bytes + 19 filler = 250
      *-----------------------------------------------------------------
       01  WS-DETAIL-LINE.
           03 WS-DL-CUST-NO      PIC X(10).
           03 FILLER             PIC X     VALUE SPACE.
           03 WS-DL-TITLE        PIC X(10).
           03 FILLER             PIC X     VALUE SPACE.
           03 WS-DL-FNAME        PIC X(50).
           03 FILLER             PIC X     VALUE SPACE.
           03 WS-DL-LNAME        PIC X(50).
           03 FILLER             PIC X     VALUE SPACE.
           03 WS-DL-PHONE        PIC X(20).
           03 FILLER             PIC X     VALUE SPACE.
           03 WS-DL-ACC-NO       PIC X(8).
           03 FILLER             PIC X     VALUE SPACE.
           03 WS-DL-TYPE         PIC X(8).
           03 FILLER             PIC X     VALUE SPACE.
           03 WS-DL-INT-RATE     PIC Z9.99.
           03 FILLER             PIC X     VALUE SPACE.
           03 WS-DL-OPENED       PIC X(10).
           03 FILLER             PIC X     VALUE SPACE.
           03 WS-DL-OVERDRAFT    PIC Z(8)9.
           03 FILLER             PIC X     VALUE SPACE.
           03 WS-DL-AVAIL-BAL    PIC +Z(10)9.99.
           03 FILLER             PIC X     VALUE SPACE.
           03 WS-DL-ACTUAL-BAL   PIC +Z(10)9.99.
           03 FILLER             PIC X     VALUE SPACE.
           03 WS-DL-NEXT-STMT    PIC X(10).
           03 FILLER             PIC X(19) VALUE SPACES.

      *-----------------------------------------------------------------
      * Trailer lines (shared structure, filled per report)
      *-----------------------------------------------------------------
       01  WS-TR-CUST-COUNT.
           03 FILLER             PIC X(30)
               VALUE 'TOTAL NUMBER OF CUSTOMERS    :'.
           03 WS-TR-CUST-NO      PIC ZZZZ9.
           03 FILLER             PIC X(215) VALUE SPACES.

       01  WS-TR-AVAIL-BAL.
           03 FILLER             PIC X(30)
               VALUE 'TOTAL AVAILABLE BALANCE      :'.
           03 WS-TR-AVAIL        PIC +Z(15)9.99.
           03 FILLER             PIC X(201) VALUE SPACES.

       01  WS-TR-ACTUAL-BAL.
           03 FILLER             PIC X(30)
               VALUE 'TOTAL ACTUAL BALANCE         :'.
           03 WS-TR-ACTUAL       PIC +Z(15)9.99.
           03 FILLER             PIC X(201) VALUE SPACES.

      ******************************************************************
       PROCEDURE DIVISION.
      ******************************************************************

      *-----------------------------------------------------------------
       MAIN-CONTROL.
           PERFORM OPEN-FILES
           IF WS-RETURN-CODE = 0
               PERFORM WRITE-ALL-HEADERS
           END-IF
           IF WS-RETURN-CODE = 0
               PERFORM PROCESS-ALL-ACCOUNTS
           END-IF
           IF WS-RETURN-CODE = 0 OR WS-RETURN-CODE = 4
               PERFORM WRITE-ALL-TRAILERS
           END-IF
           PERFORM CLOSE-FILES
           MOVE WS-RETURN-CODE TO RETURN-CODE
           STOP RUN.

      *-----------------------------------------------------------------
       OPEN-FILES.
           OPEN OUTPUT SAVRPT
           IF WS-SAVRPT-STATUS NOT = '00'
               STRING 'BNK1STMT: OPEN SAVRPT failed. Status='
                   DELIMITED BY SIZE
                   WS-SAVRPT-STATUS DELIMITED BY SIZE
                   INTO WS-MSG
               END-STRING
               DISPLAY WS-MSG
               MOVE 16 TO WS-RETURN-CODE
               GO TO OF-EXIT
           END-IF

           OPEN OUTPUT ISARPT
           IF WS-ISARPT-STATUS NOT = '00'
               STRING 'BNK1STMT: OPEN ISARPT failed. Status='
                   DELIMITED BY SIZE
                   WS-ISARPT-STATUS DELIMITED BY SIZE
                   INTO WS-MSG
               END-STRING
               DISPLAY WS-MSG
               MOVE 16 TO WS-RETURN-CODE
               GO TO OF-EXIT
           END-IF

           OPEN OUTPUT CURRPT
           IF WS-CURRPT-STATUS NOT = '00'
               STRING 'BNK1STMT: OPEN CURRPT failed. Status='
                   DELIMITED BY SIZE
                   WS-CURRPT-STATUS DELIMITED BY SIZE
                   INTO WS-MSG
               END-STRING
               DISPLAY WS-MSG
               MOVE 16 TO WS-RETURN-CODE
           END-IF.

       OF-EXIT.
           EXIT.

      *-----------------------------------------------------------------
      * Write title + run-date + separator + col header + separator
      * to each of the three report files
      *-----------------------------------------------------------------
       WRITE-ALL-HEADERS.
           MOVE FUNCTION CURRENT-DATE TO WS-CURRENT-DATE
           MOVE '/' TO WS-DATE-SEP1
           MOVE '/' TO WS-DATE-SEP2
           MOVE WS-CURR-DD   TO WS-DATE-DD
           MOVE WS-CURR-MM   TO WS-DATE-MM
           MOVE WS-CURR-YYYY TO WS-DATE-YYYY
           MOVE WS-DATE-WORK TO WS-RUN-DATE
           MOVE WS-RUN-DATE  TO WS-DL-DATE

           PERFORM WRITE-SAV-HEADER
           IF WS-RETURN-CODE = 0
               PERFORM WRITE-ISA-HEADER
           END-IF
           IF WS-RETURN-CODE = 0
               PERFORM WRITE-CUR-HEADER
           END-IF.

       WAH-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       WRITE-SAV-HEADER.
           MOVE WS-SAV-TITLE-LINE  TO SAVRPT-RECORD
           WRITE SAVRPT-RECORD
           IF WS-SAVRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE SAV title failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WSH-EXIT
           END-IF
           MOVE WS-DATE-LINE       TO SAVRPT-RECORD
           WRITE SAVRPT-RECORD
           IF WS-SAVRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE SAV date failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WSH-EXIT
           END-IF
           MOVE WS-SEPARATOR-LINE  TO SAVRPT-RECORD
           WRITE SAVRPT-RECORD
           IF WS-SAVRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE SAV sep1 failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WSH-EXIT
           END-IF
           MOVE WS-COL-HDR         TO SAVRPT-RECORD
           WRITE SAVRPT-RECORD
           IF WS-SAVRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE SAV hdr failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WSH-EXIT
           END-IF
           MOVE WS-SEPARATOR-LINE  TO SAVRPT-RECORD
           WRITE SAVRPT-RECORD
           IF WS-SAVRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE SAV sep2 failed'
               MOVE 16 TO WS-RETURN-CODE
           END-IF.

       WSH-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       WRITE-ISA-HEADER.
           MOVE WS-ISA-TITLE-LINE  TO ISARPT-RECORD
           WRITE ISARPT-RECORD
           IF WS-ISARPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE ISA title failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WIH-EXIT
           END-IF
           MOVE WS-DATE-LINE       TO ISARPT-RECORD
           WRITE ISARPT-RECORD
           IF WS-ISARPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE ISA date failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WIH-EXIT
           END-IF
           MOVE WS-SEPARATOR-LINE  TO ISARPT-RECORD
           WRITE ISARPT-RECORD
           IF WS-ISARPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE ISA sep1 failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WIH-EXIT
           END-IF
           MOVE WS-COL-HDR         TO ISARPT-RECORD
           WRITE ISARPT-RECORD
           IF WS-ISARPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE ISA hdr failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WIH-EXIT
           END-IF
           MOVE WS-SEPARATOR-LINE  TO ISARPT-RECORD
           WRITE ISARPT-RECORD
           IF WS-ISARPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE ISA sep2 failed'
               MOVE 16 TO WS-RETURN-CODE
           END-IF.

       WIH-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       WRITE-CUR-HEADER.
           MOVE WS-CUR-TITLE-LINE  TO CURRPT-RECORD
           WRITE CURRPT-RECORD
           IF WS-CURRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE CUR title failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WCH-EXIT
           END-IF
           MOVE WS-DATE-LINE       TO CURRPT-RECORD
           WRITE CURRPT-RECORD
           IF WS-CURRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE CUR date failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WCH-EXIT
           END-IF
           MOVE WS-SEPARATOR-LINE  TO CURRPT-RECORD
           WRITE CURRPT-RECORD
           IF WS-CURRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE CUR sep1 failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WCH-EXIT
           END-IF
           MOVE WS-COL-HDR         TO CURRPT-RECORD
           WRITE CURRPT-RECORD
           IF WS-CURRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE CUR hdr failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WCH-EXIT
           END-IF
           MOVE WS-SEPARATOR-LINE  TO CURRPT-RECORD
           WRITE CURRPT-RECORD
           IF WS-CURRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE CUR sep2 failed'
               MOVE 16 TO WS-RETURN-CODE
           END-IF.

       WCH-EXIT.
           EXIT.

      *-----------------------------------------------------------------
      * Open cursor and drive the main report loop
      *-----------------------------------------------------------------
       PROCESS-ALL-ACCOUNTS.
           MOVE 'N'    TO WS-CURSOR-EOF

           EXEC SQL OPEN STMT-CURSOR
           END-EXEC

           IF SQLCODE NOT = 0
               MOVE SQLCODE TO SQLCODE-DISPLAY
               STRING 'BNK1STMT: OPEN STMT-CURSOR failed. SQLCODE='
                   DELIMITED BY SIZE
                   SQLCODE-DISPLAY DELIMITED BY SIZE
                   INTO WS-MSG
               END-STRING
               DISPLAY WS-MSG
               MOVE 12 TO WS-RETURN-CODE
               GO TO PAA-EXIT
           END-IF

           MOVE 'Y' TO WS-CURSOR-OPEN

           PERFORM UNTIL WS-CURSOR-EOF = 'Y'
               PERFORM FETCH-ONE-ROW
           END-PERFORM

           EXEC SQL CLOSE STMT-CURSOR
           END-EXEC
           MOVE 'N' TO WS-CURSOR-OPEN

           IF SQLCODE NOT = 0
               MOVE SQLCODE TO SQLCODE-DISPLAY
               DISPLAY 'BNK1STMT: CLOSE STMT-CURSOR warning. SQLCODE='
                   SQLCODE-DISPLAY
           END-IF

           IF WS-SAV-ROW-COUNT = 0
           AND WS-ISA-ROW-COUNT = 0
           AND WS-CUR-ROW-COUNT = 0
           AND WS-RETURN-CODE   = 0
               DISPLAY 'BNK1STMT: No matching accounts found in DB2'
               MOVE 4 TO WS-RETURN-CODE
           ELSE
               IF WS-RETURN-CODE = 0
                   DISPLAY 'BNK1STMT: Savings rows:  ' WS-SAV-ROW-COUNT
                   DISPLAY 'BNK1STMT: ISA rows:      ' WS-ISA-ROW-COUNT
                   DISPLAY 'BNK1STMT: Current rows:  ' WS-CUR-ROW-COUNT
               END-IF
           END-IF.

       PAA-EXIT.
           EXIT.

      *-----------------------------------------------------------------
      * Fetch one row and route to the correct report file
      *-----------------------------------------------------------------
       FETCH-ONE-ROW.
           EXEC SQL FETCH FROM STMT-CURSOR
               INTO :HV-CUST-NUMBER,
                    :HV-CUST-TITLE,
                    :HV-CUST-FIRST-NAME,
                    :HV-CUST-LAST-NAME,
                    :HV-CUST-PHONE,
                    :HV-ACC-NUMBER,
                    :HV-ACC-TYPE,
                    :HV-ACC-INT-RATE :NI-INT-RATE,
                    :HV-ACC-OPENED,
                    :HV-ACC-OVERDRAFT-LIM,
                    :HV-ACC-AVAIL-BAL :NI-AVAIL-BAL,
                    :HV-ACC-ACTUAL-BAL :NI-ACTUAL-BAL,
                    :HV-ACC-NEXT-STMT
           END-EXEC

           EVALUATE SQLCODE
               WHEN 0
                   PERFORM FORMAT-DETAIL-LINE
                   EVALUATE TRUE
                       WHEN HV-ACC-TYPE(1:6) = 'SAVING'
                           PERFORM ROUTE-TO-SAVRPT
                       WHEN HV-ACC-TYPE(1:3) = 'ISA'
                           PERFORM ROUTE-TO-ISARPT
                       WHEN HV-ACC-TYPE(1:7) = 'CURRENT'
                           PERFORM ROUTE-TO-CURRPT
                       WHEN OTHER
                           CONTINUE
                   END-EVALUATE
               WHEN +100
                   MOVE 'Y' TO WS-CURSOR-EOF
               WHEN OTHER
                   MOVE SQLCODE TO SQLCODE-DISPLAY
                   STRING 'BNK1STMT: FETCH failed. SQLCODE='
                       DELIMITED BY SIZE
                       SQLCODE-DISPLAY DELIMITED BY SIZE
                       INTO WS-MSG
                   END-STRING
                   DISPLAY WS-MSG
                   MOVE 12 TO WS-RETURN-CODE
                   MOVE 'Y' TO WS-CURSOR-EOF
           END-EVALUATE.

       FOR-EXIT.
           EXIT.

      *-----------------------------------------------------------------
      * Route formatted detail line to SAVRPT
      *-----------------------------------------------------------------
       ROUTE-TO-SAVRPT.
           IF HV-CUST-NUMBER NOT = WS-SAV-PREV-CUST
               ADD 1 TO WS-SAV-CUST-COUNT
               MOVE HV-CUST-NUMBER TO WS-SAV-PREV-CUST
           END-IF
           ADD HV-ACC-AVAIL-BAL  TO WS-SAV-TOTAL-AVAIL
           ADD HV-ACC-ACTUAL-BAL TO WS-SAV-TOTAL-ACTUAL
           ADD 1                 TO WS-SAV-ROW-COUNT
           MOVE WS-DETAIL-LINE   TO SAVRPT-RECORD
           WRITE SAVRPT-RECORD
           IF WS-SAVRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE SAVRPT detail failed. Status='
                   WS-SAVRPT-STATUS
               MOVE 16 TO WS-RETURN-CODE
               MOVE 'Y' TO WS-CURSOR-EOF
           END-IF.

       RTS-EXIT.
           EXIT.

      *-----------------------------------------------------------------
      * Route formatted detail line to ISARPT
      *-----------------------------------------------------------------
       ROUTE-TO-ISARPT.
           IF HV-CUST-NUMBER NOT = WS-ISA-PREV-CUST
               ADD 1 TO WS-ISA-CUST-COUNT
               MOVE HV-CUST-NUMBER TO WS-ISA-PREV-CUST
           END-IF
           ADD HV-ACC-AVAIL-BAL  TO WS-ISA-TOTAL-AVAIL
           ADD HV-ACC-ACTUAL-BAL TO WS-ISA-TOTAL-ACTUAL
           ADD 1                 TO WS-ISA-ROW-COUNT
           MOVE WS-DETAIL-LINE   TO ISARPT-RECORD
           WRITE ISARPT-RECORD
           IF WS-ISARPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE ISARPT detail failed. Status='
                   WS-ISARPT-STATUS
               MOVE 16 TO WS-RETURN-CODE
               MOVE 'Y' TO WS-CURSOR-EOF
           END-IF.

       RTI-EXIT.
           EXIT.

      *-----------------------------------------------------------------
      * Route formatted detail line to CURRPT
      *-----------------------------------------------------------------
       ROUTE-TO-CURRPT.
           IF HV-CUST-NUMBER NOT = WS-CUR-PREV-CUST
               ADD 1 TO WS-CUR-CUST-COUNT
               MOVE HV-CUST-NUMBER TO WS-CUR-PREV-CUST
           END-IF
           ADD HV-ACC-AVAIL-BAL  TO WS-CUR-TOTAL-AVAIL
           ADD HV-ACC-ACTUAL-BAL TO WS-CUR-TOTAL-ACTUAL
           ADD 1                 TO WS-CUR-ROW-COUNT
           MOVE WS-DETAIL-LINE   TO CURRPT-RECORD
           WRITE CURRPT-RECORD
           IF WS-CURRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE CURRPT detail failed. Status='
                   WS-CURRPT-STATUS
               MOVE 16 TO WS-RETURN-CODE
               MOVE 'Y' TO WS-CURSOR-EOF
           END-IF.

       RTC-EXIT.
           EXIT.

      *-----------------------------------------------------------------
      * Format one tabular detail line from current host variables
      *-----------------------------------------------------------------
       FORMAT-DETAIL-LINE.
           MOVE HV-CUST-NUMBER       TO WS-DL-CUST-NO
           MOVE HV-CUST-TITLE        TO WS-DL-TITLE
           MOVE HV-CUST-FIRST-NAME   TO WS-DL-FNAME
           MOVE HV-CUST-LAST-NAME    TO WS-DL-LNAME
           MOVE HV-CUST-PHONE        TO WS-DL-PHONE
           MOVE HV-ACC-NUMBER        TO WS-DL-ACC-NO
           MOVE HV-ACC-TYPE          TO WS-DL-TYPE
           IF NI-INT-RATE < 0
               MOVE ZEROS             TO WS-DL-INT-RATE
           ELSE
               MOVE HV-ACC-INT-RATE   TO WS-DL-INT-RATE
           END-IF
      *    Reformat ACCOUNT_OPENED date YYYY-MM-DD -> DD/MM/YYYY
           MOVE HV-ACC-OPENED        TO DB2-DATE-REFORMAT
           MOVE '/' TO WS-DATE-SEP1
           MOVE '/' TO WS-DATE-SEP2
           MOVE DB2-DATE-REF-DAY     TO WS-DATE-DD
           MOVE DB2-DATE-REF-MNTH    TO WS-DATE-MM
           MOVE DB2-DATE-REF-YR      TO WS-DATE-YYYY
           MOVE WS-DATE-WORK         TO WS-DL-OPENED
           MOVE HV-ACC-OVERDRAFT-LIM TO WS-DL-OVERDRAFT
           IF NI-AVAIL-BAL < 0
               MOVE ZEROS             TO WS-DL-AVAIL-BAL
           ELSE
               MOVE HV-ACC-AVAIL-BAL  TO WS-DL-AVAIL-BAL
           END-IF
           IF NI-ACTUAL-BAL < 0
               MOVE ZEROS             TO WS-DL-ACTUAL-BAL
           ELSE
               MOVE HV-ACC-ACTUAL-BAL TO WS-DL-ACTUAL-BAL
           END-IF
      *    Reformat ACCOUNT_NEXT_STATEMENT date YYYY-MM-DD -> DD/MM/YYYY
           MOVE HV-ACC-NEXT-STMT     TO DB2-DATE-REFORMAT
           MOVE '/' TO WS-DATE-SEP1
           MOVE '/' TO WS-DATE-SEP2
           MOVE DB2-DATE-REF-DAY     TO WS-DATE-DD
           MOVE DB2-DATE-REF-MNTH    TO WS-DATE-MM
           MOVE DB2-DATE-REF-YR      TO WS-DATE-YYYY
           MOVE WS-DATE-WORK         TO WS-DL-NEXT-STMT.

       FDL-EXIT.
           EXIT.

      *-----------------------------------------------------------------
      * Write trailers to all three report files
      *-----------------------------------------------------------------
       WRITE-ALL-TRAILERS.
           PERFORM WRITE-SAV-TRAILER
           PERFORM WRITE-ISA-TRAILER
           PERFORM WRITE-CUR-TRAILER.

       WAT-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       WRITE-SAV-TRAILER.
           MOVE WS-SEPARATOR-LINE    TO SAVRPT-RECORD
           WRITE SAVRPT-RECORD
           IF WS-SAVRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE SAV trail-sep failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WST-EXIT
           END-IF
           MOVE WS-SAV-CUST-COUNT    TO WS-TR-CUST-NO
           MOVE WS-TR-CUST-COUNT     TO SAVRPT-RECORD
           WRITE SAVRPT-RECORD
           IF WS-SAVRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE SAV cust-cnt failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WST-EXIT
           END-IF
           MOVE WS-SAV-TOTAL-AVAIL   TO WS-TR-AVAIL
           MOVE WS-TR-AVAIL-BAL      TO SAVRPT-RECORD
           WRITE SAVRPT-RECORD
           IF WS-SAVRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE SAV avail failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WST-EXIT
           END-IF
           MOVE WS-SAV-TOTAL-ACTUAL  TO WS-TR-ACTUAL
           MOVE WS-TR-ACTUAL-BAL     TO SAVRPT-RECORD
           WRITE SAVRPT-RECORD
           IF WS-SAVRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE SAV actual failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WST-EXIT
           END-IF
           MOVE WS-SEPARATOR-LINE    TO SAVRPT-RECORD
           WRITE SAVRPT-RECORD
           IF WS-SAVRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE SAV final-sep failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WST-EXIT
           END-IF
           DISPLAY 'BNK1STMT: Savings report complete. Customers: '
               WS-SAV-CUST-COUNT.

       WST-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       WRITE-ISA-TRAILER.
           MOVE WS-SEPARATOR-LINE    TO ISARPT-RECORD
           WRITE ISARPT-RECORD
           IF WS-ISARPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE ISA trail-sep failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WIT-EXIT
           END-IF
           MOVE WS-ISA-CUST-COUNT    TO WS-TR-CUST-NO
           MOVE WS-TR-CUST-COUNT     TO ISARPT-RECORD
           WRITE ISARPT-RECORD
           IF WS-ISARPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE ISA cust-cnt failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WIT-EXIT
           END-IF
           MOVE WS-ISA-TOTAL-AVAIL   TO WS-TR-AVAIL
           MOVE WS-TR-AVAIL-BAL      TO ISARPT-RECORD
           WRITE ISARPT-RECORD
           IF WS-ISARPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE ISA avail failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WIT-EXIT
           END-IF
           MOVE WS-ISA-TOTAL-ACTUAL  TO WS-TR-ACTUAL
           MOVE WS-TR-ACTUAL-BAL     TO ISARPT-RECORD
           WRITE ISARPT-RECORD
           IF WS-ISARPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE ISA actual failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WIT-EXIT
           END-IF
           MOVE WS-SEPARATOR-LINE    TO ISARPT-RECORD
           WRITE ISARPT-RECORD
           IF WS-ISARPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE ISA final-sep failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WIT-EXIT
           END-IF
           DISPLAY 'BNK1STMT: ISA report complete. Customers: '
               WS-ISA-CUST-COUNT.

       WIT-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       WRITE-CUR-TRAILER.
           MOVE WS-SEPARATOR-LINE    TO CURRPT-RECORD
           WRITE CURRPT-RECORD
           IF WS-CURRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE CUR trail-sep failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WCT-EXIT
           END-IF
           MOVE WS-CUR-CUST-COUNT    TO WS-TR-CUST-NO
           MOVE WS-TR-CUST-COUNT     TO CURRPT-RECORD
           WRITE CURRPT-RECORD
           IF WS-CURRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE CUR cust-cnt failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WCT-EXIT
           END-IF
           MOVE WS-CUR-TOTAL-AVAIL   TO WS-TR-AVAIL
           MOVE WS-TR-AVAIL-BAL      TO CURRPT-RECORD
           WRITE CURRPT-RECORD
           IF WS-CURRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE CUR avail failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WCT-EXIT
           END-IF
           MOVE WS-CUR-TOTAL-ACTUAL  TO WS-TR-ACTUAL
           MOVE WS-TR-ACTUAL-BAL     TO CURRPT-RECORD
           WRITE CURRPT-RECORD
           IF WS-CURRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE CUR actual failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WCT-EXIT
           END-IF
           MOVE WS-SEPARATOR-LINE    TO CURRPT-RECORD
           WRITE CURRPT-RECORD
           IF WS-CURRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: WRITE CUR final-sep failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WCT-EXIT
           END-IF
           DISPLAY 'BNK1STMT: Current report complete. Customers: '
               WS-CUR-CUST-COUNT.

       WCT-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       CLOSE-FILES.
           IF WS-CURSOR-OPEN = 'Y'
               EXEC SQL CLOSE STMT-CURSOR
               END-EXEC
               MOVE 'N' TO WS-CURSOR-OPEN
           END-IF

           CLOSE SAVRPT
           IF WS-SAVRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: CLOSE SAVRPT failed. Status='
                   WS-SAVRPT-STATUS
           END-IF

           CLOSE ISARPT
           IF WS-ISARPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: CLOSE ISARPT failed. Status='
                   WS-ISARPT-STATUS
           END-IF

           CLOSE CURRPT
           IF WS-CURRPT-STATUS NOT = '00'
               DISPLAY 'BNK1STMT: CLOSE CURRPT failed. Status='
                   WS-CURRPT-STATUS
           END-IF.

       CF-EXIT.
           EXIT.
