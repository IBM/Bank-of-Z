       PROCESS CICS,NODYNAM,NSYMBOL(NATIONAL),TRUNC(STD)
       CBL CICS('SP,EDF,DLI')
       CBL SQL
      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      ******************************************************************
      ******************************************************************
      * This program gets called when someone updates the customer
      * details.
      *
      * The program receives as input all of the fields which make
      * up the Customer record. It then accesses the VSAM datastore.
      *
      * Because it is only permissible to change a limited number of
      * fields on the Customer record, no record needs to be written to
      * PROCTRAN.
      *
      * The presentation layer is responsible for ensuring that the
      * fields are validated.
      *
      * If the Customer cannot be updated a failure flag is returned
      * to the calling program.
      *
      ******************************************************************

       IDENTIFICATION DIVISION.
       PROGRAM-ID. UPDCUST.
       AUTHOR. Jon Collett.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *SOURCE-COMPUTER.   IBM-370 WITH DEBUGGING MODE.
       SOURCE-COMPUTER.  IBM-370.
       OBJECT-COMPUTER.  IBM-370.

       INPUT-OUTPUT SECTION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.


       COPY SORTCODE.



       77 SYSIDERR-RETRY                PIC 999.

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
          03 HV-CUSTOMER-EMAIL          PIC X(60).
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

      * Pull in the SQL COMMAREA
           EXEC SQL
          INCLUDE SQLCA
           END-EXEC.

       01 SQLCODE-DISPLAY               PIC S9(8) DISPLAY
             SIGN LEADING SEPARATE.

       01 WS-CICS-WORK-AREA.
          03 WS-CICS-RESP               PIC S9(8) COMP.
          03 WS-CICS-RESP2              PIC S9(8) COMP.


       LOCAL-STORAGE SECTION.
       01 DB2-DATE-REFORMAT.
          03 DB2-DATE-REF-YR            PIC 9(4).
          03 FILLER                     PIC X.
          03 DB2-DATE-REF-MNTH          PIC 99.
          03 FILLER                     PIC X.
          03 DB2-DATE-REF-DAY           PIC 99.


       01 WS-CUST-DATA.
          COPY CUSTOMER.

       01 WS-EIBTASKN12                 PIC 9(12)  VALUE 0.
       01 WS-SQLCODE-DISP               PIC 9(9)   VALUE 0.

      *
      * Pull in the input and output data structures
      *
       01 DESIRED-CUST-KEY.
          03 DESIRED-SORT-CODE          PIC 9(6).
          03 DESIRED-CUSTNO             PIC 9(10).

       01 WS-CUST-REC-LEN               PIC S9(4) COMP
                                                   VALUE 0.

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
          03 FILLER                     PIC X      VALUE '.'.
          03 WS-ORIG-DATE-MM-X          PIC XX.
          03 FILLER                     PIC X      VALUE '.'.
          03 WS-ORIG-DATE-YYYY-X        PIC X(4).

       01 REJ-REASON                    PIC XX     VALUE SPACES.

       01 WS-PASSED-DATA.
          02 WS-TEST-KEY                PIC X(4).
          02 WS-SORT-CODE               PIC 9(6).
          02 WS-CUSTOMER-RANGE.
             07 WS-CUSTOMER-RANGE-TOP   PIC X.
             07 WS-CUSTOMER-RANGE-MIDDLE
                                        PIC X.
             07 WS-CUSTOMER-RANGE-BOTTOM
                                        PIC X.

       01 WS-SORT-DIV.
          03 WS-SORT-DIV1               PIC XX.
          03 WS-SORT-DIV2               PIC XX.
          03 WS-SORT-DIV3               PIC XX.

       01 CUSTOMER-KY.
          03 REQUIRED-SORT-CODE         PIC 9(6)   VALUE 0.
          03 REQUIRED-ACC-NUM           PIC 9(8)   VALUE 0.

       01 STORM-DRAIN-CONDITION         PIC X(20).

       01 WS-UNSTR-TITLE                PIC X(9)   VALUE ' '.
       01 WS-TITLE-VALID                PIC X.

       01 WS-TIME-DATA.
          03 WS-TIME-NOW                PIC 9(6).
          03 WS-TIME-NOW-GRP REDEFINES WS-TIME-NOW.
             05 WS-TIME-NOW-GRP-HH      PIC 99.
             05 WS-TIME-NOW-GRP-MM      PIC 99.
             05 WS-TIME-NOW-GRP-SS      PIC 99.

       01 WS-ABEND-PGM                  PIC X(8)   VALUE 'ABNDPROC'.

       01 ABNDINFO-REC.
           COPY ABNDINFO.

       LINKAGE SECTION.
       01 DFHCOMMAREA.
           COPY UPDCUST.

       PROCEDURE DIVISION.
       PREMIERE SECTION.
       A010.

           MOVE COMM-SCODE TO DESIRED-SORT-CODE.

      *
      *    You can change the customer's name, but the title must
      *    be a valid one. Check that here
      *
           MOVE COMM-TITLE TO WS-UNSTR-TITLE.

           MOVE ' ' TO WS-TITLE-VALID.

           EVALUATE TRUE
           WHEN WS-UNSTR-TITLE = 'Professor' OR
              WS-UNSTR-TITLE = 'Mr' OR
              WS-UNSTR-TITLE = 'Mrs' OR
              WS-UNSTR-TITLE = 'Miss' OR
              WS-UNSTR-TITLE = 'Ms' OR
              WS-UNSTR-TITLE = 'Dr' OR
              WS-UNSTR-TITLE = 'Drs' OR
              WS-UNSTR-TITLE = 'Lord' OR
              WS-UNSTR-TITLE = 'Sir' OR
              WS-UNSTR-TITLE = 'Lady' OR
              WS-UNSTR-TITLE = SPACES
                MOVE 'Y' TO WS-TITLE-VALID

           WHEN OTHER
                MOVE 'N' TO WS-TITLE-VALID
           END-EVALUATE.

           IF WS-TITLE-VALID = 'N'
              MOVE 'N' TO COMM-UPD-SUCCESS
              MOVE 'T' TO COMM-UPD-FAIL-CD
              GOBACK
           END-IF

      *
      *          Update the CUSTOMER datastore
      *
           PERFORM UPDATE-CUSTOMER-DB2
      *
      *    The COMMAREA values have now been set so all we need to do
      *    is finish
      *
           PERFORM GET-ME-OUT-OF-HERE.

       A999.
           EXIT.


       UPDATE-CUSTOMER-DB2 SECTION.
       UCD010.

      *
      *    Update customer record in DB2
      *
           MOVE COMM-SCODE TO DESIRED-SORT-CODE.
           MOVE COMM-CUSTNO TO DESIRED-CUSTNO.

      *
      *    Validate that name and address are provided
      *    (same validation logic as VSAM version)
      *
           IF (COMM-FIRST-NAME = SPACES OR COMM-FIRST-NAME(1:1) = ' ')
              AND (COMM-LAST-NAME = SPACES OR COMM-LAST-NAME(1:1) = ' ')
              AND (COMM-ADDR-LINE1 = SPACES OR COMM-ADDR-LINE1(1:1) =
              ' ')
              MOVE 'N' TO COMM-UPD-SUCCESS
              MOVE '4' TO COMM-UPD-FAIL-CD
              GO TO UCD999
           END-IF.

      *
      *    First, read the current customer record
      *
           MOVE DESIRED-SORT-CODE TO HV-CUSTOMER-SORTCODE.
           MOVE DESIRED-CUSTNO TO HV-CUSTOMER-NUMBER.

           EXEC SQL
              SELECT CUSTOMER_EYECATCHER,
                     CUSTOMER_SORTCODE,
                     CUSTOMER_NUMBER,
                     CUSTOMER_TITLE,
                     CUSTOMER_FIRST_NAME,
                     CUSTOMER_LAST_NAME,
                     CUSTOMER_EMAIL,
                     CUSTOMER_PHONE,
                     CUSTOMER_ADDR_LINE1,
                     CUSTOMER_ADDR_LINE2,
                     CUSTOMER_CITY,
                     CUSTOMER_POSTCODE,
                     CUSTOMER_COUNTRY,
                     CUSTOMER_STATUS,
                     CUSTOMER_CREATED_DATE,
                     CUSTOMER_DATE_OF_BIRTH,
                     CUSTOMER_CREDIT_SCORE,
                     CUSTOMER_CS_REVIEW_DATE
                INTO :HV-CUSTOMER-EYECATCHER,
                     :HV-CUSTOMER-SORTCODE,
                     :HV-CUSTOMER-NUMBER,
                     :HV-CUSTOMER-TITLE,
                     :HV-CUSTOMER-FIRST-NAME,
                     :HV-CUSTOMER-LAST-NAME,
                     :HV-CUSTOMER-EMAIL,
                     :HV-CUSTOMER-PHONE,
                     :HV-CUSTOMER-ADDR-LINE1,
                     :HV-CUSTOMER-ADDR-LINE2,
                     :HV-CUSTOMER-CITY,
                     :HV-CUSTOMER-POSTCODE,
                     :HV-CUSTOMER-COUNTRY,
                     :HV-CUSTOMER-STATUS,
                     :HV-CUSTOMER-CREATE-DATE,
                     :HV-CUSTOMER-DOB,
                     :HV-CUSTOMER-CREDIT-SCORE,
                     :HV-CUSTOMER-CS-REVIEW-DATE
                FROM CUSTOMER
               WHERE CUSTOMER_SORTCODE = :HV-CUSTOMER-SORTCODE
                 AND CUSTOMER_NUMBER = :HV-CUSTOMER-NUMBER
           END-EXEC.

      *
      *    Check if customer was found
      *
           IF SQLCODE = 100
              MOVE 'N' TO COMM-UPD-SUCCESS
              MOVE '1' TO COMM-UPD-FAIL-CD
              GO TO UCD999
           END-IF.

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO SQLCODE-DISPLAY
              DISPLAY 'UPDCUST - SELECT CUSTOMER failed. SQLCODE='
                      SQLCODE-DISPLAY
              MOVE 'N' TO COMM-UPD-SUCCESS
              MOVE '2' TO COMM-UPD-FAIL-CD
              GO TO UCD999
           END-IF.

      *
      *    Update the fields based on what was provided
      *    (same logic as VSAM version)
      *
           IF COMM-FIRST-NAME OF COMM-NAME (1:1) NOT = ' '
              MOVE COMM-TITLE OF COMM-NAME TO HV-CUSTOMER-TITLE
              MOVE COMM-FIRST-NAME OF COMM-NAME
                 TO HV-CUSTOMER-FIRST-NAME
              MOVE COMM-LAST-NAME OF COMM-NAME
                 TO HV-CUSTOMER-LAST-NAME
           END-IF.

           IF COMM-EMAIL(1:1) NOT = ' '
              MOVE COMM-EMAIL TO HV-CUSTOMER-EMAIL
           END-IF.

           IF COMM-PHONE(1:1) NOT = ' '
              MOVE COMM-PHONE TO HV-CUSTOMER-PHONE
           END-IF.

           IF COMM-ADDR-LINE1 OF COMM-ADDR (1:1) NOT = ' '
              MOVE COMM-ADDR-LINE1 OF COMM-ADDR
                 TO HV-CUSTOMER-ADDR-LINE1
              MOVE COMM-ADDR-LINE2 OF COMM-ADDR
                 TO HV-CUSTOMER-ADDR-LINE2
              MOVE COMM-CITY OF COMM-ADDR TO HV-CUSTOMER-CITY
              MOVE COMM-POSTCODE OF COMM-ADDR TO HV-CUSTOMER-POSTCODE
              MOVE COMM-COUNTRY OF COMM-ADDR TO HV-CUSTOMER-COUNTRY
           END-IF.

           IF COMM-STATUS(1:1) NOT = ' '
              MOVE COMM-STATUS TO HV-CUSTOMER-STATUS
           END-IF.

           MOVE COMM-EMAIL TO HV-CUSTOMER-EMAIL.

      *
      *    Update the customer record in DB2
      *
           EXEC SQL
              UPDATE CUSTOMER
                 SET CUSTOMER_TITLE = :HV-CUSTOMER-TITLE,
                     CUSTOMER_FIRST_NAME = :HV-CUSTOMER-FIRST-NAME,
                     CUSTOMER_LAST_NAME = :HV-CUSTOMER-LAST-NAME,
                     CUSTOMER_EMAIL = :HV-CUSTOMER-EMAIL,
                     CUSTOMER_PHONE = :HV-CUSTOMER-PHONE,
                     CUSTOMER_ADDR_LINE1 = :HV-CUSTOMER-ADDR-LINE1,
                     CUSTOMER_ADDR_LINE2 = :HV-CUSTOMER-ADDR-LINE2,
                     CUSTOMER_CITY = :HV-CUSTOMER-CITY,
                     CUSTOMER_POSTCODE = :HV-CUSTOMER-POSTCODE,
                     CUSTOMER_COUNTRY = :HV-CUSTOMER-COUNTRY,
                     CUSTOMER_STATUS = :HV-CUSTOMER-STATUS,
                     CUSTOMER_CREATED_DATE = :HV-CUSTOMER-CREATE-DATE
               WHERE CUSTOMER_SORTCODE = :HV-CUSTOMER-SORTCODE
                 AND CUSTOMER_NUMBER = :HV-CUSTOMER-NUMBER
           END-EXEC.

      *
      *    Check if update was successful
      *
           IF SQLCODE NOT = 0
              MOVE SQLCODE TO SQLCODE-DISPLAY
              DISPLAY 'UPDCUST - UPDATE CUSTOMER failed. SQLCODE='
                      SQLCODE-DISPLAY
              MOVE 'N' TO COMM-UPD-SUCCESS
              MOVE '3' TO COMM-UPD-FAIL-CD
              GO TO UCD999
           END-IF.

      *
      *    Update was successful - set return values
      *
           MOVE HV-CUSTOMER-EYECATCHER TO COMM-EYE.
           MOVE HV-CUSTOMER-SORTCODE TO COMM-SCODE.
           MOVE HV-CUSTOMER-NUMBER TO COMM-CUSTNO.
           MOVE HV-CUSTOMER-TITLE TO COMM-TITLE OF COMM-NAME.
           MOVE HV-CUSTOMER-FIRST-NAME TO COMM-FIRST-NAME
              OF COMM-NAME.
           MOVE HV-CUSTOMER-LAST-NAME TO COMM-LAST-NAME
              OF COMM-NAME.
           MOVE HV-CUSTOMER-EMAIL TO COMM-EMAIL.
           MOVE HV-CUSTOMER-PHONE TO COMM-PHONE.
           MOVE HV-CUSTOMER-ADDR-LINE1 TO COMM-ADDR-LINE1
              OF COMM-ADDR.
           MOVE HV-CUSTOMER-ADDR-LINE2 TO COMM-ADDR-LINE2
              OF COMM-ADDR.
           MOVE HV-CUSTOMER-CITY TO COMM-CITY OF COMM-ADDR.
           MOVE HV-CUSTOMER-POSTCODE TO COMM-POSTCODE OF COMM-ADDR.
           MOVE HV-CUSTOMER-COUNTRY TO COMM-COUNTRY OF COMM-ADDR.
           MOVE HV-CUSTOMER-STATUS TO COMM-STATUS.
           COMPUTE COMM-CREATED-YEAR =
              HV-CUSTOMER-CREATE-DATE / 10000.
           COMPUTE COMM-CREATED-MONTH =
              FUNCTION MOD(HV-CUSTOMER-CREATE-DATE / 100, 100).
           COMPUTE COMM-CREATED-DAY =
              FUNCTION MOD(HV-CUSTOMER-CREATE-DATE, 100).
           COMPUTE COMM-DOB-YEAR = HV-CUSTOMER-DOB / 10000.
           COMPUTE COMM-DOB-MONTH =
              FUNCTION MOD(HV-CUSTOMER-DOB / 100, 100).
           COMPUTE COMM-DOB-DAY =
              FUNCTION MOD(HV-CUSTOMER-DOB, 100).
           MOVE HV-CUSTOMER-CREDIT-SCORE TO COMM-CREDIT-SCORE.
           MOVE HV-CUSTOMER-CS-REVIEW-DATE TO COMM-CS-REVIEW-DATE.

           MOVE 'Y' TO COMM-UPD-SUCCESS.

       UCD999.
           EXIT.


       GET-ME-OUT-OF-HERE SECTION.
       GMOOH010.

           EXEC CICS RETURN
                END-EXEC.

       GMOOH999.
           EXIT.


       POPULATE-TIME-DATE SECTION.
       PTD010.

           EXEC CICS ASKTIME
                ABSTIME(WS-U-TIME)
                END-EXEC.

           EXEC CICS FORMATTIME
                ABSTIME(WS-U-TIME)
                DDMMYYYY(WS-ORIG-DATE)
                TIME(WS-TIME-NOW)
                DATESEP
                END-EXEC.

       PTD999.
           EXIT.