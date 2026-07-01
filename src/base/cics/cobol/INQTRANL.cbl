       CBL CICS('SP,EDF,DLI')
       CBL SQL
      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2026                                      *
      *                                                                *
      ******************************************************************

      ******************************************************************
      * This program retrieves a list of transactions for a given     *
      * account with optional date filtering and pagination support.  *
      *                                                                *
      * Input:                                                         *
      *   - Account sortcode and number                                *
      *   - Optional from/to dates (YYYYMMDD format)                   *
      *   - Limit (max 100) and offset for pagination                  *
      *                                                                *
      * Output:                                                        *
      *   - Array of transactions with composite transaction IDs       *
      *   - Total count and returned count                             *
      *                                                                *
      ******************************************************************

       IDENTIFICATION DIVISION.
       PROGRAM-ID. INQTRANL.
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

      * Host variables for query parameters
       01 HV-QUERY-SORTCODE            PIC X(6).
       01 HV-QUERY-ACCNO               PIC X(8).
       01 HV-QUERY-FROM-DATE           PIC X(10).
       01 HV-QUERY-TO-DATE             PIC X(10).
       01 HV-QUERY-LIMIT               PIC S9(4) COMP.
       01 HV-QUERY-OFFSET              PIC S9(8) COMP.

      * Pull in the SQL COMMAREA
           EXEC SQL
              INCLUDE SQLCA
           END-EXEC.

      * Declare the CURSOR for PROCTRAN table
      * Note: Pagination handled in COBOL for Db2 V10 compatibility
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
                     FROM PROCTRAN
                     WHERE PROCTRAN_SORTCODE = :HV-QUERY-SORTCODE
                       AND PROCTRAN_NUMBER = :HV-QUERY-ACCNO
                       AND PROCTRAN_DATE >= :HV-QUERY-FROM-DATE
                       AND PROCTRAN_DATE <= :HV-QUERY-TO-DATE
                     ORDER BY PROCTRAN_DATE DESC,
                              PROCTRAN_TIME DESC
                     FOR FETCH ONLY
           END-EXEC.

      * Declare cursor for counting total transactions
           EXEC SQL DECLARE TRAN-COUNT-CURSOR CURSOR FOR
              SELECT COUNT(*)
                     FROM PROCTRAN
                     WHERE PROCTRAN_SORTCODE = :HV-QUERY-SORTCODE
                       AND PROCTRAN_NUMBER = :HV-QUERY-ACCNO
                       AND PROCTRAN_DATE >= :HV-QUERY-FROM-DATE
                       AND PROCTRAN_DATE <= :HV-QUERY-TO-DATE
           END-EXEC.

       01 WS-CICS-WORK-AREA.
          05 WS-CICS-RESP              PIC S9(8) COMP.
          05 WS-CICS-RESP2             PIC S9(8) COMP.

       01 WS-TRANSACTION-COUNT         PIC S9(5) COMP VALUE 0.
       01 WS-FETCH-COUNT               PIC S9(3) COMP VALUE 0.
       01 WS-TOTAL-COUNT               PIC S9(5) COMP VALUE 0.
       01 WS-SKIP-COUNT                PIC S9(8) COMP VALUE 0.
       01 WS-ROW-COUNT                 PIC S9(8) COMP VALUE 0.

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

      * Numeric to character conversion working storage
       01 WS-SORTCODE-CHAR             PIC X(6).
       01 WS-ACCNO-CHAR                PIC X(8).

       LINKAGE SECTION.
       COPY INQTRANL REPLACING INQTRANL-COMMAREA BY DFHCOMMAREA.


       PROCEDURE DIVISION USING DFHCOMMAREA.
       PREMIERE SECTION.
       A010.

           DISPLAY 'INQTRANL: Program started'.
           
           INITIALIZE WS-TRANSACTION-COUNT
                      WS-FETCH-COUNT
                      WS-TOTAL-COUNT.
           
           DISPLAY 'INQTRANL: Variables initialized'.

      *
      *    Set up the abend handling
      *
           EXEC CICS HANDLE
              ABEND LABEL(ABEND-HANDLING)
           END-EXEC.
           
           DISPLAY 'INQTRANL: Abend handler set'.

      *
      *    Validate eyecatcher
      *
           IF NOT INQTRANL-EYE-VALID
              MOVE 'ITRL' TO INQTRANL-EYE
           END-IF.
           
           DISPLAY 'INQTRANL: Eyecatcher validated'.
           MOVE INQTRANL-SORTCODE TO WS-SORTCODE-CHAR.
           DISPLAY 'INQTRANL: SortCode=' WS-SORTCODE-CHAR.
           MOVE INQTRANL-ACCNO TO WS-ACCNO-CHAR.
           DISPLAY 'INQTRANL: AccNo=' WS-ACCNO-CHAR.

      *
      *    Set default values if not provided
      *
           IF INQTRANL-NO-FROM-DATE
              MOVE 0 TO INQTRANL-FROM-DATE
           END-IF.

           IF INQTRANL-NO-TO-DATE
              MOVE 99999999 TO INQTRANL-TO-DATE
           END-IF.

           IF INQTRANL-LIMIT = 0
              MOVE 50 TO INQTRANL-LIMIT
           END-IF.

      *
      *    Ensure limit doesn't exceed maximum
      *
           IF INQTRANL-LIMIT > 100
              MOVE 100 TO INQTRANL-LIMIT
           END-IF.
           
           DISPLAY 'INQTRANL: Parameters validated'.
           MOVE INQTRANL-FROM-DATE TO WS-DATE-YYYYMMDD.
           MOVE WS-DATE-YYYYMMDD TO WS-ACCNO-CHAR.
           DISPLAY 'INQTRANL: FromDate=' WS-ACCNO-CHAR.
           MOVE INQTRANL-TO-DATE TO WS-DATE-YYYYMMDD.
           MOVE WS-DATE-YYYYMMDD TO WS-ACCNO-CHAR.
           DISPLAY 'INQTRANL: ToDate=' WS-ACCNO-CHAR.
           MOVE INQTRANL-LIMIT TO WS-SORTCODE-CHAR(4:3).
           DISPLAY 'INQTRANL: Limit=' WS-SORTCODE-CHAR(4:3).
           MOVE INQTRANL-OFFSET TO WS-SORTCODE-CHAR(1:5).
           DISPLAY 'INQTRANL: Offset=' WS-SORTCODE-CHAR(1:5).

      *
      *    Get total count first
      *
           DISPLAY 'INQTRANL: About to get total count'.
           PERFORM GET-TOTAL-COUNT.
           DISPLAY 'INQTRANL: Total count=' WS-TOTAL-COUNT.

      *
      *    Get transaction list
      *
           DISPLAY 'INQTRANL: About to read transactions'.
           PERFORM READ-TRANSACTIONS-DB2.
           DISPLAY 'INQTRANL: Transactions read=' WS-FETCH-COUNT.

      *
      *    Return results to COMMAREA
      *
           MOVE WS-TOTAL-COUNT TO INQTRANL-TOTAL-COUNT.
           MOVE WS-FETCH-COUNT TO INQTRANL-RETURNED-COUNT.
           MOVE 'Y' TO INQTRANL-SUCCESS.
           
           DISPLAY 'INQTRANL: Returning success'.
           PERFORM GET-ME-OUT-OF-HERE.

       A999.
           EXIT.


       GET-TOTAL-COUNT SECTION.
       GTC010.

           DISPLAY 'INQTRANL: GET-TOTAL-COUNT started'.

      *
      *    Prepare query parameters - convert numeric to character
      *
           MOVE INQTRANL-SORTCODE TO WS-SORTCODE-CHAR.
           MOVE WS-SORTCODE-CHAR TO HV-QUERY-SORTCODE.
           MOVE INQTRANL-ACCNO TO WS-ACCNO-CHAR.
           MOVE WS-ACCNO-CHAR TO HV-QUERY-ACCNO.
           
           DISPLAY 'INQTRANL: Query params set'.
           
      *    Convert FROM-DATE from YYYYMMDD to YYYY-MM-DD
           MOVE INQTRANL-FROM-DATE TO WS-DATE-YYYYMMDD.
           PERFORM CONVERT-YYYYMMDD-TO-ISO.
           MOVE WS-DATE-ISO TO HV-QUERY-FROM-DATE.
           
      *    Convert TO-DATE from YYYYMMDD to YYYY-MM-DD
           MOVE INQTRANL-TO-DATE TO WS-DATE-YYYYMMDD.
           PERFORM CONVERT-YYYYMMDD-TO-ISO.
           MOVE WS-DATE-ISO TO HV-QUERY-TO-DATE.
           
           DISPLAY 'INQTRANL: Dates converted'.
           DISPLAY 'INQTRANL: FromDate(ISO)=' HV-QUERY-FROM-DATE.
           DISPLAY 'INQTRANL: ToDate(ISO)=' HV-QUERY-TO-DATE.

      *
      *    Open count cursor
      *
           DISPLAY 'INQTRANL: About to open count cursor'.
           EXEC SQL OPEN TRAN-COUNT-CURSOR
           END-EXEC.
           
           DISPLAY 'INQTRANL: Count cursor opened'.
           DISPLAY 'INQTRANL: SQLCODE=' SQLCODE.

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO SQLCODE-DISPLAY
              DISPLAY 'INQTRANL: ERROR opening count cursor'
              PERFORM ABEND-ROUTINE
           END-IF.

      *
      *    Fetch count
      *
           DISPLAY 'INQTRANL: About to fetch count'.
           EXEC SQL FETCH TRAN-COUNT-CURSOR
              INTO :WS-TOTAL-COUNT
           END-EXEC.
           
           DISPLAY 'INQTRANL: Count fetched'.
           DISPLAY 'INQTRANL: SQLCODE=' SQLCODE.

           IF SQLCODE NOT = 0 AND SQLCODE NOT = 100
              MOVE SQLCODE TO SQLCODE-DISPLAY
              DISPLAY 'INQTRANL: ERROR fetching count'
              PERFORM ABEND-ROUTINE
           END-IF.

      *
      *    Close count cursor
      *
           DISPLAY 'INQTRANL: About to close count cursor'.
           EXEC SQL CLOSE TRAN-COUNT-CURSOR
           END-EXEC.
           
           DISPLAY 'INQTRANL: Count cursor closed'.
           DISPLAY 'INQTRANL: SQLCODE=' SQLCODE.

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO SQLCODE-DISPLAY
              DISPLAY 'INQTRANL: ERROR closing count cursor'
              PERFORM ABEND-ROUTINE
           END-IF.
           
           DISPLAY 'INQTRANL: GET-TOTAL-COUNT completed'.

       GTC999.
           EXIT.


       READ-TRANSACTIONS-DB2 SECTION.
       RTD010.

           DISPLAY 'INQTRANL: READ-TRANSACTIONS-DB2 started'.

      *
      *    Prepare query parameters - convert numeric to character
      *
           MOVE INQTRANL-SORTCODE TO WS-SORTCODE-CHAR.
           MOVE WS-SORTCODE-CHAR TO HV-QUERY-SORTCODE.
           MOVE INQTRANL-ACCNO TO WS-ACCNO-CHAR.
           MOVE WS-ACCNO-CHAR TO HV-QUERY-ACCNO.
           
      *    Convert FROM-DATE from YYYYMMDD to YYYY-MM-DD
           MOVE INQTRANL-FROM-DATE TO WS-DATE-YYYYMMDD.
           PERFORM CONVERT-YYYYMMDD-TO-ISO.
           MOVE WS-DATE-ISO TO HV-QUERY-FROM-DATE.
           
      *    Convert TO-DATE from YYYYMMDD to YYYY-MM-DD
           MOVE INQTRANL-TO-DATE TO WS-DATE-YYYYMMDD.
           PERFORM CONVERT-YYYYMMDD-TO-ISO.
           MOVE WS-DATE-ISO TO HV-QUERY-TO-DATE.
           
           MOVE INQTRANL-LIMIT TO HV-QUERY-LIMIT.
           MOVE INQTRANL-OFFSET TO HV-QUERY-OFFSET.
           
           DISPLAY 'INQTRANL: Query params prepared'.

      *
      *    Open the DB2 CURSOR
      *
           DISPLAY 'INQTRANL: About to open transaction cursor'.
           EXEC SQL OPEN TRAN-CURSOR
           END-EXEC.
           
           DISPLAY 'INQTRANL: Transaction cursor opened'.
           DISPLAY 'INQTRANL: SQLCODE=' SQLCODE.

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO SQLCODE-DISPLAY
              DISPLAY 'INQTRANL: ERROR opening transaction cursor'
              PERFORM ABEND-ROUTINE
           END-IF.

      *
      *    FETCH transaction rows
      *
           DISPLAY 'INQTRANL: About to fetch transactions'.
           PERFORM FETCH-TRANSACTION-DATA.
           DISPLAY 'INQTRANL: Fetch completed'.

      *
      *    Close the DB2 CURSOR
      *
           DISPLAY 'INQTRANL: About to close transaction cursor'.
           EXEC SQL CLOSE TRAN-CURSOR
           END-EXEC.
           
           DISPLAY 'INQTRANL: Transaction cursor closed'.
           DISPLAY 'INQTRANL: SQLCODE=' SQLCODE.

           IF SQLCODE NOT = 0
              MOVE SQLCODE TO SQLCODE-DISPLAY
              DISPLAY 'INQTRANL: ERROR closing transaction cursor'
              PERFORM ABEND-ROUTINE
           END-IF.
           
           DISPLAY 'INQTRANL: READ-TRANSACTIONS-DB2 completed'.

       RTD999.
           EXIT.


       FETCH-TRANSACTION-DATA SECTION.
       FTD010.

           MOVE 0 TO WS-FETCH-COUNT.
           MOVE 0 TO WS-SKIP-COUNT.
           MOVE 0 TO WS-ROW-COUNT.

           PERFORM UNTIL SQLCODE = 100
                      OR WS-FETCH-COUNT >= HV-QUERY-LIMIT

              EXEC SQL FETCH TRAN-CURSOR
                 INTO :HV-PROCTRAN-EYECATCHER,
                      :HV-PROCTRAN-SORTCODE,
                      :HV-PROCTRAN-NUMBER,
                      :HV-PROCTRAN-DATE,
                      :HV-PROCTRAN-TIME,
                      :HV-PROCTRAN-REF,
                      :HV-PROCTRAN-TYPE,
                      :HV-PROCTRAN-DESC,
                      :HV-PROCTRAN-AMOUNT
              END-EXEC

              IF SQLCODE = 0
                 ADD 1 TO WS-ROW-COUNT
                 
      *
      *          Skip rows for OFFSET pagination
      *
                 IF WS-SKIP-COUNT < HV-QUERY-OFFSET
                    ADD 1 TO WS-SKIP-COUNT
                 ELSE
      *
      *             Process this row - we're past the offset
      *
                    ADD 1 TO WS-FETCH-COUNT

      *
      *             Convert DATE from YYYY-MM-DD to YYYYMMDD
      *
                    MOVE HV-PROCTRAN-DATE TO WS-DATE-ISO
                    PERFORM CONVERT-ISO-TO-YYYYMMDD
                    
      *
      *             Build composite transaction ID
      *
                    MOVE HV-PROCTRAN-SORTCODE TO WS-TRAN-ID-SC
                    MOVE HV-PROCTRAN-NUMBER TO WS-TRAN-ID-NUM
                    MOVE WS-DATE-YYYYMMDD TO WS-TRAN-ID-DATE
                    MOVE HV-PROCTRAN-TIME TO WS-TRAN-ID-TIME
                    MOVE HV-PROCTRAN-REF TO WS-TRAN-ID-REF

                    MOVE WS-TRAN-ID-PARTS TO
                       INQTRANL-TRAN-ID(WS-FETCH-COUNT)
                    MOVE HV-PROCTRAN-SORTCODE TO
                       INQTRANL-TRAN-SORTCODE(WS-FETCH-COUNT)
                    MOVE HV-PROCTRAN-NUMBER TO
                       INQTRANL-TRAN-ACCNO(WS-FETCH-COUNT)
                    MOVE WS-DATE-YYYYMMDD TO
                       INQTRANL-TRAN-DATE(WS-FETCH-COUNT)
                    MOVE HV-PROCTRAN-TIME TO
                       INQTRANL-TRAN-TIME(WS-FETCH-COUNT)
                    MOVE HV-PROCTRAN-REF TO
                       INQTRANL-TRAN-REF(WS-FETCH-COUNT)
                    MOVE HV-PROCTRAN-TYPE TO
                       INQTRANL-TRAN-TYPE(WS-FETCH-COUNT)
                    MOVE HV-PROCTRAN-DESC TO
                       INQTRANL-TRAN-DESC(WS-FETCH-COUNT)
                    MOVE HV-PROCTRAN-AMOUNT TO
                       INQTRANL-TRAN-AMOUNT(WS-FETCH-COUNT)
                 END-IF
              ELSE
                 IF SQLCODE NOT = 100
                    MOVE SQLCODE TO SQLCODE-DISPLAY
                    PERFORM ABEND-ROUTINE
                 END-IF
              END-IF

           END-PERFORM.

       FTD999.
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
           MOVE 'ITRL'      TO ABND-CODE.

           EXEC CICS ASSIGN PROGRAM(ABND-PROGRAM)
           END-EXEC.

           MOVE SQLCODE-DISPLAY TO ABND-SQLCODE.

           STRING 'INQTRANL - DB2 Error. SQLCODE='
                 DELIMITED BY SIZE,
                 SQLCODE-DISPLAY DELIMITED BY SIZE
                 INTO ABND-FREEFORM
           END-STRING.

           EXEC CICS LINK PROGRAM(WS-ABEND-PGM)
                     COMMAREA(ABNDINFO-REC)
           END-EXEC.

           EXEC CICS ABEND ABCODE('ITRL')
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
           MOVE 'ITRL'      TO ABND-CODE.

           EXEC CICS ASSIGN PROGRAM(ABND-PROGRAM)
           END-EXEC.

           STRING 'INQTRANL - Abend occurred'
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
