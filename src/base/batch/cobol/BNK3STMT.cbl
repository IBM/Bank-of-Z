       CBL SQL
      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2026                                      *
      *                                                                *
      ******************************************************************

       IDENTIFICATION DIVISION.
       PROGRAM-ID. BNK3STMT.
       AUTHOR.     IBM.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.

           SELECT SORTCODE-FILE
               ASSIGN TO SORTCODE
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL
               FILE STATUS  IS WS-SORTCODE-STATUS.

           SELECT DATECARD-FILE
               ASSIGN TO DATECARD
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL
               FILE STATUS  IS WS-DATECARD-STATUS.

           SELECT STMTRPT
               ASSIGN TO STMTRPT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL
               FILE STATUS  IS WS-STMTRPT-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD  SORTCODE-FILE
           RECORDING MODE F
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 80 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  SORTCODE-RECORD            PIC X(80).

       FD  DATECARD-FILE
           RECORDING MODE F
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 80 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  DATECARD-RECORD            PIC X(80).

       FD  STMTRPT
           RECORDING MODE F
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 132 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  STMTRPT-RECORD             PIC X(132).

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

           EXEC SQL
               INCLUDE PROCDB2
           END-EXEC.

      *-----------------------------------------------------------------
      * Host variables - CUSTOMER SELECT INTO
      *-----------------------------------------------------------------
       01  HOST-CUSTOMER-ROW.
           03 HV-CUST-EYECATCHER      PIC X(4).
           03 HV-CUST-SORTCODE        PIC X(6).
           03 HV-CUST-NUMBER          PIC X(10).
           03 HV-CUST-TITLE           PIC X(10).
           03 HV-CUST-FIRST-NAME      PIC X(50).
           03 HV-CUST-LAST-NAME       PIC X(50).
           03 HV-CUST-DOB             PIC S9(9) COMP.
           03 HV-CUST-PHONE           PIC X(20).
           03 HV-CUST-ADDR1           PIC X(50).
           03 HV-CUST-ADDR2           PIC X(50).
           03 HV-CUST-CITY            PIC X(50).
           03 HV-CUST-POSTCODE        PIC X(10).
           03 HV-CUST-COUNTRY         PIC X(50).
           03 HV-CUST-STATUS          PIC X(10).
           03 HV-CUST-CREATE-DATE     PIC S9(9) COMP.
           03 HV-CUST-CREDIT-SCORE    PIC S9(4) COMP.
           03 HV-CUST-CS-REVIEW-DATE  PIC S9(9) COMP.

      *-----------------------------------------------------------------
      * Null indicators - customer nullable columns
      *-----------------------------------------------------------------
       01  WS-CUST-NULL-IND.
           03 NI-CUST-TITLE           PIC S9(4) COMP VALUE 0.
           03 NI-CUST-PHONE           PIC S9(4) COMP VALUE 0.
           03 NI-CUST-ADDR2           PIC S9(4) COMP VALUE 0.
           03 NI-CUST-DOB             PIC S9(4) COMP VALUE 0.
           03 NI-CUST-CREDIT-SCORE    PIC S9(4) COMP VALUE 0.
           03 NI-CUST-CS-REVIEW-DATE  PIC S9(4) COMP VALUE 0.

      *-----------------------------------------------------------------
      * Host variables - ACCOUNT cursor
      *-----------------------------------------------------------------
       01  HOST-ACCOUNT-ROW.
           03 HV-ACCT-EYECATCHER      PIC X(4).
           03 HV-ACCT-CUST-NUMBER     PIC X(10).
           03 HV-ACCT-SORTCODE        PIC X(6).
           03 HV-ACCT-NUMBER          PIC X(8).
           03 HV-ACCT-TYPE            PIC X(8).
           03 HV-ACCT-INT-RATE        PIC S9(4)V99 COMP-3.
           03 HV-ACCT-OPENED          PIC X(10).
           03 HV-ACCT-OVERDRAFT-LIM   PIC S9(9) COMP.
           03 HV-ACCT-LAST-STMT       PIC X(10).
           03 HV-ACCT-NEXT-STMT       PIC X(10).
           03 HV-ACCT-AVAIL-BAL       PIC S9(10)V99 COMP-3.
           03 HV-ACCT-ACTUAL-BAL      PIC S9(10)V99 COMP-3.

      *-----------------------------------------------------------------
      * Null indicators - account nullable columns
      *-----------------------------------------------------------------
       01  WS-ACCT-NULL-IND.
           03 NI-ACCT-INT-RATE        PIC S9(4) COMP VALUE 0.
           03 NI-ACCT-OVERDRAFT       PIC S9(4) COMP VALUE 0.
           03 NI-ACCT-LAST-STMT       PIC S9(4) COMP VALUE 0.
           03 NI-ACCT-NEXT-STMT       PIC S9(4) COMP VALUE 0.
           03 NI-ACCT-AVAIL-BAL       PIC S9(4) COMP VALUE 0.
           03 NI-ACCT-ACTUAL-BAL      PIC S9(4) COMP VALUE 0.

      *-----------------------------------------------------------------
      * Host variables - PROCTRAN cursor
      *-----------------------------------------------------------------
       01  HOST-TRAN-ROW.
          03 HV-TRAN-EYECATCHER      PIC X(4).
          03 HV-TRAN-SORTCODE        PIC X(6).
          03 HV-TRAN-NUMBER          PIC X(8).
          03 HV-TRAN-DATE            PIC X(10).
          03 HV-TRAN-TIME            PIC X(6).
          03 HV-TRAN-REF             PIC X(12).
          03 HV-TRAN-TYPE            PIC X(3).
          03 HV-TRAN-DESC            PIC X(40).
          03 HV-TRAN-AMOUNT          PIC S9(10)V99 COMP-3.

      *-----------------------------------------------------------------
      * Null indicator - transaction
      *-----------------------------------------------------------------
       01  WS-TRAN-NULL-IND.
           03 NI-TRAN-DESC            PIC S9(4) COMP VALUE 0.

      *-----------------------------------------------------------------
      * Host variables for cursor WHERE clause
      *-----------------------------------------------------------------
       01  HV-SORTCODE-FILTER         PIC X(6).
       01  HV-TRAN-SORTCODE-FILTER    PIC X(6).
       01  HV-TRAN-NUMBER-FILTER      PIC X(8).
       01  HV-PERIOD-FROM             PIC X(10).
       01  HV-PERIOD-TO               PIC X(10).

      *-----------------------------------------------------------------
      * SQL Communications Area
      *-----------------------------------------------------------------
           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      *-----------------------------------------------------------------
      * Account cursor - all accounts for a given sort code
      *-----------------------------------------------------------------
           EXEC SQL DECLARE ACCT-CURSOR CURSOR FOR
               SELECT ACCOUNT_EYECATCHER,
                      ACCOUNT_CUSTOMER_NUMBER,
                      ACCOUNT_SORTCODE,
                      ACCOUNT_NUMBER,
                      ACCOUNT_TYPE,
                      ACCOUNT_INTEREST_RATE,
                      ACCOUNT_OPENED,
                      ACCOUNT_OVERDRAFT_LIMIT,
                      ACCOUNT_LAST_STATEMENT,
                      ACCOUNT_NEXT_STATEMENT,
                      ACCOUNT_AVAILABLE_BALANCE,
                      ACCOUNT_ACTUAL_BALANCE
               FROM   BANKZ.ACCOUNT
               WHERE  ACCOUNT_SORTCODE = :HV-SORTCODE-FILTER
               ORDER BY ACCOUNT_NUMBER
               FOR FETCH ONLY
           END-EXEC.

      *-----------------------------------------------------------------
      * Transaction cursor - transactions for one account within period
      *-----------------------------------------------------------------
           EXEC SQL DECLARE TRAN-CURSOR CURSOR FOR
               SELECT PROCTRAN_EYECATCHER,
                      PROCTRAN_SORTCODE,
                      PROCTRAN_NUMBER,
                      PROCTRAN_DATE,
                      PROCTRAN_TIME,
                      PROCTRAN_REF,
                      PROCTRAN_TYPE,
                      PROCTRAN_DESC,
                      PROCTRAN_AMOUNT
               FROM   BANKZ.PROCTRAN
               WHERE  PROCTRAN_SORTCODE = :HV-TRAN-SORTCODE-FILTER
               AND    PROCTRAN_NUMBER   = :HV-TRAN-NUMBER-FILTER
               AND    PROCTRAN_DATE    >= :HV-PERIOD-FROM
               AND    PROCTRAN_DATE    <= :HV-PERIOD-TO
               ORDER BY PROCTRAN_DATE,
                        PROCTRAN_TIME
               FOR FETCH ONLY
           END-EXEC.

      *-----------------------------------------------------------------
      * File status fields
      *-----------------------------------------------------------------
       01  WS-SORTCODE-STATUS         PIC XX VALUE '00'.
       01  WS-DATECARD-STATUS         PIC XX VALUE '00'.
       01  WS-STMTRPT-STATUS         PIC XX VALUE '00'.

      *-----------------------------------------------------------------
      * SQLCODE display
      *-----------------------------------------------------------------
       01  SQLCODE-DISPLAY            PIC S9(8) DISPLAY
               SIGN LEADING SEPARATE.

      *-----------------------------------------------------------------
      * Program return code and control flags
      *-----------------------------------------------------------------
       01  WS-RETURN-CODE             PIC S9(4) COMP VALUE 0.
       01  WS-ACCT-CURSOR-OPEN        PIC X VALUE 'N'.
       01  WS-TRAN-CURSOR-OPEN        PIC X VALUE 'N'.
       01  WS-ACCT-EOF                PIC X VALUE 'N'.
       01  WS-TRAN-EOF                PIC X VALUE 'N'.
       01  WS-EOF-SORTCODE            PIC X VALUE 'N'.
       01  WS-EOF-DATECARD            PIC X VALUE 'N'.

      *-----------------------------------------------------------------
      * Input record overlays
      *-----------------------------------------------------------------
       01  WS-SORTCODE-INPUT.
           03 WS-SC-VALUE             PIC X(6).
           03 FILLER                  PIC X(74).

       01  WS-DATECARD-INPUT.
           03 WS-DC-YYYYMM            PIC X(6).
           03 WS-DC-YYYYMM-R REDEFINES WS-DC-YYYYMM.
               05 WS-DC-YEAR          PIC X(4).
               05 WS-DC-MONTH         PIC X(2).
           03 FILLER                  PIC X(74).

      *-----------------------------------------------------------------
      * Statement period work fields
      *-----------------------------------------------------------------
       01  WS-STMT-DATE               PIC X(10).
       01  WS-PERIOD-FROM-DISP        PIC X(10).
       01  WS-PERIOD-TO-DISP          PIC X(10).
       01  WS-YEAR                    PIC X(4).
       01  WS-MONTH                   PIC X(2).
       01  WS-LAST-DAY                PIC XX.

      *-----------------------------------------------------------------
      * Date work fields
      *-----------------------------------------------------------------
       01  WS-CURRENT-DATE            PIC X(21).
       01  WS-CURR-DATE-GRP
               REDEFINES WS-CURRENT-DATE.
           03 WS-CURR-YYYY            PIC X(4).
           03 WS-CURR-MM              PIC X(2).
           03 WS-CURR-DD              PIC X(2).
           03 FILLER                  PIC X(13).


      *-----------------------------------------------------------------
      * Paging control
      *-----------------------------------------------------------------
       01  WS-LINE-COUNT              PIC 9(4) COMP VALUE 0.
       01  WS-PAGE-COUNT              PIC 9(4) COMP VALUE 1.
       01  WS-ACCT-COUNT              PIC 9(6) COMP VALUE 0.
       01  WS-LINES-PER-PAGE          PIC 9(4) COMP VALUE 55.

      *-----------------------------------------------------------------
      * Per-statement accumulators
      *-----------------------------------------------------------------
       01  WS-TRANS-COUNT             PIC 9(6) COMP VALUE 0.
       01  WS-TOTAL-CREDITS           PIC S9(12)V99 COMP-3 VALUE 0.
       01  WS-TOTAL-DEBITS            PIC S9(12)V99 COMP-3 VALUE 0.
       01  WS-ABS-AMOUNT              PIC S9(12)V99 COMP-3 VALUE 0.
       01  WS-OPENING-BAL             PIC S9(12)V99 COMP-3 VALUE 0.
       01  WS-CLOSING-BAL             PIC S9(12)V99 COMP-3 VALUE 0.

      *-----------------------------------------------------------------
      * Work field for messages
      *-----------------------------------------------------------------
       01  WS-MSG                     PIC X(80).

      *================================================================
      * Report line - 132 bytes
      *================================================================
       01  WS-REPORT-LINE             PIC X(132).

      *-----------------------------------------------------------------
      * Formatted amount work fields
      *-----------------------------------------------------------------
       01  WS-AMOUNT-EDIT             PIC +ZZZ,ZZZ,ZZZ,ZZ9.99.
       01  WS-INT-RATE-EDIT           PIC Z9.99.
       01  WS-OVERDRAFT-EDIT          PIC ZZZ,ZZZ,ZZ9.
       01  WS-TRANS-COUNT-EDIT        PIC ZZZZZ9.

      *-----------------------------------------------------------------
      * Transaction date/time display work
      *-----------------------------------------------------------------
       01  WS-TRAN-DATE-DISP          PIC X(10).
       01  WS-TRAN-TIME-DISP          PIC X(8).

      ******************************************************************
       PROCEDURE DIVISION.
      ******************************************************************

      *-----------------------------------------------------------------
       MAIN-CONTROL.
           PERFORM OPEN-FILES
           IF WS-RETURN-CODE = 0
               PERFORM GET-STATEMENT-PERIOD
               IF WS-RETURN-CODE = 0
                   DISPLAY 'BNK3STMT - BANK MONTHLY STATEMENT PROGRAM'
                   DISPLAY '=========================================='
                   PERFORM PROCESS-ALL-ACCOUNTS
               END-IF
           END-IF
           PERFORM CLOSE-FILES
           IF WS-RETURN-CODE = 0
               DISPLAY 'BNK3STMT COMPLETED SUCCESSFULLY'
               DISPLAY 'TOTAL STATEMENTS GENERATED: ' WS-ACCT-COUNT
           END-IF
           MOVE WS-RETURN-CODE TO RETURN-CODE
           STOP RUN.

      *-----------------------------------------------------------------
       OPEN-FILES.
           OPEN INPUT SORTCODE-FILE
           IF WS-SORTCODE-STATUS NOT = '00'
               DISPLAY 'BNK3STMT: OPEN SORTCODE failed. Status='
                   WS-SORTCODE-STATUS
               MOVE 8 TO WS-RETURN-CODE
           ELSE
               OPEN OUTPUT STMTRPT
               IF WS-STMTRPT-STATUS NOT = '00'
                   DISPLAY 'BNK3STMT: OPEN SYSPRINT failed. Status='
                       WS-STMTRPT-STATUS
                   MOVE 16 TO WS-RETURN-CODE
               END-IF
           END-IF.

      *-----------------------------------------------------------------
      * Read SORTCODE and DATECARD; derive period-from / period-to
      *-----------------------------------------------------------------
       GET-STATEMENT-PERIOD.
           READ SORTCODE-FILE INTO WS-SORTCODE-INPUT
               AT END MOVE 'Y' TO WS-EOF-SORTCODE
           END-READ
           IF WS-SORTCODE-STATUS NOT = '00'
           AND WS-SORTCODE-STATUS NOT = '10'
               DISPLAY 'BNK3STMT: READ SORTCODE failed. Status='
                   WS-SORTCODE-STATUS
               MOVE 8 TO WS-RETURN-CODE
           ELSE
               IF WS-EOF-SORTCODE = 'Y'
                   DISPLAY 'BNK3STMT: SORTCODE file empty - default'
                   MOVE '987654' TO WS-SC-VALUE
               END-IF
               IF WS-SC-VALUE NOT NUMERIC
                   DISPLAY 'BNK3STMT: Non-numeric SORTCODE: ['
                       WS-SC-VALUE ']'
                   MOVE 8 TO WS-RETURN-CODE
               ELSE
                   MOVE WS-SC-VALUE TO HV-SORTCODE-FILTER
                   DISPLAY 'BNK3STMT: SORT CODE: ' HV-SORTCODE-FILTER
      *            Try to open DATECARD - optional file
                   OPEN INPUT DATECARD-FILE
                   IF WS-DATECARD-STATUS = '35'
                       DISPLAY 'BNK3STMT: DATECARD not found - '
                           'using current month'
                       PERFORM USE-CURRENT-DATE
                   ELSE
                       IF WS-DATECARD-STATUS NOT = '00'
                           DISPLAY 'BNK3STMT: OPEN DATECARD failed.'
                               ' Status=' WS-DATECARD-STATUS
                           PERFORM USE-CURRENT-DATE
                       ELSE
                           READ DATECARD-FILE INTO WS-DATECARD-INPUT
                               AT END MOVE 'Y' TO WS-EOF-DATECARD
                           END-READ
                           CLOSE DATECARD-FILE
                           IF WS-EOF-DATECARD = 'Y'
                               DISPLAY 'BNK3STMT: DATECARD empty - '
                                   'using current month'
                               PERFORM USE-CURRENT-DATE
                           ELSE
                               MOVE WS-DC-YYYYMM(1:4) TO WS-YEAR
                               MOVE WS-DC-YYYYMM(5:2) TO WS-MONTH
                               PERFORM CALC-LAST-DAY
                               MOVE WS-YEAR  TO WS-STMT-DATE(1:4)
                               MOVE '-'      TO WS-STMT-DATE(5:1)
                               MOVE WS-MONTH TO WS-STMT-DATE(6:2)
                               MOVE '-'      TO WS-STMT-DATE(8:1)
                               MOVE WS-LAST-DAY TO WS-STMT-DATE(9:2)
                               STRING WS-YEAR  DELIMITED BY SIZE
                                      '-'      DELIMITED BY SIZE
                                      WS-MONTH DELIMITED BY SIZE
                                      '-'      DELIMITED BY SIZE
                                      '01'     DELIMITED BY SIZE
                                   INTO WS-PERIOD-FROM-DISP
                               STRING WS-YEAR      DELIMITED BY SIZE
                                      '-'          DELIMITED BY SIZE
                                      WS-MONTH     DELIMITED BY SIZE
                                      '-'          DELIMITED BY SIZE
                                      WS-LAST-DAY  DELIMITED BY SIZE
                                   INTO WS-PERIOD-TO-DISP
                               MOVE WS-PERIOD-FROM-DISP
                                   TO HV-PERIOD-FROM
                               MOVE WS-PERIOD-TO-DISP
                                   TO HV-PERIOD-TO
                               DISPLAY 'BNK3STMT: REPORTING MONTH: '
                                   WS-DC-YYYYMM
                               DISPLAY 'BNK3STMT: PERIOD: '
                                   WS-PERIOD-FROM-DISP
                                   ' TO ' WS-PERIOD-TO-DISP
                           END-IF
                       END-IF
                   END-IF
               END-IF
           END-IF.

      *-----------------------------------------------------------------
       USE-CURRENT-DATE.
           MOVE FUNCTION CURRENT-DATE TO WS-CURRENT-DATE
           MOVE WS-CURR-YYYY TO WS-YEAR
           MOVE WS-CURR-MM   TO WS-MONTH
           PERFORM CALC-LAST-DAY
           MOVE WS-CURR-YYYY TO WS-STMT-DATE(1:4)
           MOVE '-'          TO WS-STMT-DATE(5:1)
           MOVE WS-CURR-MM   TO WS-STMT-DATE(6:2)
           MOVE '-'          TO WS-STMT-DATE(8:1)
           MOVE WS-CURR-DD   TO WS-STMT-DATE(9:2)
           STRING WS-YEAR   DELIMITED BY SIZE
                  '-'        DELIMITED BY SIZE
                  WS-MONTH   DELIMITED BY SIZE
                  '-'        DELIMITED BY SIZE
                  '01'       DELIMITED BY SIZE
               INTO WS-PERIOD-FROM-DISP
           STRING WS-YEAR     DELIMITED BY SIZE
                  '-'         DELIMITED BY SIZE
                  WS-MONTH    DELIMITED BY SIZE
                  '-'         DELIMITED BY SIZE
                  WS-CURR-DD  DELIMITED BY SIZE
               INTO WS-PERIOD-TO-DISP
           MOVE WS-PERIOD-FROM-DISP TO HV-PERIOD-FROM
           MOVE WS-PERIOD-TO-DISP   TO HV-PERIOD-TO
           DISPLAY 'BNK3STMT: USING CURRENT DATE PERIOD: '
               WS-PERIOD-FROM-DISP ' TO ' WS-PERIOD-TO-DISP.

      *-----------------------------------------------------------------
      * Calculate last day of WS-MONTH / WS-YEAR
      *-----------------------------------------------------------------
       CALC-LAST-DAY.
           EVALUATE WS-MONTH
               WHEN '02'
                   MOVE '28' TO WS-LAST-DAY
               WHEN '04'
               WHEN '06'
               WHEN '09'
               WHEN '11'
                   MOVE '30' TO WS-LAST-DAY
               WHEN OTHER
                   MOVE '31' TO WS-LAST-DAY
           END-EVALUATE.

      *-----------------------------------------------------------------
      * Open account cursor and drive the main loop
      *-----------------------------------------------------------------
       PROCESS-ALL-ACCOUNTS.
           DISPLAY 'BNK3STMT: PROCESSING ACCOUNTS FOR SORT CODE: '
               HV-SORTCODE-FILTER

           EXEC SQL OPEN ACCT-CURSOR
           END-EXEC

           IF SQLCODE NOT = 0
               MOVE SQLCODE TO SQLCODE-DISPLAY
               STRING 'BNK3STMT: OPEN ACCT-CURSOR failed. SQLCODE='
                   DELIMITED BY SIZE
                   SQLCODE-DISPLAY DELIMITED BY SIZE
                   INTO WS-MSG
               END-STRING
               DISPLAY WS-MSG
               MOVE 12 TO WS-RETURN-CODE
           ELSE
               MOVE 'Y' TO WS-ACCT-CURSOR-OPEN
               MOVE 'N' TO WS-ACCT-EOF
               PERFORM UNTIL WS-ACCT-EOF = 'Y'
                   PERFORM FETCH-ACCOUNT
                   IF WS-ACCT-EOF = 'N'
                       PERFORM GENERATE-STATEMENT
                   END-IF
               END-PERFORM
               EXEC SQL CLOSE ACCT-CURSOR
               END-EXEC
               MOVE 'N' TO WS-ACCT-CURSOR-OPEN
               IF WS-ACCT-COUNT = 0 AND WS-RETURN-CODE = 0
                   DISPLAY 'BNK3STMT: No accounts found for sort '
                       'code: ' HV-SORTCODE-FILTER
                   MOVE 4 TO WS-RETURN-CODE
               END-IF
           END-IF.

      *-----------------------------------------------------------------
       FETCH-ACCOUNT.
           EXEC SQL FETCH ACCT-CURSOR
               INTO :HV-ACCT-EYECATCHER,
                    :HV-ACCT-CUST-NUMBER,
                    :HV-ACCT-SORTCODE,
                    :HV-ACCT-NUMBER,
                    :HV-ACCT-TYPE,
                    :HV-ACCT-INT-RATE     :NI-ACCT-INT-RATE,
                    :HV-ACCT-OPENED,
                    :HV-ACCT-OVERDRAFT-LIM :NI-ACCT-OVERDRAFT,
                    :HV-ACCT-LAST-STMT    :NI-ACCT-LAST-STMT,
                    :HV-ACCT-NEXT-STMT    :NI-ACCT-NEXT-STMT,
                    :HV-ACCT-AVAIL-BAL    :NI-ACCT-AVAIL-BAL,
                    :HV-ACCT-ACTUAL-BAL   :NI-ACCT-ACTUAL-BAL
           END-EXEC

           EVALUATE SQLCODE
               WHEN 0
                   CONTINUE
               WHEN +100
                   MOVE 'Y' TO WS-ACCT-EOF
               WHEN OTHER
                   MOVE SQLCODE TO SQLCODE-DISPLAY
                   DISPLAY 'BNK3STMT: FETCH ACCT-CURSOR failed. '
                       'SQLCODE=' SQLCODE-DISPLAY
                   MOVE 12 TO WS-RETURN-CODE
                   MOVE 'Y' TO WS-ACCT-EOF
           END-EVALUATE.

      *-----------------------------------------------------------------
      * Generate one complete statement for the current account
      *-----------------------------------------------------------------
       GENERATE-STATEMENT.
           ADD 1 TO WS-ACCT-COUNT
           MOVE 0 TO WS-TRANS-COUNT
           MOVE 0 TO WS-TOTAL-CREDITS
           MOVE 0 TO WS-TOTAL-DEBITS

           PERFORM GET-CUSTOMER-INFO
           PERFORM PRINT-HEADER
           PERFORM PRINT-ACCOUNT-INFO
           PERFORM PROCESS-TRANSACTIONS
           PERFORM PRINT-SUMMARY
           PERFORM PRINT-FOOTER.

      *-----------------------------------------------------------------
      * SELECT INTO customer for current account
      *-----------------------------------------------------------------
       GET-CUSTOMER-INFO.
           EXEC SQL
               SELECT CUSTOMER_EYECATCHER,
                      CUSTOMER_SORTCODE,
                      CUSTOMER_NUMBER,
                      CUSTOMER_TITLE,
                      CUSTOMER_FIRST_NAME,
                      CUSTOMER_LAST_NAME,
                      CUSTOMER_DATE_OF_BIRTH,
                      CUSTOMER_PHONE,
                      CUSTOMER_ADDR_LINE1,
                      CUSTOMER_ADDR_LINE2,
                      CUSTOMER_CITY,
                      CUSTOMER_POSTCODE,
                      CUSTOMER_COUNTRY,
                      CUSTOMER_STATUS,
                      CUSTOMER_CREATED_DATE,
                      CUSTOMER_CREDIT_SCORE,
                      CUSTOMER_CS_REVIEW_DATE
               INTO  :HV-CUST-EYECATCHER,
                     :HV-CUST-SORTCODE,
                     :HV-CUST-NUMBER,
                     :HV-CUST-TITLE         :NI-CUST-TITLE,
                     :HV-CUST-FIRST-NAME,
                     :HV-CUST-LAST-NAME,
                     :HV-CUST-DOB           :NI-CUST-DOB,
                     :HV-CUST-PHONE         :NI-CUST-PHONE,
                     :HV-CUST-ADDR1,
                     :HV-CUST-ADDR2         :NI-CUST-ADDR2,
                     :HV-CUST-CITY,
                     :HV-CUST-POSTCODE,
                     :HV-CUST-COUNTRY,
                     :HV-CUST-STATUS,
                     :HV-CUST-CREATE-DATE,
                     :HV-CUST-CREDIT-SCORE  :NI-CUST-CREDIT-SCORE,
                     :HV-CUST-CS-REVIEW-DATE :NI-CUST-CS-REVIEW-DATE
               FROM  BANKZ.CUSTOMER
               WHERE CUSTOMER_NUMBER   = :HV-ACCT-CUST-NUMBER
               AND   CUSTOMER_SORTCODE = :HV-ACCT-SORTCODE
           END-EXEC

           EVALUATE SQLCODE
               WHEN 0
                   CONTINUE
               WHEN +100
                   DISPLAY 'BNK3STMT: WARNING customer not found for '
                       'account ' HV-ACCT-NUMBER
                   MOVE SPACES TO HV-CUST-FIRST-NAME
                   MOVE SPACES TO HV-CUST-LAST-NAME
                   MOVE SPACES TO HV-CUST-TITLE
                   MOVE SPACES TO HV-CUST-PHONE
                   MOVE SPACES TO HV-CUST-ADDR1
                   MOVE SPACES TO HV-CUST-ADDR2
                   MOVE SPACES TO HV-CUST-CITY
                   MOVE SPACES TO HV-CUST-POSTCODE
                   MOVE SPACES TO HV-CUST-COUNTRY
               WHEN OTHER
                   MOVE SQLCODE TO SQLCODE-DISPLAY
                   DISPLAY 'BNK3STMT: ERROR retrieving customer. '
                       'SQLCODE=' SQLCODE-DISPLAY
                   MOVE SPACES TO HV-CUST-FIRST-NAME
                   MOVE SPACES TO HV-CUST-LAST-NAME
           END-EVALUATE.

      *-----------------------------------------------------------------
      * Check page break  print new header if needed
      *-----------------------------------------------------------------
       CHECK-PAGE-BREAK.
           IF WS-LINE-COUNT >= WS-LINES-PER-PAGE
               PERFORM WRITE-PAGE-BREAK
               ADD 1 TO WS-PAGE-COUNT
           END-IF.

      *-----------------------------------------------------------------
       WRITE-PAGE-BREAK.
           MOVE SPACES TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           MOVE 0 TO WS-LINE-COUNT.

      *-----------------------------------------------------------------
      * Write one report line and bump line counter
      *-----------------------------------------------------------------
       WRITE-LINE.
           MOVE WS-REPORT-LINE TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNK3STMT: WRITE SYSPRINT failed. Status='
                   WS-STMTRPT-STATUS
               MOVE 16 TO WS-RETURN-CODE
           END-IF
           ADD 1 TO WS-LINE-COUNT.

      *-----------------------------------------------------------------
      * Print statement header (title, dates, page number)
      *-----------------------------------------------------------------
       PRINT-HEADER.
           PERFORM CHECK-PAGE-BREAK

           MOVE SPACES TO WS-REPORT-LINE
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           STRING
               'BANK OF Z'
               DELIMITED BY SIZE
               INTO WS-REPORT-LINE(62:9)
           END-STRING
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           STRING
               'MONTHLY ACCOUNT STATEMENT'
               DELIMITED BY SIZE
               INTO WS-REPORT-LINE(54:25)
           END-STRING
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           STRING
               '================================'
               DELIMITED BY SIZE
               INTO WS-REPORT-LINE(51:32)
           END-STRING
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           PERFORM WRITE-LINE

           STRING 'STATEMENT DATE: ' DELIMITED BY SIZE
                  WS-STMT-DATE       DELIMITED BY SIZE
               INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-LINE

           STRING 'STATEMENT PERIOD: '    DELIMITED BY SIZE
                  WS-PERIOD-FROM-DISP    DELIMITED BY SIZE
                  ' TO '                 DELIMITED BY SIZE
                  WS-PERIOD-TO-DISP      DELIMITED BY SIZE
               INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-LINE

           MOVE WS-PAGE-COUNT TO WS-TRANS-COUNT-EDIT
           MOVE SPACES TO WS-REPORT-LINE
           STRING 'PAGE: ' DELIMITED BY SIZE
                  FUNCTION TRIM(WS-TRANS-COUNT-EDIT)
                  DELIMITED BY SIZE
               INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-LINE.

      *-----------------------------------------------------------------
      * Print customer and account information section
      *-----------------------------------------------------------------
       PRINT-ACCOUNT-INFO.
           PERFORM CHECK-PAGE-BREAK

           MOVE SPACES TO WS-REPORT-LINE
           PERFORM WRITE-LINE

           MOVE 'CUSTOMER INFORMATION:' TO WS-REPORT-LINE
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           STRING '  NAME: '               DELIMITED BY SIZE
                  FUNCTION TRIM(HV-CUST-TITLE) DELIMITED BY SIZE
                  ' '                      DELIMITED BY SIZE
                  FUNCTION TRIM(HV-CUST-FIRST-NAME)
                                           DELIMITED BY SIZE
                  ' '                      DELIMITED BY SIZE
                  FUNCTION TRIM(HV-CUST-LAST-NAME)
                                           DELIMITED BY SIZE
               INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           STRING '  ADDRESS: '
                  DELIMITED BY SIZE
                  FUNCTION TRIM(HV-CUST-ADDR1)
                  DELIMITED BY SIZE
               INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-LINE

           IF NI-CUST-ADDR2 >= 0 AND
              FUNCTION TRIM(HV-CUST-ADDR2) NOT = SPACES
               MOVE SPACES TO WS-REPORT-LINE
               STRING '           '
                      DELIMITED BY SIZE
                      FUNCTION TRIM(HV-CUST-ADDR2)
                      DELIMITED BY SIZE
                   INTO WS-REPORT-LINE
               END-STRING
               PERFORM WRITE-LINE
           END-IF

           MOVE SPACES TO WS-REPORT-LINE
           STRING '           '
                  DELIMITED BY SIZE
                  FUNCTION TRIM(HV-CUST-CITY)
                  DELIMITED BY SIZE
                  ', '
                  DELIMITED BY SIZE
                  FUNCTION TRIM(HV-CUST-POSTCODE)
                  DELIMITED BY SIZE
               INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           STRING '           '
                  DELIMITED BY SIZE
                  FUNCTION TRIM(HV-CUST-COUNTRY)
                  DELIMITED BY SIZE
               INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           IF NI-CUST-PHONE < 0 OR HV-CUST-PHONE = SPACES
               MOVE '  PHONE: N/A' TO WS-REPORT-LINE
           ELSE
               STRING '  PHONE: '
                      DELIMITED BY SIZE
                      FUNCTION TRIM(HV-CUST-PHONE)
                      DELIMITED BY SIZE
                   INTO WS-REPORT-LINE
               END-STRING
           END-IF
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           PERFORM WRITE-LINE

           MOVE 'ACCOUNT INFORMATION:' TO WS-REPORT-LINE
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           STRING '  ACCOUNT NUMBER: '
                  DELIMITED BY SIZE
                  HV-ACCT-NUMBER
                  DELIMITED BY SIZE
               INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           STRING '  ACCOUNT TYPE: '
                  DELIMITED BY SIZE
                  FUNCTION TRIM(HV-ACCT-TYPE)
                  DELIMITED BY SIZE
               INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           IF NI-ACCT-INT-RATE < 0
               MOVE '  INTEREST RATE: N/A' TO WS-REPORT-LINE
           ELSE
               MOVE HV-ACCT-INT-RATE TO WS-INT-RATE-EDIT
               STRING '  INTEREST RATE: '
                      DELIMITED BY SIZE
                      FUNCTION TRIM(WS-INT-RATE-EDIT)
                      DELIMITED BY SIZE
                      '%' DELIMITED BY SIZE
                   INTO WS-REPORT-LINE
               END-STRING
           END-IF
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           IF NI-ACCT-OVERDRAFT < 0
               MOVE '  OVERDRAFT LIMIT: N/A' TO WS-REPORT-LINE
           ELSE
               MOVE HV-ACCT-OVERDRAFT-LIM TO WS-OVERDRAFT-EDIT
               STRING '  OVERDRAFT LIMIT: '
                      DELIMITED BY SIZE
                      FUNCTION TRIM(WS-OVERDRAFT-EDIT) DELIMITED BY SIZE
                   INTO WS-REPORT-LINE
               END-STRING
           END-IF
           PERFORM WRITE-LINE.

      *-----------------------------------------------------------------
      * Process and print transaction history for current account
      *-----------------------------------------------------------------
       PROCESS-TRANSACTIONS.
           PERFORM CHECK-PAGE-BREAK

           MOVE SPACES TO WS-REPORT-LINE
           PERFORM WRITE-LINE

           MOVE 'TRANSACTION HISTORY:' TO WS-REPORT-LINE
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           MOVE 'DATE'        TO WS-REPORT-LINE(1:4)
           MOVE 'TIME'        TO WS-REPORT-LINE(12:4)
           MOVE 'TYPE'        TO WS-REPORT-LINE(22:4)
           MOVE 'REFERENCE'   TO WS-REPORT-LINE(27:9)
           MOVE 'DESCRIPTION' TO WS-REPORT-LINE(41:11)
           MOVE 'AMOUNT'      TO WS-REPORT-LINE(96:6)
           PERFORM WRITE-LINE

           MOVE ALL '-' TO WS-REPORT-LINE
           PERFORM WRITE-LINE

           MOVE HV-ACCT-SORTCODE TO HV-TRAN-SORTCODE-FILTER
           MOVE HV-ACCT-NUMBER   TO HV-TRAN-NUMBER-FILTER

           EXEC SQL OPEN TRAN-CURSOR
           END-EXEC

           IF SQLCODE NOT = 0
               MOVE SQLCODE TO SQLCODE-DISPLAY
               DISPLAY 'BNK3STMT: OPEN TRAN-CURSOR failed. SQLCODE='
                   SQLCODE-DISPLAY
               MOVE 12 TO WS-RETURN-CODE
           ELSE
               MOVE 'Y' TO WS-TRAN-CURSOR-OPEN
               MOVE 'N' TO WS-TRAN-EOF

               PERFORM UNTIL WS-TRAN-EOF = 'Y'
                   PERFORM FETCH-TRANSACTION
               END-PERFORM

               EXEC SQL CLOSE TRAN-CURSOR
               END-EXEC
               MOVE 'N' TO WS-TRAN-CURSOR-OPEN

               IF WS-TRANS-COUNT = 0
                   MOVE '  NO TRANSACTIONS FOR THIS PERIOD'
                       TO WS-REPORT-LINE
                   PERFORM WRITE-LINE
               END-IF
           END-IF.

      *-----------------------------------------------------------------
       FETCH-TRANSACTION.
           EXEC SQL FETCH TRAN-CURSOR
               INTO :HV-TRAN-EYECATCHER,
                    :HV-TRAN-SORTCODE,
                    :HV-TRAN-NUMBER,
                    :HV-TRAN-DATE,
                    :HV-TRAN-TIME,
                    :HV-TRAN-REF,
                    :HV-TRAN-TYPE,
                    :HV-TRAN-DESC  :NI-TRAN-DESC,
                    :HV-TRAN-AMOUNT
           END-EXEC

           EVALUATE SQLCODE
               WHEN 0
                   PERFORM PRINT-TRANSACTION
                   ADD 1 TO WS-TRANS-COUNT
                   EVALUATE TRUE
                       WHEN HV-TRAN-AMOUNT > 0
                           ADD HV-TRAN-AMOUNT TO WS-TOTAL-CREDITS
                       WHEN HV-TRAN-AMOUNT < 0
                           COMPUTE WS-ABS-AMOUNT =
                               FUNCTION ABS(HV-TRAN-AMOUNT)
                           ADD WS-ABS-AMOUNT TO WS-TOTAL-DEBITS
                   END-EVALUATE
               WHEN +100
                   MOVE 'Y' TO WS-TRAN-EOF
               WHEN OTHER
                   MOVE SQLCODE TO SQLCODE-DISPLAY
                   DISPLAY 'BNK3STMT: FETCH TRAN-CURSOR failed. '
                       'SQLCODE=' SQLCODE-DISPLAY
                   MOVE 'Y' TO WS-TRAN-EOF
           END-EVALUATE.

      *-----------------------------------------------------------------
      * Print one transaction detail line
      *-----------------------------------------------------------------
       PRINT-TRANSACTION.
           PERFORM CHECK-PAGE-BREAK
      *    DATE is already YYYY-MM-DD from DB2; copy directly
           MOVE HV-TRAN-DATE TO WS-TRAN-DATE-DISP
      *    Format time HHMMSS -> HH:MM:SS
           STRING HV-TRAN-TIME(1:2) DELIMITED BY SIZE
                  ':'                DELIMITED BY SIZE
                  HV-TRAN-TIME(3:2) DELIMITED BY SIZE
                  ':'                DELIMITED BY SIZE
                  HV-TRAN-TIME(5:2) DELIMITED BY SIZE
               INTO WS-TRAN-TIME-DISP
           END-STRING
      *    Handle null description
           IF NI-TRAN-DESC < 0
               MOVE 'N/A' TO HV-TRAN-DESC
           END-IF
      *    Format amount
           MOVE HV-TRAN-AMOUNT TO WS-AMOUNT-EDIT
      *    Fixed-column layout:
      *    Col  1-10: date (YYYY-MM-DD)
      *    Col 11   : space
      *    Col 12-19: time (HH:MM:SS)
      *    Col 20-21: spaces
      *    Col 22-24: type (3)
      *    Col 25-26: spaces
      *    Col 27-38: reference (12)
      *    Col 39-40: spaces
      *    Col 41-80: description (40, left-justified)
      *    Col 81-  : amount (right-side)
           MOVE SPACES         TO WS-REPORT-LINE
           MOVE WS-TRAN-DATE-DISP TO WS-REPORT-LINE(1:10)
           MOVE WS-TRAN-TIME-DISP TO WS-REPORT-LINE(12:8)
           MOVE HV-TRAN-TYPE      TO WS-REPORT-LINE(22:3)
           MOVE HV-TRAN-REF       TO WS-REPORT-LINE(27:12)
           MOVE HV-TRAN-DESC      TO WS-REPORT-LINE(41:40)
           MOVE WS-AMOUNT-EDIT    TO WS-REPORT-LINE(82:20)
           PERFORM WRITE-LINE.


      *-----------------------------------------------------------------
      * Print statement summary
      *-----------------------------------------------------------------
       PRINT-SUMMARY.
           PERFORM CHECK-PAGE-BREAK

           MOVE SPACES TO WS-REPORT-LINE
           PERFORM WRITE-LINE

           MOVE '================================' TO WS-REPORT-LINE
           PERFORM WRITE-LINE

           MOVE 'STATEMENT SUMMARY:'    TO WS-REPORT-LINE
           PERFORM WRITE-LINE

           MOVE '================================' TO WS-REPORT-LINE
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           PERFORM WRITE-LINE

      *    Opening balance = available balance + debits - credits
           IF NI-ACCT-AVAIL-BAL < 0
               MOVE 0 TO WS-OPENING-BAL
           ELSE
               MOVE HV-ACCT-AVAIL-BAL TO WS-OPENING-BAL
           END-IF
           ADD WS-TOTAL-DEBITS    TO WS-OPENING-BAL
           SUBTRACT WS-TOTAL-CREDITS FROM WS-OPENING-BAL

           MOVE WS-OPENING-BAL TO WS-AMOUNT-EDIT
           MOVE SPACES TO WS-REPORT-LINE
           STRING '  OPENING BALANCE:        '
                  DELIMITED BY SIZE
                  FUNCTION TRIM(WS-AMOUNT-EDIT) DELIMITED BY SIZE
               INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-LINE

           MOVE WS-TOTAL-CREDITS TO WS-AMOUNT-EDIT
           MOVE SPACES TO WS-REPORT-LINE
           STRING '  TOTAL CREDITS:          '
                  DELIMITED BY SIZE
                  FUNCTION TRIM(WS-AMOUNT-EDIT) DELIMITED BY SIZE
               INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-LINE

           MOVE WS-TOTAL-DEBITS TO WS-AMOUNT-EDIT
           MOVE SPACES TO WS-REPORT-LINE
           STRING '  TOTAL DEBITS:           '
                  DELIMITED BY SIZE
                  FUNCTION TRIM(WS-AMOUNT-EDIT) DELIMITED BY SIZE
               INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-LINE

      *    Closing balance = opening - debits + credits
           MOVE WS-OPENING-BAL TO WS-CLOSING-BAL
           SUBTRACT WS-TOTAL-DEBITS FROM WS-CLOSING-BAL
           ADD WS-TOTAL-CREDITS TO WS-CLOSING-BAL
           MOVE WS-CLOSING-BAL TO WS-AMOUNT-EDIT
           MOVE SPACES TO WS-REPORT-LINE
           STRING '  CLOSING BALANCE:        '
                  DELIMITED BY SIZE
                  FUNCTION TRIM(WS-AMOUNT-EDIT) DELIMITED BY SIZE
               INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           PERFORM WRITE-LINE

           IF NI-ACCT-AVAIL-BAL < 0
               MOVE 0 TO WS-CLOSING-BAL
           ELSE
               MOVE HV-ACCT-AVAIL-BAL TO WS-CLOSING-BAL
           END-IF
           MOVE WS-CLOSING-BAL TO WS-AMOUNT-EDIT
           MOVE SPACES TO WS-REPORT-LINE
           STRING '  AVAILABLE BALANCE:      '
                  DELIMITED BY SIZE
                  FUNCTION TRIM(WS-AMOUNT-EDIT) DELIMITED BY SIZE
               INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-LINE

           MOVE WS-TRANS-COUNT TO WS-TRANS-COUNT-EDIT
           MOVE SPACES TO WS-REPORT-LINE
           STRING '  TRANSACTION COUNT:      '
                  DELIMITED BY SIZE
                  FUNCTION TRIM(WS-TRANS-COUNT-EDIT) DELIMITED BY SIZE
               INTO WS-REPORT-LINE
           END-STRING
           PERFORM WRITE-LINE.


      *-----------------------------------------------------------------
      * Print statement footer  page eject after each account
      *-----------------------------------------------------------------
       PRINT-FOOTER.
           PERFORM CHECK-PAGE-BREAK

           MOVE SPACES TO WS-REPORT-LINE
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           STRING '*** END OF STATEMENT ***'
                  DELIMITED BY SIZE
               INTO WS-REPORT-LINE(55:24)
           END-STRING
           PERFORM WRITE-LINE

           MOVE SPACES TO WS-REPORT-LINE
           STRING 'Thank you for banking with Bank of Z'
                  DELIMITED BY SIZE
               INTO WS-REPORT-LINE(49:36)
           END-STRING
           PERFORM WRITE-LINE

      *    Force page break for next statement
           PERFORM WRITE-PAGE-BREAK
           MOVE 0 TO WS-LINE-COUNT.


      *-----------------------------------------------------------------
       CLOSE-FILES.
           IF WS-ACCT-CURSOR-OPEN = 'Y'
               EXEC SQL CLOSE ACCT-CURSOR END-EXEC
               MOVE 'N' TO WS-ACCT-CURSOR-OPEN
           END-IF
           IF WS-TRAN-CURSOR-OPEN = 'Y'
               EXEC SQL CLOSE TRAN-CURSOR END-EXEC
               MOVE 'N' TO WS-TRAN-CURSOR-OPEN
           END-IF

           EXEC SQL COMMIT WORK
           END-EXEC

           CLOSE SORTCODE-FILE
           CLOSE STMTRPT
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNK3STMT: CLOSE STMTRPT failed. Status='
                   WS-STMTRPT-STATUS
           END-IF.

