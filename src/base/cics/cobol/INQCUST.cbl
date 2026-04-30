       CBL CICS('SP,EDF')
       CBL SQL
      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      ******************************************************************

      ******************************************************************
      * This program takes customer number as input
      * and returns to the calling program a commarea containing all of
      * the customer information for that record.
      *
      * What gets returned is the CUSTOMER data if the CUSTOMER is
      * found or a CUSTOMER record set to low values if a matching
      * CUSTOMER record could not be found.
      *
      * If there is any kind of problem then an appropriate abend is
      * issued.
      *
      ******************************************************************

       IDENTIFICATION DIVISION.
       PROGRAM-ID. INQCUST.
       AUTHOR. Jon Collett.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *SOURCE-COMPUTER.  IBM-370 WITH DEBUGGING MODE.
       SOURCE-COMPUTER.  IBM-370.
       OBJECT-COMPUTER.  IBM-370.
       INPUT-OUTPUT SECTION.

       DATA DIVISION.
       FILE SECTION.

       WORKING-STORAGE SECTION.

       77 SYSIDERR-RETRY               PIC 999.
       77 INQCUST-RETRY                PIC 9999.

      * CUSTOMER DB2 copybook
          EXEC SQL
             INCLUDE CUSTDB2
          END-EXEC.

      * CUSTOMER host variables for DB2
       01 HOST-CUSTOMER-ROW.
          03 HV-CUSTOMER-EYECATCHER     PIC X(4).
          03 HV-CUSTOMER-SORTCODE       PIC X(6).
          03 HV-CUSTOMER-NUMBER         PIC X(10).
          03 HV-CUSTOMER-NAME           PIC X(60).
          03 HV-CUSTOMER-ADDRESS        PIC X(160).
          03 HV-CUSTOMER-EMAIL          PIC X(60).
          03 HV-CUSTOMER-DOB            PIC S9(9) COMP.
          03 HV-CUSTOMER-CREDIT-SCORE   PIC S9(4) COMP.
          03 HV-CUSTOMER-CS-REVIEW-DATE PIC S9(9) COMP.

      * Pull in the SQL COMMAREA
       EXEC SQL
          INCLUDE SQLCA
       END-EXEC.

       01 SQLCODE-DISPLAY               PIC S9(8) DISPLAY
             SIGN LEADING SEPARATE.

       01 WS-CICS-WORK-AREA.
          03 WS-CICS-RESP              PIC S9(8) COMP.
          03 WS-CICS-RESP2             PIC S9(8) COMP.

       LOCAL-STORAGE SECTION.
       COPY SORTCODE.



       01 OUTPUT-DATA.
           COPY CUSTOMER.

       01 CUSTOMER-KY.
          03 REQUIRED-SORT-CODE        PIC 9(6) VALUE 0.
          03 REQUIRED-CUST-NUMBER      PIC 9(10) VALUE 0.

       01 CUSTOMER-KY2.
          03 REQUIRED-SORT-CODE2       PIC 9(6) VALUE 0.
          03 REQUIRED-CUST-NUMBER2     PIC 9(10) VALUE 0.

       01 RANDOM-CUSTOMER              PIC 9(10) VALUE 0.
       01 HIGHEST-CUST-NUMBER          PIC 9(10) VALUE 0.

       01 EXIT-VSAM-READ               PIC X VALUE 'N'.
       01 EXIT-DB2-READ                PIC X VALUE 'N'.
       01 EXIT-IMS-READ                PIC X VALUE 'N'.


       01 WS-V-RETRIED                 PIC X VALUE 'N'.
       01 WS-D-RETRIED                 PIC X VALUE 'N'.

       01 WS-PROGRAM                   PIC X(8) VALUE SPACES.


      *
      * CUSTOMER NCS definitions
      *
       01 NCS-CUST-NO-STUFF.
          03 NCS-CUST-NO-NAME.
             05 NCS-CUST-NO-ACT-NAME   PIC X(8) VALUE 'HBNKCUST'.
             05 NCS-CUST-NO-TEST-SORT  PIC X(6) VALUE '      '.
             05 NCS-CUST-NO-FILL       PIC XX VALUE '  '.

          03 NCS-CUST-NO-INC           PIC 9(16) COMP VALUE 0.
          03 NCS-CUST-NO-VALUE         PIC 9(16) COMP VALUE 0.

          03 NCS-CUST-NO-RESP          PIC XX VALUE '00'.


       01 WS-PASSED-DATA.
          02 WS-TEST-KEY               PIC X(4).
          02 WS-SORT-CODE              PIC 9(6).
          02 WS-CUSTOMER-RANGE.
             07 WS-CUSTOMER-RANGE-TOP             PIC X.
             07 WS-CUSTOMER-RANGE-MIDDLE          PIC X.
             07 WS-CUSTOMER-RANGE-BOTTOM          PIC X.

       01 WS-SORT-DIV.
          03 WS-SORT-DIV1              PIC XX.
          03 WS-SORT-DIV2              PIC XX.
          03 WS-SORT-DIV3              PIC XX.

       01 WS-DISP-CUST-NO-VAL          PIC S9(18) DISPLAY.

       01 VAR-REMIX.
          03 REMIX-SCODE               PIC X(6).
          03 REMIX-NUM REDEFINES REMIX-SCODE.
             05 REMIX-SCODE-NUM        PIC 9(6).

       01 VAR-REMIX2.
          03 REMIX2-CREDIT-SCR         PIC X(3).
          03 REMIX2-NUM REDEFINES REMIX2-CREDIT-SCR.
             05 REMIX2-CREDIT-SCR-NUM  PIC 9(3).

       01 MY-ABEND-CODE                PIC XXXX.

       01 WS-STORM-DRAIN               PIC X VALUE 'N'.
       01 STORM-DRAIN-CONDITION        PIC X(20).

        01 WS-INVOKING-PROGRAM         PIC X(8).

       01 WS-POINTER USAGE POINTER.
       01 WS-POINTER-BYTES   REDEFINES WS-POINTER PIC X(8).
       01 WS-POINTER-NUMBER  REDEFINES WS-POINTER PIC 9(8) BINARY.

       01 WS-POINTER-NUMBER-DISPLAY    PIC 9(8) DISPLAY.

       01 WS-U-TIME                    PIC S9(15) COMP-3.
       01 WS-ORIG-DATE                 PIC X(10).
       01 WS-ORIG-DATE-GRP REDEFINES WS-ORIG-DATE.
          03 WS-ORIG-DATE-DD           PIC 99.
          03 FILLER                    PIC X.
          03 WS-ORIG-DATE-MM           PIC 99.
          03 FILLER                    PIC X.
          03 WS-ORIG-DATE-YYYY         PIC 9999.

       01 WS-ORIG-DATE-GRP-X.
          03 WS-ORIG-DATE-DD-X         PIC XX.
          03 FILLER                    PIC X VALUE '.'.
          03 WS-ORIG-DATE-MM-X         PIC XX.
          03 FILLER                    PIC X VALUE '.'.
          03 WS-ORIG-DATE-YYYY-X       PIC X(4).

       01 WS-TIME-DATA.
           03 WS-TIME-NOW              PIC 9(6).
           03 WS-TIME-NOW-GRP REDEFINES WS-TIME-NOW.
              05 WS-TIME-NOW-GRP-HH    PIC 99.
              05 WS-TIME-NOW-GRP-MM    PIC 99.
              05 WS-TIME-NOW-GRP-SS    PIC 99.

       01 WS-ABEND-PGM                 PIC X(8) VALUE 'ABNDPROC'.

       01 ABNDINFO-REC.
           COPY ABNDINFO.


       LINKAGE SECTION.
       01 DFHCOMMAREA.
           COPY INQCUST.


       PROCEDURE DIVISION USING DFHCOMMAREA.
       PREMIERE SECTION.
       P010.
      *
      *    Set up abend handling
      *
           EXEC CICS HANDLE ABEND
              LABEL(ABEND-HANDLING)
           END-EXEC.

           MOVE 'N' TO INQCUST-INQ-SUCCESS
           MOVE '0' TO INQCUST-INQ-FAIL-CD

           MOVE SORTCODE TO REQUIRED-SORT-CODE.
           MOVE INQCUST-CUSTNO TO REQUIRED-CUST-NUMBER.
      *
      *    Is the incoming CUSTOMER number set to 0's, 9's or
      *    an actual value?
      *
      *    If the incoming CUSTOMER number is 0's (random
      *    customer) or the incoming CUSTOMER number is 9's
      *    (the last valid CUSTOMER in use) then access the
      *    named counter server to get the last
      *    CUSTOMER-NUMBER in use.
      *
           IF INQCUST-CUSTNO = 0000000000 OR INQCUST-CUSTNO = 9999999999
              PERFORM READ-CUSTOMER-NCS
      D       DISPLAY 'CUST NO RETURNED FROM NCS=' NCS-CUST-NO-VALUE
              IF INQCUST-INQ-SUCCESS = 'Y'
                MOVE NCS-CUST-NO-VALUE TO REQUIRED-CUST-NUMBER
              ELSE
                PERFORM GET-ME-OUT-OF-HERE
              END-IF
           END-IF.
      *
      * For a random customer generate a CUSTOMER number
      * randomly which is less than the highest CUSTOMER
      * number that is currently in use.
      *
           IF INQCUST-CUSTNO = 0000000000
              PERFORM GENERATE-RANDOM-CUSTOMER
              MOVE RANDOM-CUSTOMER TO REQUIRED-CUST-NUMBER
           END-IF.
           MOVE 'N' TO EXIT-VSAM-READ.
           MOVE 'N' TO EXIT-DB2-READ.
           MOVE 'N' TO WS-D-RETRIED.
           MOVE 'N' TO WS-V-RETRIED.
      *
      *          Get the customer information
      *
           PERFORM READ-CUSTOMER-DB2
             UNTIL EXIT-VSAM-READ = 'Y'.
      *
      * Return the CUSTOMER data in the commarea.
      *
           IF INQCUST-INQ-SUCCESS = 'Y'
             MOVE '0' TO INQCUST-INQ-FAIL-CD
             MOVE CUSTOMER-EYECATCHER OF OUTPUT-DATA
                TO INQCUST-EYE
             MOVE CUSTOMER-SORTCODE OF OUTPUT-DATA
                TO INQCUST-SCODE
             MOVE CUSTOMER-NUMBER OF OUTPUT-DATA
                TO INQCUST-CUSTNO
             MOVE CUSTOMER-NAME OF OUTPUT-DATA
                TO INQCUST-NAME
             MOVE CUSTOMER-ADDRESS OF OUTPUT-DATA
                TO INQCUST-ADDR
             MOVE CUSTOMER-EMAIL OF OUTPUT-DATA
                TO INQCUST-EMAIL
             MOVE CUSTOMER-DATE-OF-BIRTH OF OUTPUT-DATA
                TO INQCUST-DOB
             MOVE CUSTOMER-CREDIT-SCORE OF OUTPUT-DATA
                TO INQCUST-CREDIT-SCORE
             MOVE CUSTOMER-CS-REVIEW-DATE OF OUTPUT-DATA
                TO INQCUST-CS-REVIEW-DT
           END-IF.

           PERFORM GET-ME-OUT-OF-HERE.

       P999.
           EXIT.


       READ-CUSTOMER-NCS SECTION.
       RCN010.
      *
      *    Retrieve the last CUSTOMER number in use
      *
           PERFORM GET-LAST-CUSTOMER-DB2
           IF INQCUST-INQ-SUCCESS = 'Y'
             MOVE REQUIRED-CUST-NUMBER2 TO NCS-CUST-NO-VALUE
           END-IF.
       RCN999.
           EXIT.

       READ-CUSTOMER-DB2 SECTION.
       RCD010.
      *
      *    Read customer from DB2
      *
           INITIALIZE OUTPUT-DATA.
           INITIALIZE HOST-CUSTOMER-ROW.

           MOVE REQUIRED-SORT-CODE TO HV-CUSTOMER-SORTCODE.
           MOVE REQUIRED-CUST-NUMBER TO HV-CUSTOMER-NUMBER.

           EXEC SQL
              SELECT CUSTOMER_EYECATCHER,
                     CUSTOMER_SORTCODE,
                     CUSTOMER_NUMBER,
                     CUSTOMER_NAME,
                     CUSTOMER_ADDRESS,
                     CUSTOMER_EMAIL,
                     CUSTOMER_DATE_OF_BIRTH,
                     CUSTOMER_CREDIT_SCORE,
                     CUSTOMER_CS_REVIEW_DATE
                INTO :HV-CUSTOMER-EYECATCHER,
                     :HV-CUSTOMER-SORTCODE,
                     :HV-CUSTOMER-NUMBER,
                     :HV-CUSTOMER-NAME,
                     :HV-CUSTOMER-ADDRESS,
                     :HV-CUSTOMER-EMAIL,
                     :HV-CUSTOMER-DOB,
                     :HV-CUSTOMER-CREDIT-SCORE,
                     :HV-CUSTOMER-CS-REVIEW-DATE
                FROM CUSTOMER
               WHERE CUSTOMER_SORTCODE = :HV-CUSTOMER-SORTCODE
                 AND CUSTOMER_NUMBER = :HV-CUSTOMER-NUMBER
           END-EXEC.

      *
      *    Check if the SELECT was successful
      *
           IF SQLCODE = 0
              MOVE 'Y' TO EXIT-VSAM-READ
              MOVE 'Y' TO INQCUST-INQ-SUCCESS
              MOVE HV-CUSTOMER-EYECATCHER TO CUSTOMER-EYECATCHER
              MOVE HV-CUSTOMER-SORTCODE TO CUSTOMER-SORTCODE
              MOVE HV-CUSTOMER-NUMBER TO CUSTOMER-NUMBER
              MOVE HV-CUSTOMER-NAME TO CUSTOMER-NAME
              MOVE HV-CUSTOMER-ADDRESS TO CUSTOMER-ADDRESS
              MOVE HV-CUSTOMER-EMAIL TO CUSTOMER-EMAIL
              MOVE HV-CUSTOMER-DOB TO CUSTOMER-DATE-OF-BIRTH
              MOVE HV-CUSTOMER-CREDIT-SCORE TO CUSTOMER-CREDIT-SCORE
              MOVE HV-CUSTOMER-CS-REVIEW-DATE TO CUSTOMER-CS-REVIEW-DATE
              GO TO RCD999
           END-IF.

      * If the customer record was NOT found and the incoming
      * customer was 0000000000 (i.e. generate a random
      * customer number) then have another go at generating a
      * different random customer number and try reading that.
      *
           IF SQLCODE = 100 AND
              INQCUST-CUSTNO = 0000000000
            IF INQCUST-RETRY < 1000
                PERFORM GENERATE-RANDOM-CUSTOMER-AGAIN
                MOVE RANDOM-CUSTOMER TO REQUIRED-CUST-NUMBER
                GO TO RCD999
              ELSE
                MOVE 'Y' TO EXIT-VSAM-READ
                MOVE 'N' TO INQCUST-INQ-SUCCESS
                MOVE '1' TO INQCUST-INQ-FAIL-CD
                GO TO RCD999
              END-IF
           END-IF.

           IF SQLCODE = 100 AND
           INQCUST-CUSTNO = 9999999999 AND
           WS-V-RETRIED = 'N'
              PERFORM GET-LAST-CUSTOMER-DB2
      D       DISPLAY 'CUSTOMER NUMBER RETURNED FROM DB2 IS='
      D           NCS-CUST-NO-VALUE
              MOVE NCS-CUST-NO-VALUE TO REQUIRED-CUST-NUMBER
              MOVE 'Y' TO WS-V-RETRIED
              GO TO RCD999
           END-IF.

      *
      *    If the customer record was NOT found
      *    we must return the customer number with an initialised
      *    output record (this will indicate that the supplied
      *    customer number was a dud.
      *
           IF (SQLCODE = 100
                AND INQCUST-CUSTNO NOT = 9999999999)
                AND (SQLCODE = 100
                AND INQCUST-CUSTNO NOT = 0000000000)
              MOVE REQUIRED-CUST-NUMBER TO CUSTOMER-NUMBER
                                           OF OUTPUT-DATA
              MOVE 'Y' TO EXIT-VSAM-READ
              MOVE 'N' TO INQCUST-INQ-SUCCESS
              MOVE '1' TO INQCUST-INQ-FAIL-CD
              MOVE SPACES TO INQCUST-ADDR
              MOVE SPACES TO INQCUST-NAME
              GO TO RCD999
           END-IF.

      *
      *    If something else went wrong all we can do is report it
      *    and abend
      *
           IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
      *
      *       Set up the standard ABEND info before getting the applid,
      *       date/time etc. and linking to the Abend Handler
      *       program.
      *
              INITIALIZE ABNDINFO-REC
              MOVE SQLCODE TO ABND-SQLCODE

      *
      *       Get supplemental information
      *
              EXEC CICS ASSIGN APPLID(ABND-APPLID)
              END-EXEC

              MOVE EIBTASKN   TO ABND-TASKNO-KEY
              MOVE EIBTRNID   TO ABND-TRANID

              PERFORM POPULATE-TIME-DATE

              MOVE WS-ORIG-DATE TO ABND-DATE
              STRING WS-TIME-NOW-GRP-HH DELIMITED BY SIZE,
                    ':' DELIMITED BY SIZE,
                     WS-TIME-NOW-GRP-MM DELIMITED BY SIZE,
                     ':' DELIMITED BY SIZE,
                     WS-TIME-NOW-GRP-MM DELIMITED BY SIZE
                     INTO ABND-TIME
              END-STRING

              MOVE WS-U-TIME   TO ABND-UTIME-KEY
              MOVE 'CVR1'      TO ABND-CODE

              EXEC CICS ASSIGN PROGRAM(ABND-PROGRAM)
              END-EXEC

              MOVE SQLCODE TO SQLCODE-DISPLAY
              STRING 'RCD010 - CUSTOMER DB2 SELECT KEY='
                    DELIMITED BY SIZE,
                    CUSTOMER-KY DELIMITED SIZE,
                    ' GAVE SQLCODE=' DELIMITED BY SIZE,
                    SQLCODE-DISPLAY DELIMITED BY SIZE,
                    ' FOR CUSTOMER=' DELIMITED BY SIZE,
                    ABND-RESP2CODE DELIMITED BY SIZE
                    INTO ABND-FREEFORM
              END-STRING

              EXEC CICS LINK PROGRAM(WS-ABEND-PGM)
                        COMMAREA(ABNDINFO-REC)
              END-EXEC

              DISPLAY 'CUSTOMER DB2 SELECT KEY='
                  CUSTOMER-KY ' GAVE SQLCODE='
                  SQLCODE-DISPLAY

              IF WS-V-RETRIED = 'Y'
                 DISPLAY 'ON A RETRY'
              END-IF

              EXEC CICS ABEND ABCODE('CVR1')
                 CANCEL
              END-EXEC

           END-IF.

       RCD999.
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


       ABEND-HANDLING SECTION.
       AH010.
      *
      * How ABENDs are dealt with
      *
           EXEC CICS ASSIGN
              ABCODE(MY-ABEND-CODE)
           END-EXEC.

      *    Evaluate the Abend code that is returned
      *    for DB2 AD2Z ... provide some diagnostics,
      *    for VSAM RLS abends: AFCR, AFCS and AFCT record the
      *    abend as happening but do not abend ... leave this to
      *    CPSM WLM "Storm drain" (Abend probability) to handle.
      *    If not a "storm drain" ... take the abend afterwards
      *
           EVALUATE MY-ABEND-CODE


      *
      *      VSAM RLS abends, subject to CPSM WLM Storm Drain check
      *      if handled (as here) and Workload Abend Thresholds are
      *      set.
      *
             WHEN 'AFCR'
             WHEN 'AFCS'
             WHEN 'AFCT'
               MOVE 'Y' TO WS-STORM-DRAIN
               DISPLAY 'INQCUST: Check-For-Storm-Drain-VSAM: Storm '
                       'Drain condition (Abend ' MY-ABEND-CODE ') '
                       'has been met.'

               EXEC CICS SYNCPOINT ROLLBACK
                   RESP(WS-CICS-RESP)
                   RESP2(WS-CICS-RESP2)
               END-EXEC

               IF WS-CICS-RESP NOT = DFHRESP(NORMAL)

      *
      *          Preserve the RESP and RESP2, then set up the
      *          standard ABEND info before getting the applid,
      *          date/time etc. and linking to the Abend Handler
      *          program.
      *
                 INITIALIZE ABNDINFO-REC
                 MOVE EIBRESP    TO ABND-RESPCODE
                 MOVE EIBRESP2   TO ABND-RESP2CODE
      *
      *          Get supplemental information
      *
                 EXEC CICS ASSIGN APPLID(ABND-APPLID)
                 END-EXEC

                 MOVE EIBTASKN   TO ABND-TASKNO-KEY
                 MOVE EIBTRNID   TO ABND-TRANID

                 PERFORM POPULATE-TIME-DATE

                 MOVE WS-ORIG-DATE TO ABND-DATE
                 STRING WS-TIME-NOW-GRP-HH DELIMITED BY SIZE,
                       ':' DELIMITED BY SIZE,
                        WS-TIME-NOW-GRP-MM DELIMITED BY SIZE,
                        ':' DELIMITED BY SIZE,
                        WS-TIME-NOW-GRP-MM DELIMITED BY SIZE
                        INTO ABND-TIME
                 END-STRING

                 MOVE WS-U-TIME   TO ABND-UTIME-KEY
                 MOVE 'HROL'      TO ABND-CODE

                 EXEC CICS ASSIGN PROGRAM(ABND-PROGRAM)
                 END-EXEC

                 MOVE 0 TO ABND-SQLCODE

                 STRING 'AH010 -Unable to perform SYNCPOINT ROLLBACK.'
                       DELIMITED BY SIZE,
                       ' Possible integrity issue following VSAM RLS '
                       DELIMITED BY SIZE,
                       ' abend.' DELIMITED BY SIZE,
                       ' EIBRESP=' DELIMITED BY SIZE,
                       ABND-RESPCODE DELIMITED BY SIZE,
                       ' RESP2=' DELIMITED BY SIZE,
                       ABND-RESP2CODE DELIMITED BY SIZE
                       INTO ABND-FREEFORM
                 END-STRING

                 EXEC CICS LINK PROGRAM(WS-ABEND-PGM)
                           COMMAREA(ABNDINFO-REC)
                 END-EXEC


                 DISPLAY 'INQCUST: Unable to perform Synpoint Rollback.'
                 ' Possible Integrity issue following VSAM RLS abend'
                 ' RESP CODE=' WS-CICS-RESP ' RESP2 CODE=' WS-CICS-RESP2

                  EXEC CICS ABEND
                     ABCODE ('HROL')
                     CANCEL
                  END-EXEC

               END-IF

               MOVE 'N' TO INQCUST-INQ-SUCCESS
               MOVE '2' TO INQCUST-INQ-FAIL-CD

               EXEC CICS RETURN
               END-EXEC

           END-EVALUATE.

           IF WS-STORM-DRAIN = 'N'

              EXEC CICS ABEND ABCODE( MY-ABEND-CODE)
              NODUMP
              END-EXEC

           END-IF.

       AH999.
           EXIT.


       GET-LAST-CUSTOMER-DB2 SECTION.
       GLCD010.
      *
      *    Retrieves the last customer number in use from DB2
      *    using ORDER BY DESC and FETCH FIRST 1 ROW
      *
           INITIALIZE OUTPUT-DATA.
           INITIALIZE HOST-CUSTOMER-ROW.

           MOVE REQUIRED-SORT-CODE2 TO HV-CUSTOMER-SORTCODE.

           EXEC SQL
              SELECT CUSTOMER_EYECATCHER,
                     CUSTOMER_SORTCODE,
                     CUSTOMER_NUMBER,
                     CUSTOMER_NAME,
                     CUSTOMER_ADDRESS,
                     CUSTOMER_EMAIL,
                     CUSTOMER_DATE_OF_BIRTH,
                     CUSTOMER_CREDIT_SCORE,
                     CUSTOMER_CS_REVIEW_DATE
                INTO :HV-CUSTOMER-EYECATCHER,
                     :HV-CUSTOMER-SORTCODE,
                     :HV-CUSTOMER-NUMBER,
                     :HV-CUSTOMER-NAME,
                     :HV-CUSTOMER-ADDRESS,
                     :HV-CUSTOMER-EMAIL,
                     :HV-CUSTOMER-DOB,
                     :HV-CUSTOMER-CREDIT-SCORE,
                     :HV-CUSTOMER-CS-REVIEW-DATE
                FROM CUSTOMER
               WHERE CUSTOMER_SORTCODE = :HV-CUSTOMER-SORTCODE
               ORDER BY CUSTOMER_NUMBER DESC
               FETCH FIRST 1 ROW ONLY
           END-EXEC.

           IF SQLCODE = 0
              MOVE 'Y' TO INQCUST-INQ-SUCCESS
              MOVE HV-CUSTOMER-NUMBER TO REQUIRED-CUST-NUMBER2
              GO TO GLCDE999
           END-IF.

           IF SQLCODE = 100
              MOVE 'N' TO INQCUST-INQ-SUCCESS
              MOVE '9' TO INQCUST-INQ-FAIL-CD
              GO TO GLCDE999
           END-IF.

      *
      *    Database error
      *
           MOVE 'N' TO INQCUST-INQ-SUCCESS
           MOVE '9' TO INQCUST-INQ-FAIL-CD.

       GLCDE999.
           EXIT.

       GLCV010.
      *
      *    Old VSAM section - kept for compatibility
      *    Now redirects to DB2 version
      *
           PERFORM GET-LAST-CUSTOMER-DB2.
           MOVE 'Y' TO INQCUST-INQ-SUCCESS.

       GLCVE999.
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

      *
      * Generate a random customer number
      *
       GENERATE-RANDOM-CUSTOMER SECTION.
       GRC010.
           MOVE ZERO TO INQCUST-RETRY.
           COMPUTE RANDOM-CUSTOMER = ((NCS-CUST-NO-VALUE - 1)
                                     * FUNCTION RANDOM(EIBTASKN)) + 1.
       GRC999.
           EXIT.
      *
      * Generate a random customer number
      *
       GENERATE-RANDOM-CUSTOMER-AGAIN SECTION.
       GRCA10.
           ADD 1 TO INQCUST-RETRY GIVING INQCUST-RETRY.
           COMPUTE RANDOM-CUSTOMER = ((NCS-CUST-NO-VALUE - 1)
                                                * FUNCTION RANDOM) + 1.
        GRCA99.
            EXIT.
