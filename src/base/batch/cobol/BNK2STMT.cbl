       CBL SQL
      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      ******************************************************************

       IDENTIFICATION DIVISION.
       PROGRAM-ID. BNK2STMT.
       AUTHOR.     IBM.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.

           SELECT SYSIN
               ASSIGN TO SYSIN
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL
               FILE STATUS  IS WS-SYSIN-STATUS.

           SELECT STMTRPT
               ASSIGN TO STMTRPT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL
               FILE STATUS  IS WS-STMTRPT-STATUS.

       DATA DIVISION.
       FILE SECTION.

       FD  SYSIN
           RECORDING MODE F
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 80 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  SYSIN-RECORD               PIC X(80).

       FD  STMTRPT
           RECORDING MODE F
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 80 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  STMTRPT-RECORD             PIC X(80).

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
      * Host variables - ACCOUNT cursor
      *-----------------------------------------------------------------
       01  HOST-ACCOUNT-ROW.
           03 HV-ACC-NUMBER           PIC X(8).
           03 HV-ACC-TYPE             PIC X(8).
           03 HV-ACC-INT-RATE         PIC S9(4)V99 COMP-3.
           03 HV-ACC-OPENED           PIC X(10).
           03 HV-ACC-OVERDRAFT-LIM    PIC S9(9) COMP.
           03 HV-ACC-AVAIL-BAL        PIC S9(10)V99 COMP-3.
           03 HV-ACC-ACTUAL-BAL       PIC S9(10)V99 COMP-3.

      *-----------------------------------------------------------------
      * Null indicators for nullable COMP-3 account columns
      *-----------------------------------------------------------------
       01  WS-NULL-INDICATORS.
           03 NI-INT-RATE             PIC S9(4) COMP VALUE 0.
           03 NI-AVAIL-BAL            PIC S9(4) COMP VALUE 0.
           03 NI-ACTUAL-BAL           PIC S9(4) COMP VALUE 0.

      *-----------------------------------------------------------------
      * SQL Communications Area
      *-----------------------------------------------------------------
           EXEC SQL
               INCLUDE SQLCA
           END-EXEC.

      *-----------------------------------------------------------------
      * Cursor - all accounts for the given customer
      *-----------------------------------------------------------------
           EXEC SQL DECLARE ACCT-CURSOR CURSOR FOR
               SELECT ACCOUNT_NUMBER,
                      ACCOUNT_TYPE,
                      ACCOUNT_INTEREST_RATE,
                      ACCOUNT_OPENED,
                      ACCOUNT_OVERDRAFT_LIMIT,
                      ACCOUNT_AVAILABLE_BALANCE,
                      ACCOUNT_ACTUAL_BALANCE
               FROM   BANKZ.ACCOUNT
               WHERE  ACCOUNT_CUSTOMER_NUMBER = :HV-CUST-NUMBER
               ORDER BY ACCOUNT_NUMBER
               FOR FETCH ONLY
           END-EXEC.

      *-----------------------------------------------------------------
      * SYSIN input record
      *-----------------------------------------------------------------
       01  WS-INPUT-RECORD.
           03 WS-INPUT-CUSTNO         PIC X(10).
           03 FILLER                  PIC X(70).

      *-----------------------------------------------------------------
      * File status fields
      *-----------------------------------------------------------------
       01  WS-SYSIN-STATUS            PIC XX VALUE '00'.
       01  WS-STMTRPT-STATUS          PIC XX VALUE '00'.

      *-----------------------------------------------------------------
      * SQLCODE display
      *-----------------------------------------------------------------
       01  SQLCODE-DISPLAY            PIC S9(8) DISPLAY
               SIGN LEADING SEPARATE.

      *-----------------------------------------------------------------
      * Program return code and flags
      *-----------------------------------------------------------------
       01  WS-RETURN-CODE             PIC S9(4) COMP VALUE 0.
       01  WS-CURSOR-OPEN             PIC X VALUE 'N'.
       01  WS-CURSOR-EOF              PIC X VALUE 'N'.
       01  WS-EOF-SYSIN               PIC X VALUE 'N'.

      *-----------------------------------------------------------------
      * Work field for messages
      *-----------------------------------------------------------------
       01  WS-MSG                     PIC X(80).

      *-----------------------------------------------------------------
      * Date decomposition (CUSTOMER_DATE_OF_BIRTH is INTEGER YYYYMMDD)
      *-----------------------------------------------------------------
       01  WS-DATE-INT                PIC S9(9) COMP.
       01  WS-DATE-YEAR               PIC 9(4).
       01  WS-DATE-MONTH              PIC 99.
       01  WS-DATE-DAY                PIC 99.
       01  WS-DATE-DISPLAY            PIC X(10).
       01  WS-DATE-GRP REDEFINES WS-DATE-DISPLAY.
           03 WS-DD                   PIC XX.
           03 FILLER                  PIC X.
           03 WS-MM                   PIC XX.
           03 FILLER                  PIC X.
           03 WS-YYYY                 PIC X(4).

      *-----------------------------------------------------------------
      * Date reformatting overlay (DB2 DATE is YYYY-MM-DD / 10 chars)
      *-----------------------------------------------------------------
       01  DB2-DATE-REFORMAT.
           03 DB2-DATE-REF-YR         PIC 9(4).
           03 FILLER                  PIC X.
           03 DB2-DATE-REF-MNTH       PIC 99.
           03 FILLER                  PIC X.
           03 DB2-DATE-REF-DAY        PIC 99.

      *-----------------------------------------------------------------
      * Current date
      *-----------------------------------------------------------------
       01  WS-CURRENT-DATE            PIC X(21).
       01  WS-CURR-DATE-GRP
               REDEFINES WS-CURRENT-DATE.
           03 WS-CURR-YYYY            PIC 9(4).
           03 WS-CURR-MM              PIC 99.
           03 WS-CURR-DD              PIC 99.
           03 FILLER                  PIC X(13).

      *================================================================
      * Report lines - 80 bytes each
      *================================================================

       01  WS-TITLE-LINE.
           03 FILLER  PIC X(40)
               VALUE 'BANK OF Z - Detailed Customer Statement '.
           03 FILLER  PIC X(40) VALUE SPACES.

       01  WS-GENON-LINE.
           03 FILLER       PIC X(14) VALUE 'GENERATED ON: '.
           03 WS-GL-DATE   PIC X(10).
           03 FILLER       PIC X(56) VALUE SPACES.

       01  WS-SEPARATOR-LINE          PIC X(80) VALUE ALL '-'.

       01  WS-CUST-HDR-LINE.
           03 FILLER  PIC X(30)
               VALUE '*** CUSTOMER INFORMATION ***  '.
           03 FILLER  PIC X(50) VALUE SPACES.

       01  WS-ACCT-HDR-LINE.
           03 FILLER  PIC X(30)
               VALUE '*** ACCOUNT INFORMATION ***   '.
           03 FILLER  PIC X(50) VALUE SPACES.

      *-----------------------------------------------------------------
      * Customer detail lines (label : value format)
      *-----------------------------------------------------------------
       01  WS-CUST-LINE.
           03 WS-CL-LABEL             PIC X(8).
           03 FILLER                  PIC X(2) VALUE ': '.
           03 WS-CL-VALUE             PIC X(70).

      *-----------------------------------------------------------------
      * Account column heading
      *-----------------------------------------------------------------
      * Account column heading and detail line
      * Layout: 8+1+8+1+5+1+10+1+9+1+14+1+14+1+4 = 80
      *-----------------------------------------------------------------
       01  WS-ACCT-COL-HDR.
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
           03 FILLER  PIC X(4)  VALUE SPACES.

      *-----------------------------------------------------------------
      * Account detail line
      * Layout: 8+1+8+1+5+1+10+1+9+1+14+1+14+1+4 = 80 - (1 space removed)
      *   PIC +Z(10)9.99 = 14 chars each
      *   8+1+8+1+5+1+10+1+9+1+14+1+14+5 = 80
      *-----------------------------------------------------------------
       01  WS-ACCT-LINE.
           03 WS-AL-ACC-NO    PIC X(8).
           03 FILLER          PIC X     VALUE SPACE.
           03 WS-AL-TYPE      PIC X(8).
           03 FILLER          PIC X     VALUE SPACE.
           03 WS-AL-RATE      PIC Z9.99.
           03 FILLER          PIC X     VALUE SPACE.
           03 WS-AL-OPENED    PIC X(10).
           03 FILLER          PIC X     VALUE SPACE.
           03 WS-AL-OVERDRAFT PIC Z(8)9.
           03 FILLER          PIC X     VALUE SPACE.
           03 WS-AL-AVAIL     PIC +Z(10)9.99.
           03 FILLER          PIC X     VALUE SPACE.
           03 WS-AL-ACTUAL    PIC +Z(10)9.99.
           03 FILLER          PIC X(5)  VALUE SPACES.

      ******************************************************************
       PROCEDURE DIVISION.
      ******************************************************************

      *-----------------------------------------------------------------
       MAIN-CONTROL.
           PERFORM OPEN-FILES
           IF WS-RETURN-CODE = 0
               PERFORM READ-SYSIN
           END-IF
           IF WS-RETURN-CODE = 0
               PERFORM WRITE-HEADER
           END-IF
           IF WS-RETURN-CODE = 0
               PERFORM QUERY-CUSTOMER
           END-IF
           IF WS-RETURN-CODE = 0
               PERFORM WRITE-CUSTOMER-SECTION
               PERFORM OPEN-ACCOUNT-CURSOR
           END-IF
           IF WS-RETURN-CODE = 0
               PERFORM WRITE-ACCOUNT-SECTION-HDR
               PERFORM UNTIL WS-CURSOR-EOF = 'Y'
                   PERFORM FETCH-ONE-ACCOUNT
               END-PERFORM
           END-IF
           IF WS-CURSOR-OPEN = 'Y'
               EXEC SQL CLOSE ACCT-CURSOR END-EXEC
               MOVE 'N' TO WS-CURSOR-OPEN
           END-IF
           IF WS-RETURN-CODE = 0 OR WS-RETURN-CODE = 4
               PERFORM WRITE-FINAL-SEPARATOR
           END-IF
           PERFORM CLOSE-FILES
           MOVE WS-RETURN-CODE TO RETURN-CODE
           STOP RUN.

      *-----------------------------------------------------------------
       OPEN-FILES.
           OPEN INPUT SYSIN
           IF WS-SYSIN-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: OPEN SYSIN failed. Status='
                   WS-SYSIN-STATUS
               MOVE 16 TO WS-RETURN-CODE
               GO TO OF-EXIT
           END-IF
           OPEN OUTPUT STMTRPT
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: OPEN STMTRPT failed. Status='
                   WS-STMTRPT-STATUS
               MOVE 16 TO WS-RETURN-CODE
           END-IF.

       OF-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       READ-SYSIN.
           READ SYSIN INTO WS-INPUT-RECORD
               AT END MOVE 'Y' TO WS-EOF-SYSIN
           END-READ
           IF WS-SYSIN-STATUS NOT = '00'
           AND WS-SYSIN-STATUS NOT = '10'
               DISPLAY 'BNKCSTMT: READ SYSIN failed. Status='
                   WS-SYSIN-STATUS
               MOVE 8 TO WS-RETURN-CODE
               GO TO RS-EXIT
           END-IF
           IF WS-EOF-SYSIN = 'Y'
               DISPLAY 'BNKCSTMT: No input record in SYSIN'
               MOVE 8 TO WS-RETURN-CODE
               GO TO RS-EXIT
           END-IF
           IF WS-INPUT-CUSTNO IS NOT NUMERIC
               DISPLAY 'BNKCSTMT: Non-numeric customer number: ['
                   WS-INPUT-CUSTNO ']'
               MOVE 8 TO WS-RETURN-CODE
               GO TO RS-EXIT
           END-IF
           DISPLAY 'BNKCSTMT: Generating statement for customer: '
               WS-INPUT-CUSTNO.

       RS-EXIT.
           EXIT.

      *-----------------------------------------------------------------
      * Write title + generated-on date + separator
      *-----------------------------------------------------------------
       WRITE-HEADER.
           MOVE WS-TITLE-LINE    TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: WRITE title failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WH-EXIT
           END-IF
           MOVE FUNCTION CURRENT-DATE TO WS-CURRENT-DATE
           MOVE WS-CURR-DD   TO WS-DD
           MOVE '/'           TO WS-DATE-DISPLAY(3:1)
           MOVE WS-CURR-MM   TO WS-MM
           MOVE '/'           TO WS-DATE-DISPLAY(6:1)
           MOVE WS-CURR-YYYY TO WS-YYYY
           MOVE WS-DATE-DISPLAY TO WS-GL-DATE
           MOVE WS-GENON-LINE  TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: WRITE date line failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WH-EXIT
           END-IF
           MOVE WS-SEPARATOR-LINE TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: WRITE separator failed'
               MOVE 16 TO WS-RETURN-CODE
           END-IF.

       WH-EXIT.
           EXIT.

      *-----------------------------------------------------------------
      * SELECT INTO for the requested customer
      *-----------------------------------------------------------------
       QUERY-CUSTOMER.
           MOVE WS-INPUT-CUSTNO TO HV-CUST-NUMBER

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
                     :HV-CUST-TITLE,
                     :HV-CUST-FIRST-NAME,
                     :HV-CUST-LAST-NAME,
                     :HV-CUST-DOB,
                     :HV-CUST-PHONE,
                     :HV-CUST-ADDR1,
                     :HV-CUST-ADDR2,
                     :HV-CUST-CITY,
                     :HV-CUST-POSTCODE,
                     :HV-CUST-COUNTRY,
                     :HV-CUST-STATUS,
                     :HV-CUST-CREATE-DATE,
                     :HV-CUST-CREDIT-SCORE,
                     :HV-CUST-CS-REVIEW-DATE
               FROM  BANKZ.CUSTOMER
               WHERE CUSTOMER_NUMBER = :HV-CUST-NUMBER
           END-EXEC

           EVALUATE SQLCODE
               WHEN 0
                   DISPLAY 'BNKCSTMT: Customer found: ' HV-CUST-NUMBER
               WHEN +100
                   DISPLAY 'BNKCSTMT: Customer not found: '
                       WS-INPUT-CUSTNO
                   MOVE 4 TO WS-RETURN-CODE
               WHEN OTHER
                   MOVE SQLCODE TO SQLCODE-DISPLAY
                   STRING 'BNKCSTMT: SELECT failed. SQLCODE='
                       DELIMITED BY SIZE
                       SQLCODE-DISPLAY DELIMITED BY SIZE
                       INTO WS-MSG
                   END-STRING
                   DISPLAY WS-MSG
                   MOVE 12 TO WS-RETURN-CODE
           END-EVALUATE.

       QC-EXIT.
           EXIT.

      *-----------------------------------------------------------------
      * Write *** CUSTOMER INFORMATION *** section
      *-----------------------------------------------------------------
       WRITE-CUSTOMER-SECTION.
           MOVE WS-CUST-HDR-LINE  TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: WRITE cust hdr failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WCS-EXIT
           END-IF

      *    CUST-NO line
           MOVE 'CUST-NO'  TO WS-CL-LABEL
           MOVE HV-CUST-NUMBER TO WS-CL-VALUE
           MOVE WS-CUST-LINE TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: WRITE CUST-NO failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WCS-EXIT
           END-IF

      *    NAME line: TITLE FIRST-NAME LAST-NAME
      *    Use TRIM to preserve multi-word names
           MOVE 'NAME'     TO WS-CL-LABEL
           MOVE SPACES     TO WS-CL-VALUE
           STRING FUNCTION TRIM(HV-CUST-TITLE)
                      DELIMITED BY SIZE
                  ' ' DELIMITED BY SIZE
                  FUNCTION TRIM(HV-CUST-FIRST-NAME)
                      DELIMITED BY SIZE
                  ' ' DELIMITED BY SIZE
                  FUNCTION TRIM(HV-CUST-LAST-NAME)
                      DELIMITED BY SIZE
               INTO WS-CL-VALUE
           END-STRING
           MOVE WS-CUST-LINE TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: WRITE NAME failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WCS-EXIT
           END-IF

      *    DOB line: INTEGER YYYYMMDD -> DD/MM/YYYY
           MOVE 'DOB'      TO WS-CL-LABEL
           MOVE HV-CUST-DOB TO WS-DATE-INT
           COMPUTE WS-DATE-YEAR  = WS-DATE-INT / 10000
           COMPUTE WS-DATE-MONTH =
               FUNCTION MOD(WS-DATE-INT / 100, 100)
           COMPUTE WS-DATE-DAY   =
               FUNCTION MOD(WS-DATE-INT, 100)
           MOVE WS-DATE-DAY   TO WS-DD
           MOVE '/'           TO WS-DATE-DISPLAY(3:1)
           MOVE WS-DATE-MONTH TO WS-MM
           MOVE '/'           TO WS-DATE-DISPLAY(6:1)
           MOVE WS-DATE-YEAR  TO WS-YYYY
           MOVE WS-DATE-DISPLAY TO WS-CL-VALUE
           MOVE WS-CUST-LINE TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: WRITE DOB failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WCS-EXIT
           END-IF

      *    PHONE
           MOVE 'PHONE'    TO WS-CL-LABEL
           IF HV-CUST-PHONE = SPACES
               MOVE 'N/A' TO WS-CL-VALUE
           ELSE
               MOVE HV-CUST-PHONE TO WS-CL-VALUE
           END-IF
           MOVE WS-CUST-LINE TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: WRITE PHONE failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WCS-EXIT
           END-IF

      *    ADDR1
           MOVE 'ADDR1'    TO WS-CL-LABEL
           MOVE HV-CUST-ADDR1 TO WS-CL-VALUE
           MOVE WS-CUST-LINE TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: WRITE ADDR1 failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WCS-EXIT
           END-IF

      *    ADDR2
           MOVE 'ADDR2'    TO WS-CL-LABEL
           MOVE HV-CUST-ADDR2 TO WS-CL-VALUE
           MOVE WS-CUST-LINE TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: WRITE ADDR2 failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WCS-EXIT
           END-IF

      *    CITY
           MOVE 'CITY'     TO WS-CL-LABEL
           MOVE HV-CUST-CITY TO WS-CL-VALUE
           MOVE WS-CUST-LINE TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: WRITE CITY failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WCS-EXIT
           END-IF

      *    POSTCODE
           MOVE 'POST'     TO WS-CL-LABEL
           MOVE HV-CUST-POSTCODE TO WS-CL-VALUE
           MOVE WS-CUST-LINE TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: WRITE POST failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WCS-EXIT
           END-IF

      *    COUNTRY
           MOVE 'CNTRY'    TO WS-CL-LABEL
           MOVE HV-CUST-COUNTRY TO WS-CL-VALUE
           MOVE WS-CUST-LINE TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: WRITE CNTRY failed'
               MOVE 16 TO WS-RETURN-CODE
           END-IF.

       WCS-EXIT.
           EXIT.

      *-----------------------------------------------------------------
      * Open account cursor for this customer
      *-----------------------------------------------------------------
       OPEN-ACCOUNT-CURSOR.
           EXEC SQL OPEN ACCT-CURSOR
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE SQLCODE TO SQLCODE-DISPLAY
               STRING 'BNKCSTMT: OPEN ACCT-CURSOR failed. SQLCODE='
                   DELIMITED BY SIZE
                   SQLCODE-DISPLAY DELIMITED BY SIZE
                   INTO WS-MSG
               END-STRING
               DISPLAY WS-MSG
               MOVE 12 TO WS-RETURN-CODE
               GO TO OAC-EXIT
           END-IF
           MOVE 'Y' TO WS-CURSOR-OPEN.

       OAC-EXIT.
           EXIT.

      *-----------------------------------------------------------------
      * Write separator + *** ACCOUNT INFORMATION *** + column heading
      *-----------------------------------------------------------------
       WRITE-ACCOUNT-SECTION-HDR.
           MOVE WS-SEPARATOR-LINE TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: WRITE acct sep failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WASH-EXIT
           END-IF
           MOVE WS-ACCT-HDR-LINE  TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: WRITE acct hdr failed'
               MOVE 16 TO WS-RETURN-CODE
               GO TO WASH-EXIT
           END-IF
           MOVE WS-ACCT-COL-HDR   TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: WRITE col hdr failed'
               MOVE 16 TO WS-RETURN-CODE
           END-IF.

       WASH-EXIT.
           EXIT.

      *-----------------------------------------------------------------
      * Fetch one account row and write detail line
      *-----------------------------------------------------------------
       FETCH-ONE-ACCOUNT.
           EXEC SQL FETCH FROM ACCT-CURSOR
               INTO :HV-ACC-NUMBER,
                    :HV-ACC-TYPE,
                    :HV-ACC-INT-RATE   :NI-INT-RATE,
                    :HV-ACC-OPENED,
                    :HV-ACC-OVERDRAFT-LIM,
                    :HV-ACC-AVAIL-BAL  :NI-AVAIL-BAL,
                    :HV-ACC-ACTUAL-BAL :NI-ACTUAL-BAL
           END-EXEC

           EVALUATE SQLCODE
               WHEN 0
                   PERFORM FORMAT-ACCOUNT-LINE
                   MOVE WS-ACCT-LINE TO STMTRPT-RECORD
                   WRITE STMTRPT-RECORD
                   IF WS-STMTRPT-STATUS NOT = '00'
                       DISPLAY 'BNKCSTMT: WRITE acct detail failed'
                       MOVE 16 TO WS-RETURN-CODE
                       MOVE 'Y' TO WS-CURSOR-EOF
                   END-IF
               WHEN +100
                   MOVE 'Y' TO WS-CURSOR-EOF
               WHEN OTHER
                   MOVE SQLCODE TO SQLCODE-DISPLAY
                   STRING 'BNKCSTMT: FETCH failed. SQLCODE='
                       DELIMITED BY SIZE
                       SQLCODE-DISPLAY DELIMITED BY SIZE
                       INTO WS-MSG
                   END-STRING
                   DISPLAY WS-MSG
                   MOVE 12 TO WS-RETURN-CODE
                   MOVE 'Y' TO WS-CURSOR-EOF
           END-EVALUATE.

       FOA-EXIT.
           EXIT.

      *-----------------------------------------------------------------
      * Format one account detail line
      *-----------------------------------------------------------------
       FORMAT-ACCOUNT-LINE.
           MOVE HV-ACC-NUMBER        TO WS-AL-ACC-NO
           MOVE HV-ACC-TYPE          TO WS-AL-TYPE
           IF NI-INT-RATE < 0
               MOVE ZEROS             TO WS-AL-RATE
           ELSE
               MOVE HV-ACC-INT-RATE   TO WS-AL-RATE
           END-IF
      *    Reformat ACCOUNT_OPENED YYYY-MM-DD -> DD/MM/YYYY
           MOVE HV-ACC-OPENED        TO DB2-DATE-REFORMAT
           MOVE '/' TO WS-DATE-DISPLAY(3:1)
           MOVE '/' TO WS-DATE-DISPLAY(6:1)
           MOVE DB2-DATE-REF-DAY     TO WS-DD
           MOVE DB2-DATE-REF-MNTH    TO WS-MM
           MOVE DB2-DATE-REF-YR      TO WS-YYYY
           MOVE WS-DATE-DISPLAY      TO WS-AL-OPENED
           MOVE HV-ACC-OVERDRAFT-LIM TO WS-AL-OVERDRAFT
           IF NI-AVAIL-BAL < 0
               MOVE ZEROS             TO WS-AL-AVAIL
           ELSE
               MOVE HV-ACC-AVAIL-BAL  TO WS-AL-AVAIL
           END-IF
           IF NI-ACTUAL-BAL < 0
               MOVE ZEROS             TO WS-AL-ACTUAL
           ELSE
               MOVE HV-ACC-ACTUAL-BAL TO WS-AL-ACTUAL
           END-IF.

       FAL-EXIT.
           EXIT.

      *-----------------------------------------------------------------
      * Write final separator line
      *-----------------------------------------------------------------
       WRITE-FINAL-SEPARATOR.
           MOVE WS-SEPARATOR-LINE TO STMTRPT-RECORD
           WRITE STMTRPT-RECORD
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: WRITE final separator failed'
               MOVE 16 TO WS-RETURN-CODE
           END-IF.

       WFS-EXIT.
           EXIT.

      *-----------------------------------------------------------------
       CLOSE-FILES.
           CLOSE SYSIN.
           CLOSE STMTRPT
           IF WS-STMTRPT-STATUS NOT = '00'
               DISPLAY 'BNKCSTMT: CLOSE STMTRPT failed. Status='
                   WS-STMTRPT-STATUS
           END-IF.

       CF-EXIT.
           EXIT.
