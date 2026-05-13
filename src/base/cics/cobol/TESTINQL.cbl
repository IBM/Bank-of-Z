       CBL CICS('SP,EDF')
      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2026                                      *
      *                                                                *
      ******************************************************************
      * This program tests the INQTRANL program by calling it with    *
      * hardcoded values for account sortcode 987654 and account      *
      * number 3000. It displays some of the returned transaction     *
      * data to prove the functionality works.                         *
      ******************************************************************

       IDENTIFICATION DIVISION.
       PROGRAM-ID. TESTINQL.
       AUTHOR. IBM.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER.  IBM-370.
       OBJECT-COMPUTER.  IBM-370.

       INPUT-OUTPUT SECTION.

       DATA DIVISION.
       FILE SECTION.

       WORKING-STORAGE SECTION.

       01 WS-CICS-WORK-AREA.
          05 WS-CICS-RESP              PIC S9(8) COMP.
          05 WS-CICS-RESP2             PIC S9(8) COMP.

       01 WS-PROGRAM-NAME              PIC X(8) VALUE 'INQTRANL'.

      * Working storage for display
       01 WS-DISPLAY-LINE              PIC X(80).
       01 WS-COUNTER                   PIC 9(3) COMP VALUE 0.
       01 WS-COUNTER-DISPLAY           PIC ZZ9.
       01 WS-AMOUNT-DISPLAY            PIC -(10)9.99.
       
      * Numeric to character conversion
       01 WS-SORTCODE-CHAR             PIC X(6).
       01 WS-ACCNO-CHAR                PIC X(8).
       01 WS-COUNT-CHAR                PIC X(5).
       01 WS-DATE-CHAR                 PIC X(8).
       01 WS-TIME-CHAR                 PIC X(6).

      * COMMAREA for calling INQTRANL
       COPY INQTRANL REPLACING INQTRANL-COMMAREA BY WS-INQTRANL-COMM.

       LINKAGE SECTION.


       PROCEDURE DIVISION.
       PREMIERE SECTION.
       A010.

           DISPLAY 'TESTINQL: Program started'.

      *
      *    Initialize the COMMAREA
      *
           INITIALIZE WS-INQTRANL-COMM.
           
           DISPLAY 'TESTINQL: COMMAREA initialized'.

      *
      *    Set the eyecatcher
      *
           MOVE 'ITRL' TO INQTRANL-EYE.

      *
      *    Set hardcoded account details
      *
           MOVE 987654 TO INQTRANL-SORTCODE.
           MOVE 3000 TO INQTRANL-ACCNO.
           
           DISPLAY 'TESTINQL: Account details set'.
           MOVE INQTRANL-SORTCODE TO WS-SORTCODE-CHAR.
           DISPLAY 'TESTINQL: SortCode=' WS-SORTCODE-CHAR.
           MOVE INQTRANL-ACCNO TO WS-ACCNO-CHAR.
           DISPLAY 'TESTINQL: AccNo=' WS-ACCNO-CHAR.

      *
      *    Set date range (use valid dates for DB2)
      *    From: 2020-01-01, To: 2030-12-31
      *
           MOVE 20200101 TO INQTRANL-FROM-DATE.
           MOVE 20301231 TO INQTRANL-TO-DATE.

      *
      *    Set pagination (limit to 10 transactions for testing)
      *
           MOVE 10 TO INQTRANL-LIMIT.
           MOVE 0 TO INQTRANL-OFFSET.
           
           DISPLAY 'TESTINQL: Parameters set, calling INQTRANL'.

      *
      *    Call INQTRANL program
      *
           EXEC CICS LINK
              PROGRAM(WS-PROGRAM-NAME)
              COMMAREA(WS-INQTRANL-COMM)
              LENGTH(LENGTH OF WS-INQTRANL-COMM)
              RESP(WS-CICS-RESP)
              RESP2(WS-CICS-RESP2)
           END-EXEC.

           IF WS-CICS-RESP NOT = DFHRESP(NORMAL)
              DISPLAY 'TESTINQL: ERROR - LINK failed'
              DISPLAY 'TESTINQL: RESP=' WS-CICS-RESP
              DISPLAY 'TESTINQL: RESP2=' WS-CICS-RESP2
              PERFORM SEND-ERROR-MESSAGE
              PERFORM GET-ME-OUT-OF-HERE
           END-IF.

           DISPLAY 'TESTINQL: LINK successful'.

      *
      *    Check if the call was successful
      *
           IF NOT INQTRANL-SUCCESS-TRUE
              DISPLAY 'TESTINQL: INQTRANL returned failure'
              PERFORM SEND-ERROR-MESSAGE
              PERFORM GET-ME-OUT-OF-HERE
           END-IF.

           DISPLAY 'TESTINQL: INQTRANL returned success'.

      *
      *    Display results via EXEC CICS SEND TEXT
      *
           PERFORM SEND-RESULTS.

           DISPLAY 'TESTINQL: Results sent, ending program'.
           PERFORM GET-ME-OUT-OF-HERE.

       A999.
           EXIT.


       SEND-RESULTS SECTION.
       SR010.

           DISPLAY 'TESTINQL: Preparing to send results'.

      *
      *    Send header
      *
           MOVE 'TESTINQL - Transaction List Test Results'
              TO WS-DISPLAY-LINE.
           EXEC CICS SEND TEXT
              FROM(WS-DISPLAY-LINE)
              LENGTH(80)
              ERASE
           END-EXEC.

           MOVE '========================================' 
              TO WS-DISPLAY-LINE.
           EXEC CICS SEND TEXT
              FROM(WS-DISPLAY-LINE)
              LENGTH(80)
           END-EXEC.

      *
      *    Send account details
      *
           MOVE INQTRANL-SORTCODE TO WS-SORTCODE-CHAR.
           MOVE INQTRANL-ACCNO TO WS-ACCNO-CHAR.
           STRING 'Account: ' DELIMITED BY SIZE,
                  WS-SORTCODE-CHAR DELIMITED BY SIZE,
                  '-' DELIMITED BY SIZE,
                  WS-ACCNO-CHAR DELIMITED BY SIZE
                  INTO WS-DISPLAY-LINE
           END-STRING.
           EXEC CICS SEND TEXT
              FROM(WS-DISPLAY-LINE)
              LENGTH(80)
           END-EXEC.

      *
      *    Send transaction counts
      *
           MOVE INQTRANL-TOTAL-COUNT TO WS-COUNT-CHAR.
           STRING 'Total Transactions: ' DELIMITED BY SIZE,
                  WS-COUNT-CHAR DELIMITED BY SIZE
                  INTO WS-DISPLAY-LINE
           END-STRING.
           EXEC CICS SEND TEXT
              FROM(WS-DISPLAY-LINE)
              LENGTH(80)
           END-EXEC.

           MOVE INQTRANL-RETURNED-COUNT TO WS-COUNT-CHAR.
           STRING 'Returned: ' DELIMITED BY SIZE,
                  WS-COUNT-CHAR DELIMITED BY SIZE
                  INTO WS-DISPLAY-LINE
           END-STRING.
           EXEC CICS SEND TEXT
              FROM(WS-DISPLAY-LINE)
              LENGTH(80)
           END-EXEC.

           MOVE '========================================' 
              TO WS-DISPLAY-LINE.
           EXEC CICS SEND TEXT
              FROM(WS-DISPLAY-LINE)
              LENGTH(80)
           END-EXEC.

      *
      *    Display first 5 transactions (or fewer if less returned)
      *
           PERFORM VARYING WS-COUNTER FROM 1 BY 1
              UNTIL WS-COUNTER > INQTRANL-RETURNED-COUNT
                 OR WS-COUNTER > 5

              MOVE WS-COUNTER TO WS-COUNTER-DISPLAY
              MOVE SPACES TO WS-DISPLAY-LINE
              STRING 'Transaction #' DELIMITED BY SIZE,
                     WS-COUNTER-DISPLAY DELIMITED BY SIZE
                     INTO WS-DISPLAY-LINE
              END-STRING
              EXEC CICS SEND TEXT
                 FROM(WS-DISPLAY-LINE)
                 LENGTH(80)
              END-EXEC

              MOVE INQTRANL-TRAN-DATE(WS-COUNTER) TO WS-DATE-CHAR
              MOVE INQTRANL-TRAN-TIME(WS-COUNTER) TO WS-TIME-CHAR
              STRING '  Date/Time: ' DELIMITED BY SIZE,
                     WS-DATE-CHAR DELIMITED BY SIZE,
                     ' ' DELIMITED BY SIZE,
                     WS-TIME-CHAR DELIMITED BY SIZE
                     INTO WS-DISPLAY-LINE
              END-STRING
              EXEC CICS SEND TEXT
                 FROM(WS-DISPLAY-LINE)
                 LENGTH(80)
              END-EXEC

              STRING '  Type: ' DELIMITED BY SIZE,
                     INQTRANL-TRAN-TYPE(WS-COUNTER) DELIMITED BY SIZE
                     INTO WS-DISPLAY-LINE
              END-STRING
              EXEC CICS SEND TEXT
                 FROM(WS-DISPLAY-LINE)
                 LENGTH(80)
              END-EXEC

              STRING '  Desc: ' DELIMITED BY SIZE,
                     INQTRANL-TRAN-DESC(WS-COUNTER) DELIMITED BY SIZE
                     INTO WS-DISPLAY-LINE
              END-STRING
              EXEC CICS SEND TEXT
                 FROM(WS-DISPLAY-LINE)
                 LENGTH(80)
              END-EXEC

              MOVE INQTRANL-TRAN-AMOUNT(WS-COUNTER) 
                 TO WS-AMOUNT-DISPLAY
              STRING '  Amount: ' DELIMITED BY SIZE,
                     WS-AMOUNT-DISPLAY DELIMITED BY SIZE
                     INTO WS-DISPLAY-LINE
              END-STRING
              EXEC CICS SEND TEXT
                 FROM(WS-DISPLAY-LINE)
                 LENGTH(80)
              END-EXEC

              MOVE SPACES TO WS-DISPLAY-LINE
              EXEC CICS SEND TEXT
                 FROM(WS-DISPLAY-LINE)
                 LENGTH(80)
              END-EXEC

           END-PERFORM.

           MOVE '========================================' 
              TO WS-DISPLAY-LINE.
           EXEC CICS SEND TEXT
              FROM(WS-DISPLAY-LINE)
              LENGTH(80)
           END-EXEC.

           MOVE 'Test completed successfully!' TO WS-DISPLAY-LINE.
           EXEC CICS SEND TEXT
              FROM(WS-DISPLAY-LINE)
              LENGTH(80)
           END-EXEC.

       SR999.
           EXIT.


       SEND-ERROR-MESSAGE SECTION.
       SEM010.

           MOVE 'TESTINQL - ERROR calling INQTRANL' 
              TO WS-DISPLAY-LINE.
           EXEC CICS SEND TEXT
              FROM(WS-DISPLAY-LINE)
              LENGTH(80)
              ERASE
           END-EXEC.

           MOVE 'Please check CICS logs for details.' 
              TO WS-DISPLAY-LINE.
           EXEC CICS SEND TEXT
              FROM(WS-DISPLAY-LINE)
              LENGTH(80)
           END-EXEC.

       SEM999.
           EXIT.


       GET-ME-OUT-OF-HERE SECTION.
       GMOFH010.

           EXEC CICS RETURN
           END-EXEC.

       GMOFH999.
           EXIT.

      *> Made with Bob