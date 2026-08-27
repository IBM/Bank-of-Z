       CBL CICS('SP,EDF')
      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      ******************************************************************
      ******************************************************************
      *  CRCCVERI - Credit Check Verification                         *
      *                                                                *
      *  Called by CRECUST via EXEC CICS LINK.                        *
      *  Dispatches async credit check transactions OCR1-OCR5,        *
      *  waits 3 seconds, fetches results, and returns the            *
      *  averaged credit score and review date.                       *
      *                                                                *
      *  To replace with an API-based credit check in future:         *
      *  modify only this program. CRECUST does not change.           *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CRCCVERI.
       AUTHOR. Jon Collett.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER.  IBM-370.
       OBJECT-COMPUTER.  IBM-370.

       INPUT-OUTPUT SECTION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-CICS-WORK-AREA.
          05 WS-CICS-RESP               PIC S9(8) COMP.
          05 WS-CICS-RESP2              PIC S9(8) COMP.

       01 WS-CC-CNT                     PIC 9         VALUE 0.
       01 WS-FINISHED-FETCHING          PIC X         VALUE 'N'.
       01 WS-RETRIEVED-CNT              PIC 9         VALUE 0.
       01 WS-CHANNEL-NAME               PIC X(16)     VALUE SPACES.
       01 WS-ACTUAL-CS-SCR              PIC 9(6)      VALUE 0.
       01 WS-TOTAL-CS-SCR               PIC 9(6)      VALUE 0.

       01 WS-CHILD-TOKENS.
          03 WS-ANY-CHILD-TKN           PIC X(16).
          03 WS-ANY-CHILD-FETCH-TKN     PIC X(16).

       01 WS-ANY-CHILD-FETCH-CHAN       PIC X(16).
       01 WS-ANY-CHILD-FETCH-ABCODE     PIC X(4)      VALUE SPACES.
       01 WS-CHILD-ISSUED-CNT           PIC 9         VALUE 0.

       01 WS-CHILD-ARRAY.
          03 WS-CHILD-DETAILS OCCURS 9 TIMES.
             05 WS-CHILD-CHAN           PIC X(16).
             05 WS-CHILD-TKN            PIC X(16).

       01 WS-CHILD-RECEIVED-CNT         PIC 9         VALUE 0.
       01 WS-CHILD-FETCH-COMPST         PIC S9(8) COMP.

       01 WS-CHILD-DATA.
          03 WS-CHILD-CUSTOMER-RECORD.
             05 WS-CHILD-EYECATCHER        PIC X(4).
             05 WS-CHILD-KEY.
                07 WS-CHILD-SORTCODE       PIC 9(6) DISPLAY.
                07 WS-CHILD-NUMBER         PIC 9(10) DISPLAY.
             05 WS-CHILD-NAME.
                07 WS-CHILD-TITLE          PIC X(10).
                07 WS-CHILD-FIRST-NAME     PIC X(50).
                07 WS-CHILD-LAST-NAME      PIC X(50).
             05 WS-CHILD-DOB.
                07 WS-CHILD-DOB-DAY        PIC 99 DISPLAY.
                07 WS-CHILD-DOB-MONTH      PIC 99 DISPLAY.
                07 WS-CHILD-DOB-YEAR       PIC 9999 DISPLAY.
             05 WS-CHILD-PHONE             PIC X(20).
             05 WS-CHILD-ADDRESS.
                07 WS-CHILD-ADDR-LINE1     PIC X(50).
                07 WS-CHILD-ADDR-LINE2     PIC X(50).
                07 WS-CHILD-CITY           PIC X(50).
                07 WS-CHILD-POSTCODE       PIC X(10).
                07 WS-CHILD-COUNTRY        PIC X(50).
             05 WS-CHILD-STATUS            PIC X(10).
             05 WS-CHILD-CREATED-DATE.
                07 WS-CHILD-CREATED-DAY    PIC 99 DISPLAY.
                07 WS-CHILD-CREATED-MONTH  PIC 99 DISPLAY.
                07 WS-CHILD-CREATED-YEAR   PIC 9999 DISPLAY.
             05 WS-CHILD-CREDIT-SCORE      PIC 999.
             05 WS-CHILD-CS-REVIEW-DATE.
                07 WS-CHILD-CS-REVIEW-DAY  PIC 99 DISPLAY.
                07 WS-CHILD-CS-REVIEW-MONTH PIC 99 DISPLAY.
                07 WS-CHILD-CS-REVIEW-YEAR PIC 9999 DISPLAY.
             05 WS-CHILD-SUCCESS           PIC X.
             05 WS-CHILD-FAIL-CODE         PIC X.

       01 WS-CONTAINER-NAME             PIC X(16)     VALUE SPACES.
       01 WS-CHILD-CONTAINER-LEN        PIC S9(8) COMP
                                                      VALUE 0.
       01 WS-RUN-TRANSID                PIC X(4)      VALUE SPACES.
       01 WS-PUT-CONT-NAME              PIC X(16)     VALUE SPACES.
       01 WS-PUT-CONT-LEN               PIC S9(8) COMP
                                                      VALUE 0.

       01 WS-CURRENT-DATE-DATA.
          03 WS-CURRENT-DATE.
             05 WS-CURRENT-YYYY         PIC 9(4).
             05 WS-CURRENT-MM           PIC 99.
             05 WS-CURRENT-DD           PIC 99.
          03 WS-CURRENT-TIME.
             05 WS-CURRENT-HOURS        PIC 99.
             05 WS-CURRENT-MINS         PIC 99.
             05 WS-CURRENT-SECS         PIC 99.
             05 WS-CURRENT-MILLI        PIC 99.
          03 WS-DIFFERENCE-FROM-GMT     PIC S9(4).

       01 WS-CURRENT-DATE-9             PIC 9(8)      VALUE 0.
       01 WS-TODAY-INT                  PIC 9(8)      VALUE 0.
       01 WS-REVIEW-DATE-ADD            PIC 99        VALUE 0.
       01 WS-NEW-REVIEW-DATE-INT        PIC 9(8)      VALUE 0.
       01 WS-NEW-REVIEW-YYYYMMDD        PIC 9(8)      VALUE 0.
       01 WS-SEED                       PIC S9(15) COMP.

       LINKAGE SECTION.
       01 DFHCOMMAREA.
           COPY CRCCVERI.

       PROCEDURE DIVISION USING DFHCOMMAREA.
       PREMIERE SECTION.
       P010.
      *
      *    Populate containers and dispatch OCR1-OCR5 asynchronously
      *
           MOVE 'CIPCREDCHANN    ' TO WS-CHANNEL-NAME.
           MOVE 0 TO WS-CHILD-ISSUED-CNT.

           COMPUTE WS-PUT-CONT-LEN = LENGTH OF DFHCOMMAREA.

           PERFORM VARYING WS-CC-CNT FROM 1 BY 1
              UNTIL WS-CC-CNT > 5

                   STRING 'OCR' DELIMITED BY SIZE,
                          WS-CC-CNT DELIMITED BY SIZE
                      INTO WS-RUN-TRANSID
                   END-STRING

                   EVALUATE WS-CC-CNT
                   WHEN 1  MOVE 'CIPA            ' TO WS-PUT-CONT-NAME
                   WHEN 2  MOVE 'CIPB            ' TO WS-PUT-CONT-NAME
                   WHEN 3  MOVE 'CIPC            ' TO WS-PUT-CONT-NAME
                   WHEN 4  MOVE 'CIPD            ' TO WS-PUT-CONT-NAME
                   WHEN 5  MOVE 'CIPE            ' TO WS-PUT-CONT-NAME
                   WHEN 6  MOVE 'CIPF            ' TO WS-PUT-CONT-NAME
                   WHEN 7  MOVE 'CIPG            ' TO WS-PUT-CONT-NAME
                   WHEN 8  MOVE 'CIPH            ' TO WS-PUT-CONT-NAME
                   WHEN 9  MOVE 'CIPI            ' TO WS-PUT-CONT-NAME
                   END-EVALUATE

                   EXEC CICS PUT CONTAINER(WS-PUT-CONT-NAME)
                        FROM(DFHCOMMAREA)
                        FLENGTH(WS-PUT-CONT-LEN)
                        CHANNEL(WS-CHANNEL-NAME)
                        RESP(WS-CICS-RESP)
                        RESP2(WS-CICS-RESP2)
                   END-EXEC

                   IF WS-CICS-RESP NOT = DFHRESP(NORMAL)
                      MOVE 'N'  TO CCVERI-SUCCESS
                      MOVE 'A'  TO CCVERI-FAIL-CODE
                      GOBACK
                   END-IF

                   EXEC CICS RUN TRANSID(WS-RUN-TRANSID)
                        CHANNEL(WS-CHANNEL-NAME)
                        CHILD(WS-ANY-CHILD-TKN)
                        RESP(WS-CICS-RESP)
                        RESP2(WS-CICS-RESP2)
                   END-EXEC

                   IF WS-CICS-RESP NOT = DFHRESP(NORMAL)
                      MOVE 'N'  TO CCVERI-SUCCESS
                      MOVE 'B'  TO CCVERI-FAIL-CODE
                      GOBACK
                   END-IF

                   ADD 1 TO WS-CHILD-ISSUED-CNT
                   MOVE WS-CHANNEL-NAME
                      TO WS-CHILD-CHAN(WS-CHILD-ISSUED-CNT)
                   MOVE WS-ANY-CHILD-TKN
                      TO WS-CHILD-TKN(WS-CHILD-ISSUED-CNT)

           END-PERFORM.

      *
      *    Wait 3 seconds then fetch available responses
      *
           EXEC CICS DELAY
                FOR SECONDS(3)
           END-EXEC.

           MOVE 'N' TO WS-FINISHED-FETCHING.
           MOVE 0   TO WS-RETRIEVED-CNT.
           MOVE 0   TO WS-TOTAL-CS-SCR.

           PERFORM UNTIL WS-FINISHED-FETCHING = 'Y'

                   MOVE SPACES TO WS-ANY-CHILD-FETCH-ABCODE

                   EXEC CICS FETCH ANY(WS-ANY-CHILD-FETCH-TKN)
                        CHANNEL(WS-ANY-CHILD-FETCH-CHAN)
                        NOSUSPEND
                        COMPSTATUS(WS-CHILD-FETCH-COMPST)
                        ABCODE(WS-ANY-CHILD-FETCH-ABCODE)
                        RESP(WS-CICS-RESP)
                        RESP2(WS-CICS-RESP2)
                   END-EXEC

                   IF WS-CICS-RESP NOT = DFHRESP(NORMAL)

                      IF WS-CICS-RESP = DFHRESP(NOTFINISHED) AND
                         WS-CICS-RESP2 = 52

                         IF WS-RETRIEVED-CNT = 0
                            MOVE 'Y' TO WS-FINISHED-FETCHING
                            MOVE 0   TO CCVERI-CREDIT-SCORE
                            MOVE 'N' TO CCVERI-SUCCESS
                            MOVE 'C' TO CCVERI-FAIL-CODE
                            GOBACK
                         ELSE
                            MOVE 'Y' TO WS-FINISHED-FETCHING
                            PERFORM COMPUTE-AVERAGE-AND-REVIEW-DATE
                         END-IF
                      END-IF

                      IF WS-CICS-RESP = DFHRESP(INVREQ) AND
                         WS-CICS-RESP2 = 1
                         MOVE 0   TO CCVERI-CREDIT-SCORE
                         MOVE 'N' TO CCVERI-SUCCESS
                         MOVE 'D' TO CCVERI-FAIL-CODE
                         GOBACK
                      END-IF

                      IF WS-CICS-RESP = DFHRESP(NOTFND) AND
                         WS-CICS-RESP2 = 1
                         IF WS-RETRIEVED-CNT = 0
                            MOVE 'Y' TO WS-FINISHED-FETCHING
                            MOVE 0   TO CCVERI-CREDIT-SCORE
                            MOVE 'N' TO CCVERI-SUCCESS
                            MOVE 'C' TO CCVERI-FAIL-CODE
                            GOBACK
                         ELSE
                            MOVE 'Y' TO WS-FINISHED-FETCHING
                            PERFORM COMPUTE-AVERAGE-AND-REVIEW-DATE
                         END-IF
                      END-IF

                   ELSE

                      EVALUATE WS-CHILD-FETCH-COMPST

                      WHEN DFHVALUE(NORMAL)
                           EVALUATE WS-ANY-CHILD-FETCH-TKN
                           WHEN WS-CHILD-TKN(1)
                              MOVE 'CIPA            ' TO WS-CONTAINER-NAME
                           WHEN WS-CHILD-TKN(2)
                              MOVE 'CIPB            ' TO WS-CONTAINER-NAME
                           WHEN WS-CHILD-TKN(3)
                              MOVE 'CIPC            ' TO WS-CONTAINER-NAME
                           WHEN WS-CHILD-TKN(4)
                              MOVE 'CIPD            ' TO WS-CONTAINER-NAME
                           WHEN WS-CHILD-TKN(5)
                              MOVE 'CIPE            ' TO WS-CONTAINER-NAME
                           WHEN WS-CHILD-TKN(6)
                              MOVE 'CIPF            ' TO WS-CONTAINER-NAME
                           WHEN WS-CHILD-TKN(7)
                              MOVE 'CIPG            ' TO WS-CONTAINER-NAME
                           WHEN WS-CHILD-TKN(8)
                              MOVE 'CIPH            ' TO WS-CONTAINER-NAME
                           WHEN WS-CHILD-TKN(9)
                              MOVE 'CIPI            ' TO WS-CONTAINER-NAME
                           END-EVALUATE

                           COMPUTE WS-CHILD-CONTAINER-LEN =
                              LENGTH OF WS-CHILD-DATA

                           EXEC CICS GET CONTAINER(WS-CONTAINER-NAME)
                                CHANNEL(WS-ANY-CHILD-FETCH-CHAN)
                                INTO(WS-CHILD-DATA)
                                FLENGTH(WS-CHILD-CONTAINER-LEN)
                                RESP(WS-CICS-RESP)
                                RESP2(WS-CICS-RESP2)
                           END-EXEC

                           IF WS-CICS-RESP NOT = DFHRESP(NORMAL)
                              MOVE 0   TO CCVERI-CREDIT-SCORE
                              MOVE 'N' TO CCVERI-SUCCESS
                              MOVE 'E' TO CCVERI-FAIL-CODE
                              GOBACK
                           END-IF

                           COMPUTE WS-RETRIEVED-CNT = WS-RETRIEVED-CNT + 1
                           COMPUTE WS-TOTAL-CS-SCR  =
                              WS-TOTAL-CS-SCR + WS-CHILD-CREDIT-SCORE

                      WHEN DFHVALUE(ABEND)
                           MOVE 0   TO CCVERI-CREDIT-SCORE
                           MOVE 'N' TO CCVERI-SUCCESS
                           MOVE 'F' TO CCVERI-FAIL-CODE
                           GOBACK

                      WHEN DFHVALUE(SECERROR)
                           MOVE 0   TO CCVERI-CREDIT-SCORE
                           MOVE 'N' TO CCVERI-SUCCESS
                           MOVE 'G' TO CCVERI-FAIL-CODE
                           GOBACK

                      WHEN OTHER
                           MOVE 0   TO CCVERI-CREDIT-SCORE
                           MOVE 'N' TO CCVERI-SUCCESS
                           MOVE 'H' TO CCVERI-FAIL-CODE
                           GOBACK

                      END-EVALUATE

                   END-IF

           END-PERFORM.

           MOVE 'Y' TO CCVERI-SUCCESS.

       P999.
           EXIT.


       COMPUTE-AVERAGE-AND-REVIEW-DATE SECTION.
       CARD010.
      *
      *    Average the credit scores from responding agencies
      *    and set a random review date within the next 21 days.
      *
           COMPUTE WS-ACTUAL-CS-SCR = WS-TOTAL-CS-SCR / WS-RETRIEVED-CNT
           MOVE WS-ACTUAL-CS-SCR TO CCVERI-CREDIT-SCORE

           MOVE FUNCTION CURRENT-DATE TO WS-CURRENT-DATE-DATA
           MOVE WS-CURRENT-DATE-DATA(1:8) TO WS-CURRENT-DATE-9
           COMPUTE WS-TODAY-INT =
              FUNCTION INTEGER-OF-DATE(WS-CURRENT-DATE-9)

           MOVE EIBTASKN TO WS-SEED
           COMPUTE WS-REVIEW-DATE-ADD =
              ((21 - 1) * FUNCTION RANDOM(WS-SEED)) + 1
           COMPUTE WS-NEW-REVIEW-DATE-INT =
              WS-TODAY-INT + WS-REVIEW-DATE-ADD
           COMPUTE WS-NEW-REVIEW-YYYYMMDD =
              FUNCTION DATE-OF-INTEGER(WS-NEW-REVIEW-DATE-INT)

           MOVE WS-NEW-REVIEW-YYYYMMDD(1:4)
              TO CCVERI-CS-REVIEW-DATE(5:4)
           MOVE WS-NEW-REVIEW-YYYYMMDD(5:2)
              TO CCVERI-CS-REVIEW-DATE(3:2)
           MOVE WS-NEW-REVIEW-YYYYMMDD(7:2)
              TO CCVERI-CS-REVIEW-DATE(1:2)

       CARD999.
           EXIT.
