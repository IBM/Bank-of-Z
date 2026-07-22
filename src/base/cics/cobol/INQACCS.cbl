       CBL CICS('SP,EDF,DLI')
       CBL SQL
      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      *                                                                *
      ******************************************************************
      ******************************************************************
      * This program retrieves all accounts from the datastore,
      * up to a maximum of 20, returning them in the COMMAREA.
      ******************************************************************

       IDENTIFICATION DIVISION.
       PROGRAM-ID. INQACCS.
       AUTHOR. Bank of Z.


       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER.  IBM-370.
       OBJECT-COMPUTER.  IBM-370.

       INPUT-OUTPUT SECTION.

       DATA DIVISION.
       FILE SECTION.

       WORKING-STORAGE SECTION.

       COPY SORTCODE.


      *
      * Get the ACCOUNT DB2 copybook
      *
           EXEC SQL
              INCLUDE ACCDB2
           END-EXEC.

      * ACCOUNT Host variables for DB2
       01 HOST-ACCOUNT-ROW.
          03 HV-ACCOUNT-EYECATCHER        PIC X(4).
          03 HV-ACCOUNT-CUST-NO           PIC X(10).
          03 HV-ACCOUNT-SORTCODE          PIC X(6).
          03 HV-ACCOUNT-ACC-NO            PIC X(8).
          03 HV-ACCOUNT-ACC-TYPE          PIC X(8).
          03 HV-ACCOUNT-INT-RATE          PIC S9(4)V99 COMP-3.
          03 HV-ACCOUNT-OPENED            PIC X(10).
          03 HV-ACCOUNT-OVERDRAFT-LIM     PIC S9(9) COMP.
          03 HV-ACCOUNT-LAST-STMT         PIC X(10).
          03 HV-ACCOUNT-NEXT-STMT         PIC X(10).
          03 HV-ACCOUNT-AVAIL-BAL         PIC S9(10)V99 COMP-3.
          03 HV-ACCOUNT-ACTUAL-BAL        PIC S9(10)V99 COMP-3.

       01 EIBRCODE-NICE.
          03 EIBRCODE-FIRST               PIC X.
          03 EIBRCODE-SECOND              PIC X.
          03 EIBRCODE-THIRD               PIC X.
          03 EIBRCODE-FOURTH              PIC X.
          03 EIBRCODE-FIFTH               PIC X.
          03 EIBRCODE-SIXTH               PIC X.

      * Pull in the SQL COMMAREA
        EXEC SQL
          INCLUDE SQLCA
        END-EXEC.


      * Declare the CURSOR for ACCOUNT table - all accounts
           EXEC SQL DECLARE ACC-ALL-CURSOR CURSOR FOR
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
                     FROM ACCOUNT
                     WHERE ACCOUNT_SORTCODE =
                     :HV-ACCOUNT-SORTCODE
                     FOR FETCH ONLY
           END-EXEC.


       01 WS-CICS-WORK-AREA.
          03 WS-CICS-RESP                 PIC S9(8) COMP.
          03 WS-CICS-RESP2                PIC S9(8) COMP.

       01 DB2-DATE-REFORMAT.
          03 DB2-DATE-REF-YR              PIC 9(4).
          03 FILLER                       PIC X.
          03 DB2-DATE-REF-MNTH            PIC 99.
          03 FILLER                       PIC X.
          03 DB2-DATE-REF-DAY             PIC 99.

       01 SQLCODE-DISPLAY                 PIC S9(8) DISPLAY
                                          SIGN LEADING SEPARATE.

       01 MY-ABEND-CODE                   PIC XXXX.

       01 WS-STORM-DRAIN                  PIC X VALUE 'N'.

       01 STORM-DRAIN-CONDITION           PIC X(20).

       01 WS-U-TIME                       PIC S9(15) COMP-3.
       01 WS-ORIG-DATE                    PIC X(10).
       01 WS-ORIG-DATE-GRP REDEFINES WS-ORIG-DATE.
          03 WS-ORIG-DATE-DD                 PIC 99.
          03 FILLER                          PIC X.
          03 WS-ORIG-DATE-MM                 PIC 99.
          03 FILLER                          PIC X.
          03 WS-ORIG-DATE-YYYY               PIC 9999.

       01 WS-TIME-DATA.
           03 WS-TIME-NOW                 PIC 9(6).
           03 WS-TIME-NOW-GRP REDEFINES WS-TIME-NOW.
              05 WS-TIME-NOW-GRP-HH          PIC 99.
              05 WS-TIME-NOW-GRP-MM          PIC 99.
              05 WS-TIME-NOW-GRP-SS          PIC 99.

       01 WS-ABEND-PGM                       PIC X(8) VALUE 'ABNDPROC'.

       01 ABNDINFO-REC.
           COPY ABNDINFO.

       LINKAGE SECTION.
       01 DFHCOMMAREA.
          COPY INQACCS.

       PROCEDURE DIVISION USING DFHCOMMAREA.
       PREMIERE SECTION.
       A010.
           MOVE 'N' TO COMM-SUCCESS
           MOVE '0' TO COMM-FAIL-CODE

           EXEC CICS HANDLE ABEND
              LABEL(ABEND-HANDLING)
           END-EXEC.

           MOVE SORTCODE TO HV-ACCOUNT-SORTCODE.

           PERFORM READ-ACCOUNT-DB2.

           PERFORM GET-ME-OUT-OF-HERE.

       A999.
           EXIT.


       READ-ACCOUNT-DB2 SECTION.
       RAD010.

           EXEC SQL OPEN
              ACC-ALL-CURSOR
           END-EXEC.

           MOVE SQLCODE TO SQLCODE-DISPLAY.

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO SQLCODE-DISPLAY

              PERFORM CHECK-FOR-STORM-DRAIN-DB2

              MOVE 'N'  TO COMM-SUCCESS
              MOVE '2'  TO COMM-FAIL-CODE
              MOVE ZERO TO NUMBER-OF-ACCOUNTS

              EXEC CICS SYNCPOINT ROLLBACK
                RESP(WS-CICS-RESP)
                RESP2(WS-CICS-RESP2)
              END-EXEC

              GO TO RAD999
           END-IF.

           PERFORM FETCH-DATA.

           EXEC SQL CLOSE
                          ACC-ALL-CURSOR
           END-EXEC.

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO SQLCODE-DISPLAY
              DISPLAY 'Failure when attempting to close the DB2 CURSOR'
                  ' ACC-ALL-CURSOR. With SQL code='
                  SQLCODE-DISPLAY

              PERFORM CHECK-FOR-STORM-DRAIN-DB2

              MOVE 'N' TO COMM-SUCCESS
              MOVE '4' TO COMM-FAIL-CODE

              EXEC CICS SYNCPOINT
                 ROLLBACK
                 RESP(WS-CICS-RESP)
                 RESP2(WS-CICS-RESP2)
              END-EXEC

              GO TO RAD999
           END-IF.

           MOVE 'Y' TO COMM-SUCCESS.

       RAD999.
           EXIT.


       FETCH-DATA SECTION.
       FD010.
           MOVE ZERO TO NUMBER-OF-ACCOUNTS.

           PERFORM UNTIL SQLCODE NOT = 0 OR
           NUMBER-OF-ACCOUNTS = 20

              EXEC SQL FETCH FROM ACC-ALL-CURSOR
              INTO :HV-ACCOUNT-EYECATCHER,
                   :HV-ACCOUNT-CUST-NO,
                   :HV-ACCOUNT-SORTCODE,
                   :HV-ACCOUNT-ACC-NO,
                   :HV-ACCOUNT-ACC-TYPE,
                   :HV-ACCOUNT-INT-RATE,
                   :HV-ACCOUNT-OPENED,
                   :HV-ACCOUNT-OVERDRAFT-LIM,
                   :HV-ACCOUNT-LAST-STMT,
                   :HV-ACCOUNT-NEXT-STMT,
                   :HV-ACCOUNT-AVAIL-BAL,
                   :HV-ACCOUNT-ACTUAL-BAL
              END-EXEC

              IF SQLCODE = +100
                  MOVE 'Y' TO COMM-SUCCESS
                  GO TO FD999
              END-IF

              IF SQLCODE NOT = 0
                 MOVE SQLCODE TO SQLCODE-DISPLAY

                 DISPLAY 'Failure when attempting to FETCH from the'
                    ' DB2 CURSOR ACC-ALL-CURSOR. With SQL code='
                    SQLCODE-DISPLAY

                 PERFORM CHECK-FOR-STORM-DRAIN-DB2

                 MOVE 'N'  TO COMM-SUCCESS
                 MOVE ZERO TO NUMBER-OF-ACCOUNTS
                 MOVE '3' TO COMM-FAIL-CODE

                 EXEC CICS SYNCPOINT
                    ROLLBACK
                    RESP(WS-CICS-RESP)
                    RESP2(WS-CICS-RESP2)
                 END-EXEC

                 GO TO FD999

              END-IF

              ADD 1 TO NUMBER-OF-ACCOUNTS GIVING NUMBER-OF-ACCOUNTS

              MOVE HV-ACCOUNT-EYECATCHER
                 TO COMM-EYE(NUMBER-OF-ACCOUNTS)
              MOVE HV-ACCOUNT-CUST-NO
                  TO COMM-CUSTNO(NUMBER-OF-ACCOUNTS)
              MOVE HV-ACCOUNT-SORTCODE
                  TO COMM-SCODE(NUMBER-OF-ACCOUNTS)
              MOVE HV-ACCOUNT-ACC-NO
                  TO COMM-ACCNO(NUMBER-OF-ACCOUNTS)
              MOVE HV-ACCOUNT-ACC-TYPE
                  TO COMM-ACC-TYPE(NUMBER-OF-ACCOUNTS)
              MOVE HV-ACCOUNT-INT-RATE
                  TO COMM-INT-RATE(NUMBER-OF-ACCOUNTS)
              MOVE HV-ACCOUNT-OPENED TO DB2-DATE-REFORMAT

              STRING DB2-DATE-REF-DAY
                DB2-DATE-REF-MNTH
                DB2-DATE-REF-YR
                DELIMITED BY SIZE
                INTO COMM-OPENED(NUMBER-OF-ACCOUNTS)
              END-STRING

              MOVE HV-ACCOUNT-OVERDRAFT-LIM
                 TO COMM-OVERDRAFT(NUMBER-OF-ACCOUNTS)
              MOVE HV-ACCOUNT-LAST-STMT TO DB2-DATE-REFORMAT

              STRING DB2-DATE-REF-DAY
                 DB2-DATE-REF-MNTH
                 DB2-DATE-REF-YR
                 DELIMITED BY SIZE
                 INTO COMM-LAST-STMT-DT(NUMBER-OF-ACCOUNTS)
              END-STRING

              MOVE HV-ACCOUNT-NEXT-STMT TO DB2-DATE-REFORMAT

              STRING DB2-DATE-REF-DAY
                 DB2-DATE-REF-MNTH
                 DB2-DATE-REF-YR
                 DELIMITED BY SIZE
                 INTO COMM-NEXT-STMT-DT(NUMBER-OF-ACCOUNTS)
              END-STRING

              MOVE HV-ACCOUNT-ACTUAL-BAL
                 TO COMM-ACTUAL-BAL(NUMBER-OF-ACCOUNTS)
              MOVE HV-ACCOUNT-AVAIL-BAL
                 TO COMM-AVAIL-BAL(NUMBER-OF-ACCOUNTS)

           END-PERFORM.

       FD999.
           EXIT.

       GET-ME-OUT-OF-HERE SECTION.
       GMOFH010.
           EXEC CICS RETURN
           END-EXEC.

           GOBACK.

       GMOFH999.
           EXIT.


       CHECK-FOR-STORM-DRAIN-DB2 SECTION.
       CFSDD010.

           EVALUATE SQLCODE

              WHEN 923
                 MOVE 'DB2 Connection lost ' TO STORM-DRAIN-CONDITION

              WHEN OTHER
                 MOVE 'Not Storm Drain     ' TO STORM-DRAIN-CONDITION

           END-EVALUATE.

           IF STORM-DRAIN-CONDITION NOT EQUAL 'Not Storm Drain     '
              DISPLAY 'INQACCS: Check-For-Storm-Drain-DB2: Storm '
                      'Drain condition (' STORM-DRAIN-CONDITION ') '
                      'has been met (' SQLCODE-DISPLAY ').'
           ELSE
              CONTINUE
           END-IF.

       CFSDD999.
           EXIT.


       ABEND-HANDLING SECTION.
       AH010.

           EXEC CICS ASSIGN
              ABCODE(MY-ABEND-CODE)
           END-EXEC.

           EVALUATE MY-ABEND-CODE

              WHEN 'AD2Z'
                 MOVE SQLCODE TO SQLCODE-DISPLAY
                 DISPLAY 'DB2 DEADLOCK DETECTED IN INQACCS, SQLCODE='
                    SQLCODE-DISPLAY

              WHEN 'AFCR'

              WHEN 'AFCS'

              WHEN 'AFCT'
                 MOVE 'Y' TO WS-STORM-DRAIN

                 EXEC CICS SYNCPOINT ROLLBACK
                    RESP(WS-CICS-RESP)
                    RESP2(WS-CICS-RESP2)
                 END-EXEC

                 MOVE 'N' TO COMM-SUCCESS

                 EXEC CICS RETURN
                 END-EXEC

           END-EVALUATE.

           IF WS-STORM-DRAIN = 'N'
              EXEC CICS ABEND
                 ABCODE( MY-ABEND-CODE)
                 NODUMP
                 CANCEL
              END-EXEC
           END-IF.

       AH999.
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
