       CBL CICS('SP,EDF,DLI')
       CBL SQL
      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2026                                      *
      *                                                                *
      ******************************************************************

      ******************************************************************
      * This program retrieves details for a single transaction       *
      * identified by its composite key (sortcode, account number,    *
      * date, time, and reference).                                   *
      *                                                                *
      * Input:                                                         *
      *   - Transaction composite key components                       *
      *                                                                *
      * Output:                                                        *
      *   - Transaction details with composite transaction ID          *
      *   - Success and found flags                                    *
      *                                                                *
      ******************************************************************

       IDENTIFICATION DIVISION.
       PROGRAM-ID. INQTRAND.
       AUTHOR. IBM.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER.  IBM-370.
       OBJECT-COMPUTER.  IBM-370.

       INPUT-OUTPUT SECTION.

       DATA DIVISION.
       FILE SECTION.

       WORKING-STORAGE SECTION.

       COPY SORTCODE.

      * Get the PROCTRAN DB2 copybook
           EXEC SQL
              INCLUDE PROCDB2
           END-EXEC.

      * PROCTRAN Host variables for DB2
       01 HOST-PROCTRAN-ROW.
          03 HV-PROCTRAN-EYECATCHER    PIC X(4).
          03 HV-PROCTRAN-SORTCODE      PIC X(6).
          03 HV-PROCTRAN-NUMBER        PIC X(8).
          03 HV-PROCTRAN-DATE          PIC X(10).
          03 HV-PROCTRAN-TIME          PIC X(6).
          03 HV-PROCTRAN-REF           PIC X(12).
          03 HV-PROCTRAN-TYPE          PIC X(3).
          03 HV-PROCTRAN-DESC          PIC X(40).
          03 HV-PROCTRAN-AMOUNT        PIC S9(10)V99 COMP-3.

      * Pull in the SQL COMMAREA
           EXEC SQL
              INCLUDE SQLCA
           END-EXEC.

      * Declare the CURSOR for single PROCTRAN row
           EXEC SQL DECLARE TRAND-CURSOR CURSOR FOR
              SELECT PROCTRAN_EYECATCHER,
                     PROCTRAN_SORTCODE,
                     PROCTRAN_NUMBER,
                     PROCTRAN_DATE,
                     PROCTRAN_TIME,
                     PROCTRAN_REF,
                     PROCTRAN_TYPE,
                     PROCTRAN_DESC,
                     PROCTRAN_AMOUNT
                     FROM PROCTRAN
                     WHERE PROCTRAN_SORTCODE = :HV-PROCTRAN-SORTCODE
                       AND PROCTRAN_NUMBER = :HV-PROCTRAN-NUMBER
                       AND PROCTRAN_DATE = :HV-PROCTRAN-DATE
                       AND PROCTRAN_TIME = :HV-PROCTRAN-TIME
                       AND PROCTRAN_REF = :HV-PROCTRAN-REF
                     FOR FETCH ONLY
           END-EXEC.

       01 WS-CICS-WORK-AREA.
          05 WS-CICS-RESP              PIC S9(8) COMP.
          05 WS-CICS-RESP2             PIC S9(8) COMP.

       01 SQLCODE-DISPLAY              PIC S9(8) DISPLAY
           SIGN LEADING SEPARATE.

       01 WS-ABEND-PGM                 PIC X(8) VALUE 'ABNDPROC'.

       01 ABNDINFO-REC.
           COPY ABNDINFO.

       01 WS-U-TIME                    PIC S9(15) COMP-3.
       01 WS-ORIG-DATE                 PIC X(10).
       01 WS-ORIG-DATE-GRP REDEFINES WS-ORIG-DATE.
          03 WS-ORIG-DATE-DD           PIC 99.
          03 FILLER                    PIC X.
          03 WS-ORIG-DATE-MM           PIC 99.
          03 FILLER                    PIC X.
          03 WS-ORIG-DATE-YYYY         PIC 9999.

       01 WS-TIME-DATA.
           03 WS-TIME-NOW              PIC 9(6).
           03 WS-TIME-NOW-GRP REDEFINES WS-TIME-NOW.
              05 WS-TIME-NOW-GRP-HH       PIC 99.
              05 WS-TIME-NOW-GRP-MM       PIC 99.
              05 WS-TIME-NOW-GRP-SS       PIC 99.

      * Working storage for building transaction ID
       01 WS-TRAN-ID-PARTS.
          03 WS-TRAN-ID-SC             PIC X(6).
          03 FILLER                    PIC X VALUE '-'.
          03 WS-TRAN-ID-NUM            PIC X(8).
          03 FILLER                    PIC X VALUE '-'.
          03 WS-TRAN-ID-DATE           PIC X(8).
          03 FILLER                    PIC X VALUE '-'.
          03 WS-TRAN-ID-TIME           PIC X(6).
          03 FILLER                    PIC X VALUE '-'.
          03 WS-TRAN-ID-REF            PIC X(12).

      * Date conversion working storage
       01 WS-DATE-WORK.
          03 WS-DATE-YYYYMMDD          PIC 9(8).
          03 WS-DATE-YYYYMMDD-GRP REDEFINES WS-DATE-YYYYMMDD.
             05 WS-DATE-YYYY           PIC 9(4).
             05 WS-DATE-MM             PIC 9(2).
             05 WS-DATE-DD             PIC 9(2).
          03 WS-DATE-ISO               PIC X(10).
          03 WS-DATE-ISO-GRP REDEFINES WS-DATE-ISO.
             05 WS-DATE-ISO-YYYY       PIC X(4).
             05 WS-DATE-ISO-SEP1       PIC X.
             05 WS-DATE-ISO-MM         PIC X(2).
             05 WS-DATE-ISO-SEP2       PIC X.
             05 WS-DATE-ISO-DD         PIC X(2).

       LINKAGE SECTION.
       COPY INQTRAND REPLACING INQTRAND-COMMAREA BY DFHCOMMAREA.


       PROCEDURE DIVISION USING DFHCOMMAREA.
       PREMIERE SECTION.
       A010.

           DISPLAY 'INQTRAND: Program started'.

      *
      *    Set up the abend handling
      *
           EXEC CICS HANDLE
              ABEND LABEL(ABEND-HANDLING)
           END-EXEC.
           
           DISPLAY 'INQTRAND: Abend handler set'.

      *
      *    Validate eyecatcher
      *
           IF NOT INQTRAND-EYE-VALID
              MOVE 'ITRD' TO INQTRAND-EYE
           END-IF.
           
           DISPLAY 'INQTRAND: Eyecatcher validated'.
           DISPLAY 'INQTRAND: SortCode=' INQTRAND-SORTCODE.
           DISPLAY 'INQTRAND: AccNo=' INQTRAND-ACCNO.
           DISPLAY 'INQTRAND: Date=' INQTRAND-DATE.
           DISPLAY 'INQTRAND: Time=' INQTRAND-TIME.
           DISPLAY 'INQTRAND: Ref=' INQTRAND-REF.

      *
      *    Initialize output flags
      *
           MOVE 'N' TO INQTRAND-SUCCESS.
           MOVE 'N' TO INQTRAND-FOUND.
           
           DISPLAY 'INQTRAND: Flags initialized'.

      *
      *    Read transaction from DB2
      *
           DISPLAY 'INQTRAND: About to read transaction'.
           PERFORM READ-TRANSACTION-DB2.
           DISPLAY 'INQTRAND: Transaction read complete'.

      *
      *    Return results
      *
           DISPLAY 'INQTRAND: Returning results'.
           PERFORM GET-ME-OUT-OF-HERE.

       A999.
           EXIT.


       READ-TRANSACTION-DB2 SECTION.
       RTD010.

           DISPLAY 'INQTRAND: READ-TRANSACTION-DB2 started'.

      *
      *    Prepare query parameters from input
      *
           MOVE INQTRAND-SORTCODE TO HV-PROCTRAN-SORTCODE.
           MOVE INQTRAND-ACCNO TO HV-PROCTRAN-NUMBER.
           
           DISPLAY 'INQTRAND: Query params set'.
           
      *    Convert DATE from YYYYMMDD to YYYY-MM-DD
           MOVE INQTRAND-DATE TO WS-DATE-YYYYMMDD.
           PERFORM CONVERT-YYYYMMDD-TO-ISO.
           MOVE WS-DATE-ISO TO HV-PROCTRAN-DATE.
           
           MOVE INQTRAND-TIME TO HV-PROCTRAN-TIME.
           MOVE INQTRAND-REF TO HV-PROCTRAN-REF.
           
           DISPLAY 'INQTRAND: Date converted'.
           DISPLAY 'INQTRAND: Date(ISO)=' HV-PROCTRAN-DATE.

      *
      *    Open the DB2 CURSOR
      *
           DISPLAY 'INQTRAND: About to open cursor'.
           EXEC SQL OPEN TRAND-CURSOR
           END-EXEC.
           
           DISPLAY 'INQTRAND: Cursor opened'.
           DISPLAY 'INQTRAND: SQLCODE=' SQLCODE.

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO SQLCODE-DISPLAY
              DISPLAY 'INQTRAND: ERROR opening cursor'
              PERFORM ABEND-ROUTINE
           END-IF.

      *
      *    FETCH the transaction row
      *
           DISPLAY 'INQTRAND: About to fetch transaction'.
           EXEC SQL FETCH TRAND-CURSOR
              INTO :HV-PROCTRAN-EYECATCHER,
                   :HV-PROCTRAN-SORTCODE,
                   :HV-PROCTRAN-NUMBER,
                   :HV-PROCTRAN-DATE,
                   :HV-PROCTRAN-TIME,
                   :HV-PROCTRAN-REF,
                   :HV-PROCTRAN-TYPE,
                   :HV-PROCTRAN-DESC,
                   :HV-PROCTRAN-AMOUNT
           END-EXEC.
           
           DISPLAY 'INQTRAND: Fetch complete'.
           DISPLAY 'INQTRAND: SQLCODE=' SQLCODE.

           IF SQLCODE = 0
              DISPLAY 'INQTRAND: Transaction found'
      *
      *       Transaction found - populate output
      *
              MOVE 'Y' TO INQTRAND-FOUND

      *
      *       Convert DATE from YYYY-MM-DD to YYYYMMDD
      *
              MOVE HV-PROCTRAN-DATE TO WS-DATE-ISO
              PERFORM CONVERT-ISO-TO-YYYYMMDD
              
      *
      *       Build composite transaction ID
      *
              MOVE HV-PROCTRAN-SORTCODE TO WS-TRAN-ID-SC
              MOVE HV-PROCTRAN-NUMBER TO WS-TRAN-ID-NUM
              MOVE WS-DATE-YYYYMMDD TO WS-TRAN-ID-DATE
              MOVE HV-PROCTRAN-TIME TO WS-TRAN-ID-TIME
              MOVE HV-PROCTRAN-REF TO WS-TRAN-ID-REF

              MOVE WS-TRAN-ID-PARTS TO INQTRAND-TRAN-ID
              MOVE HV-PROCTRAN-SORTCODE TO INQTRAND-TRAN-SORTCODE
              MOVE HV-PROCTRAN-NUMBER TO INQTRAND-TRAN-ACCNO
              MOVE WS-DATE-YYYYMMDD TO INQTRAND-TRAN-DATE
              MOVE HV-PROCTRAN-TIME TO INQTRAND-TRAN-TIME
              MOVE HV-PROCTRAN-REF TO INQTRAND-TRAN-REF
              MOVE HV-PROCTRAN-TYPE TO INQTRAND-TRAN-TYPE
              MOVE HV-PROCTRAN-DESC TO INQTRAND-TRAN-DESC
              MOVE HV-PROCTRAN-AMOUNT TO INQTRAND-TRAN-AMOUNT

              MOVE 'Y' TO INQTRAND-SUCCESS
           ELSE
              IF SQLCODE = 100
      *
      *          Transaction not found - this is not an error
      *
                 DISPLAY 'INQTRAND: Transaction not found (100)'
                 MOVE 'N' TO INQTRAND-FOUND
                 MOVE 'Y' TO INQTRAND-SUCCESS
              ELSE
      *
      *          SQL error occurred
      *
                 DISPLAY 'INQTRAND: ERROR fetching transaction'
                 MOVE SQLCODE TO SQLCODE-DISPLAY
                 PERFORM ABEND-ROUTINE
              END-IF
           END-IF.

      *
      *    Close the DB2 CURSOR
      *
           DISPLAY 'INQTRAND: About to close cursor'.
           EXEC SQL CLOSE TRAND-CURSOR
           END-EXEC.
           
           DISPLAY 'INQTRAND: Cursor closed'.
           DISPLAY 'INQTRAND: SQLCODE=' SQLCODE.

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO SQLCODE-DISPLAY
              DISPLAY 'INQTRAND: ERROR closing cursor'
              PERFORM ABEND-ROUTINE
           END-IF.
           
           DISPLAY 'INQTRAND: READ-TRANSACTION-DB2 completed'.

       RTD999.
           EXIT.


       GET-ME-OUT-OF-HERE SECTION.
       GMOFH010.

           EXEC CICS RETURN
           END-EXEC.

       GMOFH999.
           EXIT.


       ABEND-ROUTINE SECTION.
       AR010.

           INITIALIZE ABNDINFO-REC.
           MOVE EIBRESP    TO ABND-RESPCODE.
           MOVE EIBRESP2   TO ABND-RESP2CODE.

           EXEC CICS ASSIGN APPLID(ABND-APPLID)
           END-EXEC.

           MOVE EIBTASKN   TO ABND-TASKNO-KEY.
           MOVE EIBTRNID   TO ABND-TRANID.

           PERFORM POPULATE-TIME-DATE.

           MOVE WS-ORIG-DATE TO ABND-DATE.
           STRING WS-TIME-NOW-GRP-HH DELIMITED BY SIZE,
                 ':' DELIMITED BY SIZE,
                  WS-TIME-NOW-GRP-MM DELIMITED BY SIZE,
                  ':' DELIMITED BY SIZE,
                  WS-TIME-NOW-GRP-SS DELIMITED BY SIZE
                  INTO ABND-TIME
           END-STRING.

           MOVE WS-U-TIME   TO ABND-UTIME-KEY.
           MOVE 'ITRD'      TO ABND-CODE.

           EXEC CICS ASSIGN PROGRAM(ABND-PROGRAM)
           END-EXEC.

           MOVE SQLCODE-DISPLAY TO ABND-SQLCODE.

           STRING 'INQTRAND - DB2 Error. SQLCODE='
                 DELIMITED BY SIZE,
                 SQLCODE-DISPLAY DELIMITED BY SIZE
                 INTO ABND-FREEFORM
           END-STRING.

           EXEC CICS LINK PROGRAM(WS-ABEND-PGM)
                     COMMAREA(ABNDINFO-REC)
           END-EXEC.

           EXEC CICS ABEND ABCODE('ITRD')
              CANCEL
              NODUMP
           END-EXEC.

       AR999.
           EXIT.


       ABEND-HANDLING SECTION.
       AH010.

           INITIALIZE ABNDINFO-REC.
           MOVE EIBRESP    TO ABND-RESPCODE.
           MOVE EIBRESP2   TO ABND-RESP2CODE.

           EXEC CICS ASSIGN APPLID(ABND-APPLID)
           END-EXEC.

           MOVE EIBTASKN   TO ABND-TASKNO-KEY.
           MOVE EIBTRNID   TO ABND-TRANID.

           PERFORM POPULATE-TIME-DATE.

           MOVE WS-ORIG-DATE TO ABND-DATE.
           STRING WS-TIME-NOW-GRP-HH DELIMITED BY SIZE,
                 ':' DELIMITED BY SIZE,
                  WS-TIME-NOW-GRP-MM DELIMITED BY SIZE,
                  ':' DELIMITED BY SIZE,
                  WS-TIME-NOW-GRP-SS DELIMITED BY SIZE
                  INTO ABND-TIME
           END-STRING.

           MOVE WS-U-TIME   TO ABND-UTIME-KEY.
           MOVE 'ITRD'      TO ABND-CODE.

           EXEC CICS ASSIGN PROGRAM(ABND-PROGRAM)
           END-EXEC.

           STRING 'INQTRAND - Abend occurred'
                 DELIMITED BY SIZE
                 INTO ABND-FREEFORM
           END-STRING.

           EXEC CICS LINK PROGRAM(WS-ABEND-PGM)
                     COMMAREA(ABNDINFO-REC)
           END-EXEC.

           EXEC CICS RETURN
           END-EXEC.

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
                     DATESEP('/')
           END-EXEC.

       PTD999.
           EXIT.

       CONVERT-YYYYMMDD-TO-ISO SECTION.
       CYI010.
      *
      *    Convert YYYYMMDD (PIC 9(8)) to YYYY-MM-DD (PIC X(10))
      *
           MOVE WS-DATE-YYYY TO WS-DATE-ISO-YYYY.
           MOVE '-' TO WS-DATE-ISO-SEP1.
           MOVE WS-DATE-MM TO WS-DATE-ISO-MM.
           MOVE '-' TO WS-DATE-ISO-SEP2.
           MOVE WS-DATE-DD TO WS-DATE-ISO-DD.

       CYI999.
           EXIT.


       CONVERT-ISO-TO-YYYYMMDD SECTION.
       CIY010.
      *
      *    Convert YYYY-MM-DD (PIC X(10)) to YYYYMMDD (PIC 9(8))
      *
           MOVE WS-DATE-ISO-YYYY TO WS-DATE-YYYY.
           MOVE WS-DATE-ISO-MM TO WS-DATE-MM.
           MOVE WS-DATE-ISO-DD TO WS-DATE-DD.

       CIY999.
           EXIT.

      *> Made with Bob
