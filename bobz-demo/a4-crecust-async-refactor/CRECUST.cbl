       CBL CICS('SP,EDF')
       CBL SQL
      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      ******************************************************************
      ******************************************************************
      * This program takes customer information from the BMS
      * application (name, address and DOB) and should get the SORTCODE,
      * determine which datastore to use (VSAM or DB2), then enqueue
      * the counter for CUSTOMER, increment the counter and get
      * that number.
      *
      * It then delegates the credit check to CRCCVERI (Credit Check
      * Verification) via EXEC CICS LINK. CRCCVERI handles the async
      * dispatch to credit agency programs, the 3-second wait, and
      * score aggregation. To switch the credit check to an API call
      * in future, only CRCCVERI needs to change.
      *
      * If no data is returned from the credit check, then set the
      * credit score to 0 and mark the credit score review date as
      * today (so another attempt at credit scoring will be carried
      * out later).
      *
      * Next, attempt to update the CUSTOMER datastore & if that is
      * successful, write a rec to the PROCTRAN datastore.
      *
      * If all of that works, then DEQUEUE the named counter
      * and return the SORTCODE and CUSTOMER number.
      *
      * If for any reason the write to the CUSTOMER or PROCTRAN
      * datastore is unsuccessful, then we need to decrement the Named
      * Counter (restoring it to the start position) and DEQUEUE the
      * Named Counter.
      *
      ******************************************************************

       IDENTIFICATION DIVISION.
       PROGRAM-ID. CRECUST.
       AUTHOR. Jon Collett.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      * SOURCE-COMPUTER.  IBM-370 WITH DEBUGGING MODE.
       SOURCE-COMPUTER.  IBM-370.
       OBJECT-COMPUTER.  IBM-370.

       INPUT-OUTPUT SECTION.

       DATA DIVISION.
       FILE SECTION.

       WORKING-STORAGE SECTION.


       COPY SORTCODE.



      * CUSTOMER DB2 copybook
           EXEC SQL
             INCLUDE CUSTDB2
             END-EXEC.

      * CUSTOMER host variables for DB2
       01 HOST-CUSTOMER-ROW.
          03 HV-CUSTOMER-EYECATCHER     PIC X(4).
          03 HV-CUSTOMER-SORTCODE       PIC X(6).
          03 HV-CUSTOMER-NUMBER         PIC X(10).
          03 HV-CUSTOMER-TITLE          PIC X(10).
          03 HV-CUSTOMER-FIRST-NAME     PIC X(50).
          03 HV-CUSTOMER-LAST-NAME      PIC X(50).
          03 HV-CUSTOMER-DOB            PIC S9(9) COMP.
          03 HV-CUSTOMER-PHONE          PIC X(20).
          03 HV-CUSTOMER-ADDR-LINE1     PIC X(50).
          03 HV-CUSTOMER-ADDR-LINE2     PIC X(50).
          03 HV-CUSTOMER-CITY           PIC X(50).
          03 HV-CUSTOMER-POSTCODE       PIC X(10).
          03 HV-CUSTOMER-COUNTRY        PIC X(50).
          03 HV-CUSTOMER-STATUS         PIC X(10).
          03 HV-CUSTOMER-CREATE-DATE    PIC S9(9) COMP.
          03 HV-CUSTOMER-CREDIT-SCORE   PIC S9(4) COMP.
          03 HV-CUSTOMER-CS-REVIEW-DATE PIC S9(9) COMP.

      * PROCTRAN DB2 copybook
           EXEC SQL
             INCLUDE PROCDB2
           END-EXEC.

      * PROCTRAN host variables for DB2
       01 HOST-PROCTRAN-ROW.
          03 HV-PROCTRAN-EYECATCHER     PIC X(4).
          03 HV-PROCTRAN-SORT-CODE      PIC X(6).
          03 HV-PROCTRAN-ACC-NUMBER     PIC X(8).
          03 HV-PROCTRAN-DATE           PIC X(10).
          03 HV-PROCTRAN-TIME           PIC X(6).
          03 HV-PROCTRAN-REF            PIC X(12).
          03 HV-PROCTRAN-TYPE           PIC X(3).
          03 HV-PROCTRAN-DESC           PIC X(40).
          03 HV-PROCTRAN-AMOUNT         PIC S9(10)V99 COMP-3.

      * Get the CONTROL table
           EXEC SQL
              INCLUDE CONTDB2
           END-EXEC.

      * CONTROL Host variables for DB2
       01 HOST-CONTROL-ROW.
          03 HV-CONTROL-NAME            PIC X(32).
          03 HV-CONTROL-VALUE-NUM       PIC S9(9) COMP.
          03 HV-CONTROL-VALUE-STR       PIC X(32).

      * Pull in the SQL COMMAREA
           EXEC SQL
          INCLUDE SQLCA
           END-EXEC.

       01 PROCTRAN-AREA.
          COPY PROCTRAN.

       01 PROCTRAN-RIDFLD               PIC S9(8) COMP.

       01 WS-CICS-WORK-AREA.
          05 WS-CICS-RESP               PIC S9(8) COMP.
          05 WS-CICS-RESP2              PIC S9(8) COMP.

       01 WS-CUSTOMER-NO-NUM            PIC 9(10).

       01 WS-TIME-DATA.
          03 WS-TIME-NOW                PIC 9(6).
          03 WS-TIME-NOW-GRP REDEFINES WS-TIME-NOW.
             05 WS-TIME-NOW-GRP-HH      PIC 99.
             05 WS-TIME-NOW-GRP-MM      PIC 99.
             05 WS-TIME-NOW-GRP-SS      PIC 99.

       01 WS-ABEND-PGM                  PIC X(8)      VALUE 'ABNDPROC'.
       01 ABNDINFO-REC.
           COPY ABNDINFO.

       LOCAL-STORAGE SECTION.
       01 FILE-RETRY                    PIC 999.
       01 WS-EXIT-RETRY-LOOP            PIC X         VALUE ' '.

       01 OUTPUT-DATA.
           COPY CUSTOMER.

       01 RETURN-DATA.
          03 RETURN-DATA-EYECATCHER     PIC X(4).
          03 RETURN-DATA-NUMBER         PIC 9(10) DISPLAY.
          03 RETURN-DATA-NAME           PIC X(60).
          03 RETURN-DATA-ADDRESS        PIC X(160).
          03 RETURN-DATA-DATE-OF-BIRTH  PIC 9(8).


       01 CUSTOMER-KY.
          03 REQUIRED-SORT-CODE         PIC 9(6)      VALUE 0.
          03 REQUIRED-CUST-NUMBER       PIC 9(10)     VALUE 0.

       01 RANDOM-CUSTOMER               PIC 9(10)     VALUE 0.
       01 HIGHEST-CUST-NUMBER           PIC 9(10)     VALUE 0.

       01 EXIT-VSAM-READ                PIC X         VALUE 'N'.
       01 EXIT-DB2-READ                 PIC X         VALUE 'N'.

       01 WS-V-RETRIED                  PIC X         VALUE 'N'.
       01 WS-D-RETRIED                  PIC X         VALUE 'N'.

       01 SQLCODE-DISPLAY               PIC S9(8) DISPLAY
             SIGN LEADING SEPARATE.


      *
      * CUSTOMER NCS definitions
      *
       01 NCS-CUST-NO-STUFF.
          03 NCS-CUST-NO-NAME.
             05 NCS-CUST-NO-ACT-NAME    PIC X(9)
                                                      VALUE 'BANKZCUST'.
             05 NCS-CUST-NO-TEST-SORT   PIC X(6)
                                                      VALUE '      '.
             05 NCS-CUST-NO-FILL        PIC XX
                                                      VALUE '  '.

          03 NCS-CUST-NO-INC            PIC 9(16) COMP
                                                      VALUE 0.
          03 NCS-CUST-NO-VALUE          PIC 9(16) COMP
                                                      VALUE 0.

          03 NCS-CUST-NO-RESP           PIC XX        VALUE '00'.

       01 WS-DISP-CUST-NO-VAL           PIC S9(18) DISPLAY.

       01 WS-CUST-REC-LEN               PIC S9(4) COMP
                                                      VALUE 0.

       01 NCS-UPDATED                   PIC X         VALUE 'N'.

       01 WS-U-TIME                     PIC S9(15) COMP-3.
       01 WS-ORIG-DATE                  PIC X(10).
       01 WS-ORIG-DATE-GRP REDEFINES WS-ORIG-DATE.
          03 WS-ORIG-DATE-DD            PIC 99.
          03 FILLER                     PIC X.
          03 WS-ORIG-DATE-MM            PIC 99.
          03 FILLER                     PIC X.
          03 WS-ORIG-DATE-YYYY          PIC 9999.

       01 WS-ORIG-DATE-GRP-X.
          03 WS-ORIG-DATE-DD-X          PIC XX.
          03 FILLER                     PIC X         VALUE '.'.
          03 WS-ORIG-DATE-MM-X          PIC XX.
          03 FILLER                     PIC X         VALUE '.'.
          03 WS-ORIG-DATE-YYYY-X        PIC X(4).

       01 STORED-SORTCODE               PIC X(6)      VALUE SPACES.
       01 STORED-CUSTNO                 PIC X(10)     VALUE SPACES.
       01 STORED-NAME                   PIC X(60)     VALUE SPACES.
       01 STORED-DOB                    PIC X(10)     VALUE SPACES.

       01 WS-EIBTASKN12                 PIC 9(12)     VALUE 0.
       77 PROCTRAN-RETRY                PIC 999.

       01 CUSTOMER-KY2.
          03 REQUIRED-SORT-CODE2        PIC 9(6)      VALUE 0.
          03 REQUIRED-CUST-NUMBER2      PIC 9(10)     VALUE 0.

       01 CUSTOMER-KY2-BYTES REDEFINES CUSTOMER-KY2
                                        PIC X(16).

       01 HIGHEST-CUST-NUMBER           PIC 9(10)     VALUE 0.

      *
      * WS-CREDIT-CHECK-ERROR is set by CREDIT-CHECK and tested in P010
      *
       01 WS-CREDIT-CHECK-ERROR         PIC X         VALUE 'N'.

      *
      * COMMAREA for CRCCVERI (credit check delegation program)
      *
       01 WS-CRCCVERI-AREA.
           COPY CRCCVERI.

       01 WS-CICSTS-LEVEL-DATA.
          03 WS-CICSTSLEVEL             PIC X(6).
          03 WS-CICSTS-LEVEL-NUM-GRP REDEFINES WS-CICSTSLEVEL.
             05 WS-CICSTS-LEVEL-NUM-VV  PIC 99.
             05 WS-CICSTS-LEVEL-NUM-RR  PIC 99.
             05 WS-CICSTS-LEVEL-NUM-MM  PIC 99.

       01 STORM-DRAIN-CONDITION         PIC X(20).

       01 WS-DATE-OF-BIRTH-ERROR        PIC X         VALUE 'N'.
       01 WS-DATE-OF-BIRTH-LILLIAN      PIC S9(9) BINARY.

       01 DATE-OF-BIRTH-FORMAT.
          03 DATE-OF-BIRTH-FORMAT-LENGTH
                                        PIC S9(4) BINARY
                                                      VALUE 10.
          03 DATE-OF-BIRTH-FORMAT-TEXT  PIC X(8)      VALUE 'YYYYMMDD'.

       01 DATE-OF-BIRTH-FOR-CEEDAYS.
          03 DATE-OF-BIRTH-CEEDAYS-LENGTH
                                        PIC S9(4) BINARY
                                                      VALUE 10.
          03 CEEDAYS-YEAR               PIC 9999.
          03 CEEDAYS-MONTH              PIC 99.
          03 CEEDAYS-DAY                PIC 99.

       01 FC.
          02 CONDITION-TOKEN-VALUE.
           COPY  CEEIGZCT.
             03 CASE-1-CONDITION-ID.
                04 SEVERITY             PIC S9(4) BINARY.
                04 MSG-NO               PIC S9(4) BINARY.
             03 CASE-2-CONDITION-ID
                   REDEFINES CASE-1-CONDITION-ID.
                04 CLASS-CODE           PIC S9(4) BINARY.
                04 CAUSE-CODE           PIC S9(4) BINARY.
             03 CASE-SEV-CTL            PIC X.
             03 FACILITY-ID             PIC XXX.
          02 I-S-INFO                   PIC S9(9) BINARY.

       01 WS-TODAY-LILLIAN              PIC S9(9) BINARY.
       01 WS-TODAY-SECONDS COMP-2.
       01 WS-TODAY-GREGORIAN.
          03 WS-TODAY-G-YEAR            PIC 9(4).
          03 WS-TODAY-G-MONTH           PIC 9(2).
          03 WS-TODAY-G-DAY             PIC 9(2).
          03 WS-TODAY-G-HOURS           PIC 9(2).
          03 WS-TODAY-G-MINUTES         PIC 9(2).
          03 WS-TODAY-G-SECONDS         PIC 9(2).
          03 WS-TODAY-G-MILLISECONDS    PIC 999.

       01 CHRDATE.
          02 VSTRING-LENGTH             PIC S9(4) BINARY.
          02 VSTRING-TEXT.
             03 VSTRING-CHAR            PIC X
                   OCCURS 0 TO 256 TIMES
                   DEPENDING ON VSTRING-LENGTH
                   OF CHRDATE.
       01 PICSTR.
          02 VSTRING-LENGTH             PIC S9(4) BINARY.
          02 VSTRING-TEXT.
             03 VSTRING-CHAR            PIC X
                   OCCURS 0 TO 256 TIMES
                   DEPENDING ON VSTRING-LENGTH
                   OF PICSTR.
       01 LILIAN                        PIC S9(9) BINARY.

       01 WS-CUSTOMER-AGE               PIC S9999.

       01 CUSTOMER-CONTROL.
           COPY CUSTCTRL.

       01 WS-UNSTR-TITLE                PIC X(9)      VALUE ' '.
       01 WS-FULL-NAME                  PIC X(110)    VALUE SPACES.
       01 WS-TITLE-VALID                PIC X.


       LINKAGE SECTION.
       01 DFHCOMMAREA.
           COPY CRECUST.


       PROCEDURE DIVISION USING DFHCOMMAREA.
       PREMIERE SECTION.
       P010.

      *
      *    You can change the customer's name, but the title must
      *    be a valid one. Check that here
      *
           MOVE ' ' TO WS-TITLE-VALID.

           EVALUATE COMM-TITLE
           WHEN 'Professor'
                MOVE 'Y' TO WS-TITLE-VALID

           WHEN 'Mr       '
                MOVE 'Y' TO WS-TITLE-VALID

           WHEN 'Mrs      '
                MOVE 'Y' TO WS-TITLE-VALID

           WHEN 'Miss     '
                MOVE 'Y' TO WS-TITLE-VALID

           WHEN 'Ms       '
                MOVE 'Y' TO WS-TITLE-VALID

           WHEN 'Dr       '
                MOVE 'Y' TO WS-TITLE-VALID

           WHEN 'Drs      '
                MOVE 'Y' TO WS-TITLE-VALID

           WHEN 'Lord     '
                MOVE 'Y' TO WS-TITLE-VALID

           WHEN 'Sir      '
                MOVE 'Y' TO WS-TITLE-VALID

           WHEN 'Lady     '
                MOVE 'Y' TO WS-TITLE-VALID

           WHEN '         '
                MOVE 'Y' TO WS-TITLE-VALID

           WHEN OTHER
                MOVE 'N' TO WS-TITLE-VALID
           END-EVALUATE.

           IF WS-TITLE-VALID = 'N'
              MOVE 'N' TO COMM-SUCCESS
              MOVE 'T' TO COMM-FAIL-CODE
              GOBACK
           END-IF

           MOVE SORTCODE TO REQUIRED-SORT-CODE.


      *
      *    Derive the date and time
      *

           PERFORM POPULATE-TIME-DATE.

      *
      *    Delegate the credit check to CRCCVERI
      *
           PERFORM CREDIT-CHECK.

           IF WS-CREDIT-CHECK-ERROR = 'Y'
              MOVE 0 TO COMM-CREDIT-SCORE

              STRING WS-ORIG-DATE-DD DELIMITED BY SIZE,
                     WS-ORIG-DATE-MM DELIMITED BY SIZE,
                     WS-ORIG-DATE-YYYY DELIMITED BY SIZE
                 INTO COMM-CS-REVIEW-DATE
              END-STRING

              MOVE 'N' TO COMM-SUCCESS
              MOVE 'G' TO COMM-FAIL-CODE

              DISPLAY 'WS-CREDIT-CHECK-ERROR = Y, '
                      ' RESP='
                      WS-CICS-RESP
                      ' RESP2='
                      WS-CICS-RESP2
              DISPLAY '   Exiting CRECUST. COMMAREA='
                      DFHCOMMAREA
              PERFORM GET-ME-OUT-OF-HERE

           END-IF.

           PERFORM DATE-OF-BIRTH-CHECK.

           IF WS-DATE-OF-BIRTH-ERROR = 'Y'

              MOVE 'N' TO COMM-SUCCESS
              PERFORM GET-ME-OUT-OF-HERE

           END-IF.

      *
      *    Enqueue the named counter for customer
      *
           PERFORM ENQ-NAMED-COUNTER.

      *
      *    Get the next CUSTOMER number from the CUSTOMER Named Counter
      *
           PERFORM UPD-NCS.

      *
      *    Update the datastore
      *
           PERFORM WRITE-CUSTOMER-DB2.

           PERFORM GET-ME-OUT-OF-HERE.

       POPULATE-TIME-DATE SECTION.
       PTD010.

           EXEC CICS ASKTIME
                ABSTIME(WS-U-TIME)
                END-EXEC.

           EXEC CICS FORMATTIME
                ABSTIME(WS-U-TIME)
                DDMMYYYY(WS-ORIG-DATE)
                TIME(PROC-TRAN-TIME OF PROCTRAN-AREA)
                DATESEP
                END-EXEC.

       PTD999.
           EXIT.


       ENQ-NAMED-COUNTER SECTION.
       ENC010.
           MOVE SORTCODE TO
              NCS-CUST-NO-TEST-SORT.

           EXEC CICS ENQ
                RESOURCE(NCS-CUST-NO-NAME)
                LENGTH(16)
                RESP(WS-CICS-RESP)
                RESP2(WS-CICS-RESP2)
                END-EXEC.

           IF WS-CICS-RESP NOT = DFHRESP(NORMAL)
              MOVE 'N' TO COMM-SUCCESS
              MOVE '3' TO COMM-FAIL-CODE
              PERFORM GET-ME-OUT-OF-HERE
           END-IF.

       ENC999.
           EXIT.


       DEQ-NAMED-COUNTER SECTION.
       DNC010.

           MOVE SORTCODE TO
              NCS-CUST-NO-TEST-SORT.

      D    EXEC CICS ASKTIME ABSTIME(START-DEQ) END-EXEC

           EXEC CICS DEQ
                RESOURCE(NCS-CUST-NO-NAME)
                LENGTH(16)
                RESP(WS-CICS-RESP)
                RESP2(WS-CICS-RESP2)
                END-EXEC.

           IF WS-CICS-RESP NOT = DFHRESP(NORMAL)
              MOVE 'N' TO COMM-SUCCESS
              MOVE '5' TO COMM-FAIL-CODE
              PERFORM GET-ME-OUT-OF-HERE
           END-IF.

       DNC999.
           EXIT.


       UPD-NCS SECTION.
       UN010.
      *
      *    Update the Named Counter Server
      *
           MOVE 1 TO NCS-CUST-NO-INC.

           PERFORM GET-LAST-CUSTOMER-DB2

           MOVE 'Y' TO NCS-UPDATED.

       UN999.
           EXIT.


       CREDIT-CHECK SECTION.
       CC010.
      *
      *    Delegate all credit check logic to CRCCVERI.
      *    To switch to an API-based credit check in future,
      *    replace CRCCVERI.cbl only — this call site does not change.
      *
           MOVE SORTCODE              TO CCVERI-SORTCODE OF WS-CRCCVERI-AREA
           MOVE COMM-NAME             TO CCVERI-NAME     OF WS-CRCCVERI-AREA
           MOVE COMM-DOB              TO CCVERI-DOB      OF WS-CRCCVERI-AREA
           MOVE COMM-PHONE            TO CCVERI-PHONE    OF WS-CRCCVERI-AREA
           MOVE COMM-ADDR             TO CCVERI-ADDR     OF WS-CRCCVERI-AREA
           MOVE COMM-STATUS           TO CCVERI-STATUS   OF WS-CRCCVERI-AREA
           MOVE COMM-CREATED-DATE
              TO CCVERI-CREATED-DATE  OF WS-CRCCVERI-AREA

           EXEC CICS LINK
                PROGRAM('CRCCVERI')
                COMMAREA(WS-CRCCVERI-AREA)
                LENGTH(LENGTH OF WS-CRCCVERI-AREA)
                RESP(WS-CICS-RESP)
                RESP2(WS-CICS-RESP2)
           END-EXEC

           IF WS-CICS-RESP NOT = DFHRESP(NORMAL)
              MOVE 'N'             TO COMM-SUCCESS
              MOVE 'A'             TO COMM-FAIL-CODE
              MOVE 'Y'             TO WS-CREDIT-CHECK-ERROR
              PERFORM GET-ME-OUT-OF-HERE
           END-IF

           MOVE CCVERI-CREDIT-SCORE    OF WS-CRCCVERI-AREA
              TO COMM-CREDIT-SCORE
           MOVE CCVERI-CS-REVIEW-DATE  OF WS-CRCCVERI-AREA
              TO COMM-CS-REVIEW-DATE
           MOVE CCVERI-SUCCESS         OF WS-CRCCVERI-AREA
              TO COMM-SUCCESS
           MOVE CCVERI-FAIL-CODE       OF WS-CRCCVERI-AREA
              TO COMM-FAIL-CODE

           IF CCVERI-SUCCESS OF WS-CRCCVERI-AREA NOT = 'Y'
              MOVE 'Y' TO WS-CREDIT-CHECK-ERROR
           END-IF

       CC999.
           EXIT.


       WRITE-CUSTOMER-DB2 SECTION.
       WCD010.
      *
      *    Write a record to the CUSTOMER DB2 table
      *
           INITIALIZE OUTPUT-DATA.
           INITIALIZE HOST-CUSTOMER-ROW.

           MOVE 'CUST' TO CUSTOMER-EYECATCHER.
           MOVE SORTCODE TO CUSTOMER-SORTCODE.
           MOVE NCS-CUST-NO-VALUE TO CUSTOMER-NUMBER.
           MOVE COMM-NAME TO CUSTOMER-NAME.
           MOVE COMM-DOB TO CUSTOMER-DOB.
           MOVE COMM-PHONE TO CUSTOMER-PHONE.
           MOVE COMM-ADDR TO CUSTOMER-ADDRESS.
           MOVE COMM-STATUS TO CUSTOMER-STATUS.
           MOVE COMM-CREATED-DATE TO CUSTOMER-CREATED-DATE.
           MOVE COMM-CREDIT-SCORE TO CUSTOMER-CREDIT-SCORE.
           MOVE COMM-CS-REVIEW-DATE TO CUSTOMER-CS-REVIEW-DATE.

      *
      *    Populate host variables for DB2 INSERT
      *
           MOVE 'CUST' TO HV-CUSTOMER-EYECATCHER.
           MOVE SORTCODE TO HV-CUSTOMER-SORTCODE.
           MOVE WS-CUSTOMER-NO-NUM TO HV-CUSTOMER-NUMBER.
           MOVE COMM-TITLE OF COMM-NAME TO HV-CUSTOMER-TITLE.
           MOVE COMM-FIRST-NAME OF COMM-NAME TO HV-CUSTOMER-FIRST-NAME.
           MOVE COMM-LAST-NAME OF COMM-NAME TO HV-CUSTOMER-LAST-NAME.
           COMPUTE HV-CUSTOMER-DOB =
              (COMM-DOB-YEAR * 10000) +
              (COMM-DOB-MONTH * 100) +
              COMM-DOB-DAY.
           MOVE COMM-PHONE TO HV-CUSTOMER-PHONE.
           MOVE COMM-ADDR-LINE1 OF COMM-ADDR
              TO HV-CUSTOMER-ADDR-LINE1.
           MOVE COMM-ADDR-LINE2 OF COMM-ADDR
              TO HV-CUSTOMER-ADDR-LINE2.
           MOVE COMM-CITY OF COMM-ADDR TO HV-CUSTOMER-CITY.
           MOVE COMM-POSTCODE OF COMM-ADDR TO HV-CUSTOMER-POSTCODE.
           MOVE COMM-COUNTRY OF COMM-ADDR TO HV-CUSTOMER-COUNTRY.
           MOVE COMM-STATUS TO HV-CUSTOMER-STATUS.

      *
      * Convert created date to INTEGER format (YYYYMMDD)
      *
           COMPUTE HV-CUSTOMER-CREATE-DATE =
              (COMM-CREATED-YEAR OF COMM-CREATED-DATE * 10000) +
              (COMM-CREATED-MONTH OF COMM-CREATED-DATE * 100) +
              COMM-CREATED-DAY OF COMM-CREATED-DATE.

           MOVE COMM-CREDIT-SCORE TO HV-CUSTOMER-CREDIT-SCORE.

      *
      * Convert CS review date to INTEGER format (YYYYMMDD)
      *
           COMPUTE HV-CUSTOMER-CS-REVIEW-DATE =
              (COMM-CS-REVIEW-YEAR OF COMM-CS-REVIEW-DATE * 10000) +
              (COMM-CS-REVIEW-MONTH OF COMM-CS-REVIEW-DATE * 100) +
              COMM-CS-REVIEW-DAY OF COMM-CS-REVIEW-DATE.

           DISPLAY 'CUSTOMER-EYECATCHER: ' CUSTOMER-EYECATCHER
           DISPLAY 'CUSTOMER-SORTCODE: ' CUSTOMER-SORTCODE
           DISPLAY 'CUSTOMER-NUMBER: ' CUSTOMER-NUMBER
           DISPLAY 'CUSTOMER-FIRST-NAME: ' CUSTOMER-FIRST-NAME
           DISPLAY 'CUSTOMER-LAST-NAME: ' CUSTOMER-LAST-NAME
           DISPLAY 'CUSTOMER-DOB: ' CUSTOMER-DOB-DAY OF CUSTOMER-DOB
              '/' CUSTOMER-DOB-MONTH OF CUSTOMER-DOB
              '/' CUSTOMER-DOB-YEAR OF CUSTOMER-DOB

           DISPLAY 'HV-CUSTOMER-EYECATCHER: ' HV-CUSTOMER-EYECATCHER
           DISPLAY 'HV-CUSTOMER-SORTCODE: ' HV-CUSTOMER-SORTCODE
           DISPLAY 'HV-CUSTOMER-NUMBER: ' HV-CUSTOMER-NUMBER
           DISPLAY 'HV-CUSTOMER-FIRST-NAME: ' HV-CUSTOMER-FIRST-NAME
           DISPLAY 'HV-CUSTOMER-LAST-NAME: ' HV-CUSTOMER-LAST-NAME
           DISPLAY 'HV-CUSTOMER-DOB: ' HV-CUSTOMER-DOB
           DISPLAY 'HV-CUSTOMER-CREDIT-SCOR: ' HV-CUSTOMER-CREDIT-SCORE
           DISPLAY 'HV-CUSTOMER-CS-DATE: ' HV-CUSTOMER-CS-REVIEW-DATE
      *
      *    Insert customer record into DB2
      *
           EXEC SQL
              INSERT INTO CUSTOMER
                 (CUSTOMER_EYECATCHER,
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
                  CUSTOMER_CS_REVIEW_DATE)
              VALUES
                 (:HV-CUSTOMER-EYECATCHER,
                  :HV-CUSTOMER-SORTCODE,
                  :HV-CUSTOMER-NUMBER,
                  :HV-CUSTOMER-TITLE,
                  :HV-CUSTOMER-FIRST-NAME,
                  :HV-CUSTOMER-LAST-NAME,
                  :HV-CUSTOMER-DOB,
                  :HV-CUSTOMER-PHONE,
                  :HV-CUSTOMER-ADDR-LINE1,
                  :HV-CUSTOMER-ADDR-LINE2,
                  :HV-CUSTOMER-CITY,
                  :HV-CUSTOMER-POSTCODE,
                  :HV-CUSTOMER-COUNTRY,
                  :HV-CUSTOMER-STATUS,
                  :HV-CUSTOMER-CREATE-DATE,
                  :HV-CUSTOMER-CREDIT-SCORE,
                  :HV-CUSTOMER-CS-REVIEW-DATE)
           END-EXEC.

      *
      *    Check if the INSERT was unsuccessful and take action.
      *
           IF SQLCODE NOT = 0
              MOVE SQLCODE TO SQLCODE-DISPLAY
              DISPLAY 'CRECUST - INSERT CUSTOMER failed. SQLCODE='
                      SQLCODE-DISPLAY
              MOVE 'N' TO COMM-SUCCESS
              MOVE '1' TO COMM-FAIL-CODE
              PERFORM DEQ-NAMED-COUNTER
              PERFORM GET-ME-OUT-OF-HERE
           END-IF.

      *
      *    Note: CONTROL table already updated in GET-LAST-CUSTOMER-DB2
      *    No additional update needed here

      *
      *    If the WRITE was successful then WRITE to PROCTRAN datastore
      *
           MOVE CUSTOMER-SORTCODE OF OUTPUT-DATA TO STORED-SORTCODE.
           MOVE CUSTOMER-NUMBER OF OUTPUT-DATA TO STORED-CUSTNO.
           STRING CUSTOMER-FIRST-NAME OF CUSTOMER-NAME
                  DELIMITED BY '  '
                  ' ' DELIMITED BY SIZE
                  CUSTOMER-LAST-NAME OF CUSTOMER-NAME
                  DELIMITED BY '  '
              INTO STORED-NAME
           END-STRING.
           MOVE CUSTOMER-DOB-DAY OF CUSTOMER-DOB TO STORED-DOB(1:2).
           MOVE '/' TO STORED-DOB(3:1).
           MOVE CUSTOMER-DOB-MONTH OF CUSTOMER-DOB TO STORED-DOB(4:2).
           MOVE '/' TO STORED-DOB(6:1).
           MOVE CUSTOMER-DOB-YEAR OF CUSTOMER-DOB TO STORED-DOB(7:4).

           PERFORM WRITE-PROCTRAN.

           PERFORM DEQ-NAMED-COUNTER.

      *
      *    Set up the missing data in the COMM AREA ready for return
      *
           MOVE CUSTOMER-SORTCODE OF OUTPUT-DATA
              TO COMM-SORTCODE.
           MOVE CUSTOMER-NUMBER OF OUTPUT-DATA
              TO COMM-NUMBER
           MOVE 'CUST' TO COMM-EYECATCHER.
           MOVE 'Y' TO COMM-SUCCESS.
           MOVE ' ' TO COMM-FAIL-CODE.

        WCV999.
           EXIT.


       WRITE-PROCTRAN SECTION.
       WP010.
           PERFORM WRITE-PROCTRAN-DB2.

       WP999.
           EXIT.


       WRITE-PROCTRAN-DB2 SECTION.
       WPD010.
      *
      *    Record the creation of a new CUSTOMER on PROCTRAN
      *
           INITIALIZE HOST-PROCTRAN-ROW.
           INITIALIZE WS-EIBTASKN12.

           MOVE 'PRTR' TO HV-PROCTRAN-EYECATCHER.
           MOVE SORTCODE TO HV-PROCTRAN-SORT-CODE.
           MOVE ZEROS TO HV-PROCTRAN-ACC-NUMBER.
           MOVE EIBTASKN TO WS-EIBTASKN12.
           MOVE WS-EIBTASKN12 TO HV-PROCTRAN-REF.

      *
      *    Populate the time and date
      *
           EXEC CICS ASKTIME
                ABSTIME(WS-U-TIME)
                END-EXEC.

           EXEC CICS FORMATTIME
                ABSTIME(WS-U-TIME)
                DDMMYYYY(WS-ORIG-DATE)
                TIME(HV-PROCTRAN-TIME)
                DATESEP('.')
                END-EXEC.

           MOVE WS-ORIG-DATE TO WS-ORIG-DATE-GRP-X.
           MOVE WS-ORIG-DATE-GRP-X TO HV-PROCTRAN-DATE.

           MOVE STORED-SORTCODE TO HV-PROCTRAN-DESC(1:6).
           MOVE STORED-CUSTNO TO HV-PROCTRAN-DESC(7:10).
           MOVE STORED-NAME TO HV-PROCTRAN-DESC(17:14).
           MOVE STORED-DOB TO HV-PROCTRAN-DESC(31:10).

           MOVE 'OCC' TO HV-PROCTRAN-TYPE.
           MOVE ZEROS TO HV-PROCTRAN-AMOUNT.

           EXEC SQL
              INSERT INTO PROCTRAN
                     (
                      PROCTRAN_EYECATCHER,
                      PROCTRAN_SORTCODE,
                      PROCTRAN_NUMBER,
                      PROCTRAN_DATE,
                      PROCTRAN_TIME,
                      PROCTRAN_REF,
                      PROCTRAN_TYPE,
                      PROCTRAN_DESC,
                      PROCTRAN_AMOUNT
                     )
              VALUES
                     (
                      :HV-PROCTRAN-EYECATCHER,
                      :HV-PROCTRAN-SORT-CODE,
                      :HV-PROCTRAN-ACC-NUMBER,
                      :HV-PROCTRAN-DATE,
                      :HV-PROCTRAN-TIME,
                      :HV-PROCTRAN-REF,
                      :HV-PROCTRAN-TYPE,
                      :HV-PROCTRAN-DESC,
                      :HV-PROCTRAN-AMOUNT
                     )
           END-EXEC.

      *
      *    Check the SQLCODE
      *
           IF SQLCODE NOT = 0
              MOVE SQLCODE TO SQLCODE-DISPLAY
      *
      *       Preserve the RESP and RESP2, then set up the
      *       standard ABEND info before getting the applid,
      *       date/time etc. and linking to the Abend Handler
      *       program.
      *
              INITIALIZE ABNDINFO-REC
              MOVE EIBRESP TO ABND-RESPCODE
              MOVE EIBRESP2 TO ABND-RESP2CODE
      *
      *       Get supplemental information
      *
              EXEC CICS ASSIGN APPLID(ABND-APPLID)
                   END-EXEC

              MOVE EIBTASKN TO ABND-TASKNO-KEY
              MOVE EIBTRNID TO ABND-TRANID

              PERFORM POPULATE-TIME-DATE2

              MOVE WS-ORIG-DATE TO ABND-DATE
              STRING WS-TIME-NOW-GRP-HH DELIMITED BY SIZE,
                     ':' DELIMITED BY SIZE,
                     WS-TIME-NOW-GRP-MM DELIMITED BY SIZE,
                     ':' DELIMITED BY SIZE,
                     WS-TIME-NOW-GRP-MM DELIMITED BY SIZE
                 INTO ABND-TIME
              END-STRING

              MOVE WS-U-TIME TO ABND-UTIME-KEY
              MOVE 'HWPT' TO ABND-CODE

              EXEC CICS ASSIGN PROGRAM(ABND-PROGRAM)
                   END-EXEC

              MOVE SQLCODE-DISPLAY TO ABND-SQLCODE

              STRING 'WPD010  - Unable to write to PROCTRAN DB2 '
                 DELIMITED BY SIZE,
                     'datastore with the following data:'
                 DELIMITED BY SIZE,
                     HOST-PROCTRAN-ROW
                 DELIMITED BY SIZE,
                     ' EIBRESP=' DELIMITED BY SIZE,
                     ABND-RESPCODE DELIMITED BY SIZE,
                     ' RESP2=' DELIMITED BY SIZE,
                     ABND-RESP2CODE DELIMITED BY SIZE
                 INTO ABND-FREEFORM
              END-STRING

              EXEC CICS LINK PROGRAM(WS-ABEND-PGM)
                   COMMAREA(ABNDINFO-REC)
                   END-EXEC

              DISPLAY 'In CRECUST(WPD010) '
                      'UNABLE TO WRITE TO PROCTRAN DB2 DATASTORE'
                      ' SQLCODE='
                      SQLCODE-DISPLAY
                      'WITH THE FOLLOWING DATA:'
                      HOST-PROCTRAN-ROW


              PERFORM DEQ-NAMED-COUNTER

              EXEC CICS ABEND
                   ABCODE('HWPT')
                   END-EXEC
           END-IF.

        WPD999.
           EXIT.


       GET-ME-OUT-OF-HERE SECTION.
       GMOFH010.
      *
      *    Finish
      *
           EXEC CICS RETURN
                END-EXEC.

       GMOFH999.
           EXIT.


       GET-LAST-CUSTOMER-DB2 SECTION.
       GLCD010.
      *
      *    Get and increment the customer number from DB2 CONTROL table
      *
           INITIALIZE HV-CONTROL-NAME
           MOVE SORTCODE TO NCS-CUST-NO-TEST-SORT
           STRING NCS-CUST-NO-ACT-NAME
                  NCS-CUST-NO-TEST-SORT
                  NCS-CUST-NO-FILL
              DELIMITED BY SIZE
              INTO HV-CONTROL-NAME
           END-STRING

      *
      *    Select current customer number from CONTROL table
      *
           DISPLAY 'CRECUST - Searching for CONTROL_NAME=['
                   HV-CONTROL-NAME(1:16)
                   ']'
           EXEC SQL
              SELECT CONTROL_VALUE_NUM
                INTO :HV-CONTROL-VALUE-NUM
                FROM CONTROL
               WHERE CONTROL_NAME = :HV-CONTROL-NAME
           END-EXEC.

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO SQLCODE-DISPLAY
              DISPLAY 'CRECUST - SELECT CONTROL failed. SQLCODE='
                      SQLCODE-DISPLAY
              DISPLAY 'CRECUST - CONTROL_NAME was: ['
                      HV-CONTROL-NAME(1:16)
                      ']'
              MOVE 'N' TO COMM-SUCCESS
              MOVE '4' TO COMM-FAIL-CODE
              PERFORM DEQ-NAMED-COUNTER
              PERFORM GET-ME-OUT-OF-HERE
           END-IF.

      *
      *    Increment the customer number
      *
           ADD 1 TO HV-CONTROL-VALUE-NUM.

      *
      *    Update the CONTROL table with new customer number
      *
           EXEC SQL
              UPDATE CONTROL
                 SET CONTROL_VALUE_NUM = :HV-CONTROL-VALUE-NUM
               WHERE CONTROL_NAME = :HV-CONTROL-NAME
           END-EXEC.

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO SQLCODE-DISPLAY
              DISPLAY 'CRECUST - UPDATE CONTROL failed. SQLCODE='
                      SQLCODE-DISPLAY
              MOVE 'N' TO COMM-SUCCESS
              MOVE '4' TO COMM-FAIL-CODE
              PERFORM DEQ-NAMED-COUNTER
              PERFORM GET-ME-OUT-OF-HERE
           END-IF.

      *
      *    Set the new customer number in various fields
      *    Convert from COMP to DISPLAY via intermediate field
      *
           MOVE HV-CONTROL-VALUE-NUM TO WS-CUSTOMER-NO-NUM
           MOVE WS-CUSTOMER-NO-NUM TO
              COMM-NUMBER
              CUSTOMER-NUMBER
              REQUIRED-CUST-NUMBER2
           MOVE HV-CONTROL-VALUE-NUM TO NCS-CUST-NO-VALUE.

        GLCV999.
           EXIT.


       DATE-OF-BIRTH-CHECK SECTION.
       DOBC010.
      *
      *    Ensure that the Date Of Birth is valid
      *
           IF COMM-DOB-YEAR OF COMM-DOB < 1601
              MOVE 'Y' TO WS-DATE-OF-BIRTH-ERROR
              MOVE 'O' TO COMM-FAIL-CODE
              GO TO DOBC999
           END-IF.

           MOVE COMM-DOB-YEAR OF COMM-DOB TO CEEDAYS-YEAR.
           MOVE COMM-DOB-MONTH OF COMM-DOB TO CEEDAYS-MONTH.
           MOVE COMM-DOB-DAY OF COMM-DOB TO CEEDAYS-DAY.

           CALL "CEEDAYS" USING DATE-OF-BIRTH-FOR-CEEDAYS
                                DATE-OF-BIRTH-FORMAT,
                                WS-DATE-OF-BIRTH-LILLIAN,
                                FC.

           IF NOT CEE000 OF FC THEN
              MOVE 'Y' TO WS-DATE-OF-BIRTH-ERROR
              MOVE 'Z' TO COMM-FAIL-CODE
              DISPLAY 'CEEDAYS failed, FORMAT LENGTH 10 with msg '
                      MSG-NO OF FC
                      ' for date YYYYMMDD'
                      DATE-OF-BIRTH-FOR-CEEDAYS
              GO TO DOBC999
           END-IF.

           CALL "CEELOCT" USING WS-TODAY-LILLIAN,
                                WS-TODAY-SECONDS,
                                WS-TODAY-GREGORIAN,
                                FC.

           IF NOT CEE000 OF FC THEN
              MOVE 'Y' TO WS-DATE-OF-BIRTH-ERROR
              DISPLAY 'CEEDLOCT failed with msg '
                      MSG-NO OF FC
              GO TO DOBC999
           END-IF.

           SUBTRACT COMM-DOB-YEAR OF COMM-DOB FROM WS-TODAY-G-YEAR
              GIVING WS-CUSTOMER-AGE

           IF WS-CUSTOMER-AGE > 150
              MOVE 'Y' TO WS-DATE-OF-BIRTH-ERROR
              MOVE 'O' TO COMM-FAIL-CODE
              GO TO DOBC999
           END-IF.

           IF WS-TODAY-LILLIAN < WS-DATE-OF-BIRTH-LILLIAN
              MOVE 'Y' TO WS-DATE-OF-BIRTH-ERROR
              MOVE 'Y' TO COMM-FAIL-CODE
           END-IF.

        DOBC999.
           EXIT.


       POPULATE-TIME-DATE2 SECTION.
       PTD2010.
      D    DISPLAY 'POPULATE-TIME-DATE2 SECTION'.

           EXEC CICS ASKTIME
                ABSTIME(WS-U-TIME)
                END-EXEC.

           EXEC CICS FORMATTIME
                ABSTIME(WS-U-TIME)
                DDMMYYYY(WS-ORIG-DATE)
                TIME(WS-TIME-NOW)
                DATESEP
                END-EXEC.

        PTD2999.
           EXIT.
