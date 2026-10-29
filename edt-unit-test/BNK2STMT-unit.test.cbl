       PROCESS NODLL,NODYNAM,TEST(NOSEP),NOCICS,NOSQL,PGMN(LU),NOSEQ
       PROCESS ARITH(COMPAT)
      *-----------------------------------------------------------------
      * IBM Early Development Testing generated test
      *  Product ID: 5900-BBG
      *  Build: 2026-10-16T15:43:08Z (v3.1.0-SNAPSHOT)
      *   Level: [20261016T154014Z-30ec1c24]
      *  Version: COBOL_DRUN V3.0.0
      *
      * Project: Bank-of-Z
      * Program: BNK2STMT
      * Data origin: Collected
      * Data source: /Users/prasangprajapati/Repos/Bank-of-Z/.edt-unit-t
      *    est/recordings/batch-ikjeft01-bnkcstmt-2026-10-28t20-19-36-84
      *    9z.rec
      * Codepage: IBM1047
      * Host: vm30094.pok.stglabs.ibm.com
      * User: PRASANG
      *
      * Test ID: 446e9355-ba67-457b-9a04-e2fdd6d097dd
      * Generated: 10/28/2026 16:22
      *-----------------------------------------------------------------
       IDENTIFICATION DIVISION.
       PROGRAM-ID. 'BEFORE_ALL'.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  TEST-CASE-DATA.
           03 TEST-VERSION       PIC  9(05) COMP VALUE 1.
           03 NUM-TESTS          PIC  9(05) COMP VALUE 1.
           03 TEST-CASE-TYPE     PIC  X(04)      VALUE 'BTCH'.
           03 TEST-CASE-UUID     PIC  X(36)
                           VALUE '446e9355-ba67-457b-9a04-e2fdd6d097dd'.
           03 FILLER             PIC  X(128).
           03 TEST-ARRAY             OCCURS 1 TIMES.
             05 TEST-UUID        PIC  X(36).
             05 TEST-NAME        PIC  X(80).
             05 TEST-EP-NAME     PIC  X(160).
             05 TEST-BEFORE-EACH PIC  X(160)     VALUE 'BEFORE_EACH'.
             05 TEST-AFTER-EACH  PIC  X(160)     VALUE 'AFTER_EACH'.
             05 LOAD-MODULE-NAME PIC  X(08)      VALUE 'BNK2STMT'.
             05 CSECT-NAME       PIC  X(72)      VALUE SPACES.
       01  TC-DATA-PTR           POINTER.
       01  EQAUTCFG              PIC  X(08)      VALUE 'EQAUTCFG'.
       PROCEDURE DIVISION.
      *****************************************************************
      * Establish the test case information
      *****************************************************************
           DISPLAY 'RUNNING TEST CASE'.
      *****************************************************************
      * Establish individual test case arguments for TEST1
      *****************************************************************
           MOVE 'TEST1' TO TEST-NAME(1).
           MOVE 'TEST_TEST1' TO TEST-EP-NAME(1).
           MOVE '07abdee1-d34c-43cb-a16c-bc041f47d3c6'
               TO TEST-UUID(1).
      *****************************************************************
      * Inform the engine of the test case configuration
      *****************************************************************
           SET TC-DATA-PTR TO ADDRESS OF TEST-CASE-DATA.
           CALL EQAUTCFG USING TC-DATA-PTR.
           GOBACK.
       END PROGRAM 'BEFORE_ALL'.
       IDENTIFICATION DIVISION.
       PROGRAM-ID. 'TEST_TEST1'.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  LOAD-MODULE-NAME    PIC  X(08) VALUE 'BNK2STMT'.
       01  CSECT-NAME          PIC  X(72) VALUE SPACES.
       01  TEST-NAME-LENGTH    PIC S9(04) COMP-5 VALUE ZERO.
       01  TEST-NAME-TRIMMED   PIC  X(80)        VALUE SPACES.
      *
       01  BZUASSRT          PIC  X(08)        VALUE 'BZUASSRT'.
       01  BZ-ASSERT.
           03 MESSAGE-LEN    PIC S9(04) COMP-4 VALUE 5.
           03 MESSAGE-TXT    PIC  X(254)       VALUE 'HELLO'.
       01  BZ-P1             PIC S9(09) COMP-4 VALUE 4.
       01  BZ-P2             PIC S9(09) COMP-4 VALUE 2001.
       01  BZ-P3             PIC  X(03)        VALUE 'AZU'.
      *
       01  BZ-TRACE.
           03 TRACE-LEN        PIC S9(04) COMP-4 VALUE 5.
           03 TRACE-TXT        PIC  X(254)       VALUE 'TRACE'.
       01  BZUGETEP            PIC  X(08)        VALUE 'BZUGETEP'.
       01  BZUTRACE            PIC  X(08)        VALUE 'BZUTRACE'.
       01  AZ-EP-PTR           POINTER.
       01  AZ-TRACE-PTR        POINTER.
       01  ASSERT-ST.
           03 ASSERT-RC        PIC  9(09) BINARY VALUE 4.
           03 ASSERT-TEXT      PIC  9(04) BINARY VALUE 0.
       01  AZ-RC-WORK          PIC S9(04) BINARY VALUE 0.
       LINKAGE SECTION.
       01  TEST-NAME           PIC  X(80).
       01  AZ-ARG-LIST.
           03 ARG-LENGTH       PIC  9(04) COMP-4.
           03 ARG-DATA         PIC  X(256).
       01  AZ-INFO-BLOCK.
           COPY EQAITERC.
       01  AZ-PROC-PTR         PROCEDURE-POINTER.
       PROCEDURE DIVISION USING TEST-NAME
                                AZ-ARG-LIST
                                AZ-INFO-BLOCK
           .
       0000-MAINLINE-SECTION SECTION.
       0010-MAINLINE.
           DISPLAY 'AZU0000I TEST_TEST1 STARTED...'
           PERFORM 9010-TRIM-TEST-NAME
      * INITIALIZE PARAMETER
      * SET AREA ADDRESS TO POINTER
      * SET INPUT VALUE
           MOVE 0 TO RETURN-CODE.
      * CALL TEST PROGRAM
           DISPLAY 'AZU0000I CALL BNK2STMT'
           CALL BZUGETEP USING BY REFERENCE LOAD-MODULE-NAME
                               CSECT-NAME
                         RETURNING AZ-EP-PTR
           IF AZ-EP-PTR = NULL
             MOVE 1 TO MESSAGE-LEN OF BZ-ASSERT
             STRING 'UNABLE TO GET THE ENTRY POINT BY BZUGETEP.'
               DELIMITED BY SIZE
               INTO MESSAGE-TXT OF BZ-ASSERT
               WITH POINTER MESSAGE-LEN OF BZ-ASSERT
             END-STRING
             SUBTRACT 1 FROM MESSAGE-LEN OF BZ-ASSERT
             PERFORM THROW-ASSERTION-M
             GOBACK
           .
           SET ADDRESS OF AZ-PROC-PTR TO AZ-EP-PTR
           CALL AZ-PROC-PTR
           .
      * EVALUATE OUTPUT VALUE
           MOVE 0 TO RETURN-CODE
      * END
           DISPLAY 'AZU0000I TEST_TEST1 END.'
           GOBACK
           .
       THROW-ASSERTION-M.
           DISPLAY 'AZU0000I ------------------------------------------'
           DISPLAY 'AZU2001W THE TEST "' TEST-NAME-TRIMMED
                                         '" FAILED DUE TO AN ASSERTION.'
           DISPLAY 'AZU1101I ' MESSAGE-TXT OF
                                   BZ-ASSERT(1:MESSAGE-LEN OF BZ-ASSERT)
           DISPLAY 'AZU0000I ------------------------------------------'
           CALL BZUASSRT USING BZ-P1
                               BZ-P2
                               BZ-P3
                               BZ-ASSERT
           .
       9000-UTILITY-SECTION SECTION.
       9010-TRIM-TEST-NAME.
           MOVE 0 TO TEST-NAME-LENGTH
           INSPECT TEST-NAME TALLYING TEST-NAME-LENGTH
               FOR CHARACTERS BEFORE INITIAL SPACE
           MOVE TEST-NAME(1:TEST-NAME-LENGTH) TO TEST-NAME-TRIMMED
           .
       END PROGRAM 'TEST_TEST1'.
      *-----------------------------------------------------------------
      * TEST'S MAIN CALLBACK ROUTINE
      *-----------------------------------------------------------------
       IDENTIFICATION DIVISION.
       PROGRAM-ID. 'BZU_TEST'.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  LOAD-MODULE-NAME    PIC  X(08) VALUE 'BNK2STMT'.
       01  CSECT-NAME          PIC  X(72) VALUE SPACES.
       01 TESTCASE-METADATA.
           05 TM-PGM-UNDER-TEST-PATH PIC X(200) VALUE
           "src/base/batch/cobol/BNK2STMT.cbl".
       01  TEST-NAME-LENGTH    PIC S9(04) COMP-5 VALUE ZERO.
       01  TEST-NAME-TRIMMED   PIC  X(80)        VALUE SPACES.
      *
       01  BZUASSRT          PIC  X(08)        VALUE 'BZUASSRT'.
       01  BZ-ASSERT.
           03 MESSAGE-LEN    PIC S9(04) COMP-4 VALUE 5.
           03 MESSAGE-TXT    PIC  X(254)       VALUE 'HELLO'.
       01  BZ-P1             PIC S9(09) COMP-4 VALUE 4.
       01  BZ-P2             PIC S9(09) COMP-4 VALUE 2001.
       01  BZ-P3             PIC  X(03)        VALUE 'AZU'.
      *
       01  BZ-TRACE.
           03 TRACE-LEN        PIC S9(04) COMP-4 VALUE 5.
           03 TRACE-TXT        PIC  X(254)       VALUE 'TRACE'.
       01  BZUTRACE            PIC  X(08)        VALUE 'BZUTRACE'.
       01  AZ-TRACE-PTR        POINTER.
       01  ASSERT-ST.
           03 ASSERT-RC        PIC  9(09) BINARY VALUE 4.
           03 ASSERT-TEXT      PIC  9(04) BINARY VALUE 0.
       01  AZ-GRP-INDEX        PIC  9(08).
       01  AZ-FLAG-IN          PIC  9(01).
       01  AZ-RECORD-PTR       POINTER.
       01  AZ-RC-WORK          PIC S9(04) BINARY.
       01  AZ-OUTPUT-COUNT-STR PIC  X(05).
       LINKAGE SECTION.
       01  TEST-NAME           PIC  X(80).
       01  AZ-INFO-BLOCK.
          COPY EQAITERC.
       01  AZ-ARG-LIST.
           03 ARG-LENGTH       PIC  9(04) COMP-4.
           03 ARG-DATA         PIC  X(256).
       01  AZ-RECORD-COUNT     PIC 9(05) COMP-5.
      /
       PROCEDURE DIVISION.
       0000-MAINLINE-SECTION SECTION.
       0010-ENTRY-FOR-PGM-INPUT.
           ENTRY "PGM_INPT_BNK2STMT"
                 USING TEST-NAME
                       AZ-INFO-BLOCK
           .
           DISPLAY 'AZU0000I PGM_INPT_BNK2STMT INPUT VALUES...'.
           MOVE 0 TO RETURN-CODE
           PERFORM 9010-TRIM-TEST-NAME
      *
           EVALUATE TEST-NAME-TRIMMED
           WHEN SPACE
             CONTINUE
           WHEN OTHER
             CONTINUE
           END-EVALUATE
      *
           PERFORM 9020-TEARDOWN
           GOBACK
           .
       0020-ENTRY-FOR-PGM-OUTPUT.
           ENTRY "PGM_OUTP_BNK2STMT"
                 USING TEST-NAME
                       AZ-INFO-BLOCK
           .
           DISPLAY 'AZU0000I PGM_OUTP_BNK2STMT CHECK VALUES...'.
           MOVE 0 TO RETURN-CODE
           PERFORM 9010-TRIM-TEST-NAME
      *
           EVALUATE TEST-NAME-TRIMMED
           WHEN SPACE
             MOVE 4 TO RETURN-CODE
           WHEN 'TEST1'
             MOVE 0 TO RETURN-CODE
           WHEN OTHER
             MOVE 4 TO RETURN-CODE
           END-EVALUATE
      *
           PERFORM 9020-TEARDOWN
           GOBACK
           .
       9000-UTILITY-SECTION SECTION.
       9010-TRIM-TEST-NAME.
           MOVE 0 TO TEST-NAME-LENGTH
           INSPECT TEST-NAME TALLYING TEST-NAME-LENGTH
               FOR CHARACTERS BEFORE INITIAL SPACE
           MOVE TEST-NAME(1:TEST-NAME-LENGTH) TO TEST-NAME-TRIMMED
           .
       9020-TEARDOWN.
           DISPLAY 'AZU0000I BZU_TEST END.'
           .
       THROW-ASSERTION-M.
           DISPLAY 'AZU0000I ------------------------------------------'
           DISPLAY 'AZU2001W THE TEST "' TEST-NAME-TRIMMED
                                         '" FAILED DUE TO AN ASSERTION.'
           DISPLAY 'AZU1101I ' MESSAGE-TXT OF
                                   BZ-ASSERT(1:MESSAGE-LEN OF BZ-ASSERT)
           DISPLAY 'AZU0000I ------------------------------------------'
           CALL BZUASSRT USING BZ-P1
                               BZ-P2
                               BZ-P3
                               BZ-ASSERT
           .
       END PROGRAM 'BZU_TEST'.
      *-----------------------------------------------------------------
      * TEST'S INITIALIZATION ROUTINE
      *-----------------------------------------------------------------
       IDENTIFICATION DIVISION.
       PROGRAM-ID. 'BEFORE_EACH'.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  TEST-NAME-LENGTH    PIC S9(04) COMP-5 VALUE ZERO.
       01  TEST-NAME-TRIMMED   PIC  X(80)        VALUE SPACES.
       01  UNIQUE-TEST-ID      PIC  X(36)
                           VALUE '446e9355-ba67-457b-9a04-e2fdd6d097dd'.
       LINKAGE SECTION.
       01  TEST-NAME           PIC  X(80).
       01  TEST-ID             PIC  X(80).
       01  AZ-INFO-BLOCK.
           COPY EQAITERC.
       PROCEDURE DIVISION USING TEST-NAME
                                TEST-ID
                                AZ-INFO-BLOCK
           .
       0000-MAINLINE-SECTION SECTION.
       0010-MAINLINE.
           PERFORM 9010-TRIM-TEST-NAME
           DISPLAY 'AZU0000I BEFORE_EACH: ' TEST-NAME-TRIMMED
           MOVE UNIQUE-TEST-ID TO TEST-ID
           GOBACK
           .
       9000-UTILITY-SECTION SECTION.
       9010-TRIM-TEST-NAME.
           MOVE 0 TO TEST-NAME-LENGTH
           INSPECT TEST-NAME TALLYING TEST-NAME-LENGTH
               FOR CHARACTERS BEFORE INITIAL SPACE
           MOVE TEST-NAME(1:TEST-NAME-LENGTH) TO TEST-NAME-TRIMMED
           .
       END PROGRAM 'BEFORE_EACH'.
      *-----------------------------------------------------------------
      * TEST'S TERMINATION ROUTINE
      *-----------------------------------------------------------------
       IDENTIFICATION DIVISION.
       PROGRAM-ID. 'AFTER_EACH'.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  TEST-NAME-LENGTH    PIC S9(04) COMP-5 VALUE ZERO.
       01  TEST-NAME-TRIMMED   PIC  X(80)        VALUE SPACES.
       LINKAGE SECTION.
       01  TEST-NAME            PIC  X(80).
       01  AZ-INFO-BLOCK.
           COPY EQAITERC.
       PROCEDURE DIVISION USING TEST-NAME
                                AZ-INFO-BLOCK
           .
       0000-MAINLINE-SECTION SECTION.
       0010-MAINLINE.
           PERFORM 9010-TRIM-TEST-NAME
           DISPLAY 'AZU0000I AFTER_EACH: ' TEST-NAME-TRIMMED
           GOBACK
           .
       9000-UTILITY-SECTION SECTION.
       9010-TRIM-TEST-NAME.
           MOVE 0 TO TEST-NAME-LENGTH
           INSPECT TEST-NAME TALLYING TEST-NAME-LENGTH
               FOR CHARACTERS BEFORE INITIAL SPACE
           MOVE TEST-NAME(1:TEST-NAME-LENGTH) TO TEST-NAME-TRIMMED
           .
       END PROGRAM 'AFTER_EACH'.
      *-----------------------------------------------------------------
      * UNIT TEST FOR Z/OS: FILE
      *     FILE CALLBACK EXIT POINT
      * TEST CASE VERSION: 203
      *-----------------------------------------------------------------
       IDENTIFICATION DIVISION.
       PROGRAM-ID. 'FILE_BNK2STMT'.
       DATA DIVISION.
       LINKAGE SECTION.
       01  TEST-NAME           PIC  X(80).
       01  AZ-INFO-BLOCK.
           COPY EQAITERC.
       01  AZ-INFO-DDNM        PIC  X(08).
       01  AZ-INFO-STAT        PIC  X(01).
       01  AZ-INFO-COND        PIC  X(01).
       01  AZ-ACMDVA           PIC  X(04).
       01  AZ-PARM             PIC  X(80).
       PROCEDURE DIVISION.
      * CHECK OUTPUT VALUE
      * QSAM_INPT_OPEN_BNK2STMT.
           ENTRY 'QSAM_INPT_OPEN_BNK2STMT' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM.
           DISPLAY 'AZU0000I QSAM_INPT_OPEN_BNK2STMT CHECK VALUES...'
           PERFORM OPEN-OUTPUT
           .
           PERFORM TEARDOWN
           GOBACK
           .
      * QSAM_INPT_READ_BNK2STMT.
           ENTRY 'QSAM_INPT_READ_BNK2STMT' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM.
           DISPLAY 'AZU0000I QSAM_INPT_READ_BNK2STMT CHECK VALUES...'
           PERFORM READ-OUTPUT
           .
           PERFORM TEARDOWN
           GOBACK
           .
      * QSAM_INPT_CLOS_BNK2STMT.
           ENTRY 'QSAM_INPT_CLOS_BNK2STMT' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM.
           DISPLAY 'AZU0000I QSAM_INPT_CLOS_BNK2STMT CHECK VALUES...'
           PERFORM CLOS-OUTPUT
           .
           PERFORM TEARDOWN
           GOBACK
           .
      * QSAM_INPT_WRIT_BNK2STMT.
           ENTRY 'QSAM_INPT_WRIT_BNK2STMT' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM.
           DISPLAY 'AZU0000I QSAM_INPT_WRIT_BNK2STMT CHECK VALUES...'
           PERFORM WRITE-OUTPUT
           .
           PERFORM TEARDOWN
           GOBACK
           .
      * SET INPUT VALUE
      * QSAM_OUTP_OPEN_BNK2STMT.
           ENTRY 'QSAM_OUTP_OPEN_BNK2STMT' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM.
           DISPLAY 'AZU0000I QSAM_OUTP_OPEN_BNK2STMT INPUT VALUES...'
           PERFORM OPEN-INPUT
           .
           PERFORM TEARDOWN
           GOBACK
           .
      * QSAM_OUTP_READ_BNK2STMT.
           ENTRY 'QSAM_OUTP_READ_BNK2STMT' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM.
           DISPLAY 'AZU0000I QSAM_OUTP_READ_BNK2STMT INPUT VALUES...'
           PERFORM READ-INPUT
           .
           PERFORM TEARDOWN
           GOBACK
           .
      * QSAM_OUTP_CLOS_BNK2STMT.
           ENTRY 'QSAM_OUTP_CLOS_BNK2STMT' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM.
           DISPLAY 'AZU0000I QSAM_OUTP_CLOS_BNK2STMT INPUT VALUES...'
           PERFORM CLOS-INPUT
           .
           PERFORM TEARDOWN
           GOBACK
           .
      * QSAM_OUTP_WRIT_BNK2STMT.
           ENTRY 'QSAM_OUTP_WRIT_BNK2STMT' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM.
           DISPLAY 'AZU0000I QSAM_OUTP_WRIT_BNK2STMT INPUT VALUES...'
           PERFORM WRITE-INPUT
           .
           PERFORM TEARDOWN
           GOBACK
           .
      * END
       READ-OUTPUT.
      *    FILE "SYSIN"" (DD:SYSIN)"
           IF AZ-INFO-DDNM = "SYSIN"
             CALL 'SYSIN_OUTPUT_READ' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           END-IF.
           EXIT.
       READ-INPUT.
      *    FILE "SYSIN" (DD:SYSIN)"
           IF AZ-INFO-DDNM = "SYSIN"
             CALL 'SYSIN_INPUT_READ' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           END-IF.
           EXIT.
       WRITE-OUTPUT.
      *    FILE "STMTRPT"" (DD:STMTRPT)"
           IF AZ-INFO-DDNM = "STMTRPT"
             CALL 'STMTRPT_OUTPUT_WRITE' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           END-IF.
           EXIT.
       WRITE-INPUT.
           EXIT.
       OPEN-OUTPUT.
      *    FILE "SYSIN"" (DD:SYSIN)"
           IF AZ-INFO-DDNM = "SYSIN"
             CALL 'SYSIN_OUTPUT_OPEN' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           END-IF.
      *    FILE "STMTRPT"" (DD:STMTRPT)"
           IF AZ-INFO-DDNM = "STMTRPT"
             CALL 'STMTRPT_OUTPUT_OPEN' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           END-IF.
           EXIT.
       OPEN-INPUT.
      *    FILE "SYSIN" (DD:SYSIN)
            IF AZ-INFO-DDNM = "SYSIN"
              CALL 'SYSIN_INPUT_OPEN' USING TEST-NAME
              AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
              AZ-ACMDVA AZ-PARM
            END-IF.
      *    FILE "STMTRPT" (DD:STMTRPT)
            IF AZ-INFO-DDNM = "STMTRPT"
              CALL 'STMTRPT_INPUT_OPEN' USING TEST-NAME
              AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
              AZ-ACMDVA AZ-PARM
            END-IF.
            EXIT.
       CLOS-OUTPUT.
      *    FILE "SYSIN"" (DD:SYSIN)"
           IF AZ-INFO-DDNM = "SYSIN"
             CALL 'SYSIN_OUTPUT_CLOS' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           END-IF.
      *    FILE "STMTRPT"" (DD:STMTRPT)"
           IF AZ-INFO-DDNM = "STMTRPT"
             CALL 'STMTRPT_OUTPUT_CLOS' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           END-IF.
           EXIT.
       CLOS-INPUT.
      *    FILE "SYSIN" (DD:SYSIN)
            IF AZ-INFO-DDNM = "SYSIN"
              CALL 'SYSIN_INPUT_CLOS' USING TEST-NAME
              AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
              AZ-ACMDVA AZ-PARM
            END-IF.
      *    FILE "STMTRPT" (DD:STMTRPT)
            IF AZ-INFO-DDNM = "STMTRPT"
              CALL 'STMTRPT_INPUT_CLOS' USING TEST-NAME
              AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
              AZ-ACMDVA AZ-PARM
            END-IF.
            EXIT.
       TEARDOWN.
           DISPLAY 'AZU0000I FILE_BNK2STMT END.'
           .
       END PROGRAM 'FILE_BNK2STMT'.
      *-----------------------------------------------------------------
      * UNIT TEST FOR Z/OS: FILE QSAM
      *   FILE NAME: SYSIN
      * TEST CASE VERSION: 203
      *-----------------------------------------------------------------
       IDENTIFICATION DIVISION.
       PROGRAM-ID. 'QSAM_SYSIN_BNK2STMT'.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  TEST-NAME-LENGTH    PIC S9(04) COMP-5 VALUE ZERO.
       01  TEST-NAME-TRIMMED   PIC  X(80)        VALUE SPACES.
      *
       01  BZUASSRT          PIC  X(08)        VALUE 'BZUASSRT'.
       01  BZ-ASSERT.
           03 MESSAGE-LEN    PIC S9(04) COMP-4 VALUE 10.
           03 MESSAGE-TXT    PIC  X(254)       VALUE 'FILE HELLO'.
       01  BZ-P1             PIC S9(09) COMP-4 VALUE 4.
       01  BZ-P2             PIC S9(09) COMP-4 VALUE 2001.
       01  BZ-P3             PIC  X(03)        VALUE 'AZU'.
      *
       01  BZ-TRACE.
           03 TRACE-LEN        PIC S9(04) COMP-4 VALUE 5.
           03 TRACE-TXT        PIC  X(254)       VALUE 'TRACE'.
       01  BZUTRACE            PIC  X(08)        VALUE 'BZUTRACE'.
       01  AZ-TRACE-PTR        POINTER.
       01  AZ-RECORD.
           03 AZ-RECORD-COUNT  PIC  9(05) COMP-5 VALUE 0.
       01  AZ-GRP-INDEX        PIC  9(08).
       01  AZ-FLAG-IN          PIC  9(01).
       01  AZ-RECORD-PTR       POINTER.
       01  AZ-RC-WORK          PIC S9(04) BINARY.
       01  AZ-TEST-INPUT-DATA-VALUE.
           03 AZU00000000.
             05 PIC X(10) VALUE '0000000001'.
             05 PIC X(70) VALUE SPACES.
       LINKAGE SECTION.
       01  TEST-NAME           PIC  X(80).
       01  AZ-INFO-BLOCK.
           COPY EQAITERC.
       01  AZ-INFO-DDNM        PIC  X(08).
       01  AZ-INFO-STAT        PIC  X(01).
       01  AZ-INFO-COND        PIC  X(01).
       01  AZ-ACMDVA           PIC  X(04).
       01  AZ-PARM             PIC  X(80).
       01  AZ-WK-RECORD-COUNT  PIC  9(05) COMP-5.
       01  WS-INPUT-RECORD.
           03 WS-INPUT-CUSTNO PIC X(10).
      *      *** FILLER
           03 ZU00000079 PIC X(70).
      *
       PROCEDURE DIVISION.
       0000-MAINLINE-SECTION SECTION.
       0010-ENTRY-FOR-OUTPUT.
      * CHECK OUTPUT VALUE
           ENTRY 'SYSIN_OUTPUT_WRITE' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           DISPLAY 'AZU0000I FILE SYSIN CHECK VALUES...'.
           MOVE 0 TO RETURN-CODE
           PERFORM 9010-TRIM-TEST-NAME
           SET ADDRESS OF WS-INPUT-RECORD TO ADDRESS OF AZ-PARM
      * SET AREA ADDRESS TO POINTER
           MOVE 1 TO AZ-GRP-INDEX
           MOVE 0 TO AZ-FLAG-IN
           MOVE RETURN-CODE TO AZ-RC-WORK
           CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
             AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
           SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
           MOVE AZ-RC-WORK TO RETURN-CODE
           ADD 1 TO AZ-WK-RECORD-COUNT
           MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT
           EVALUATE TEST-NAME-TRIMMED
           WHEN SPACE
             CONTINUE
           WHEN 'TEST1'
             PERFORM P-OUTPUT-TEST1
           WHEN OTHER
             CONTINUE
           END-EVALUATE
           PERFORM TEARDOWN
           GOBACK
           .
      * SET INPUT VALUE
       0020-ENTRY-FOR-INPUT.
           ENTRY 'SYSIN_INPUT_READ' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           DISPLAY 'AZU0000I FILE SYSIN INPUT VALUES...'.
           MOVE 0 TO RETURN-CODE
           PERFORM 9010-TRIM-TEST-NAME
           SET ADDRESS OF WS-INPUT-RECORD TO ADDRESS OF AZ-PARM
      * SET AREA ADDRESS TO POINTER
           MOVE 1 TO AZ-GRP-INDEX
           MOVE 1 TO AZ-FLAG-IN
           MOVE RETURN-CODE TO AZ-RC-WORK
           CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
             AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
           SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
           MOVE AZ-RC-WORK TO RETURN-CODE
           ADD 1 TO AZ-WK-RECORD-COUNT
           MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT
           EVALUATE TEST-NAME-TRIMMED
           WHEN SPACE
             CONTINUE
           WHEN 'TEST1'
             PERFORM P-INPUT-TEST1
           WHEN OTHER
             CONTINUE
           END-EVALUATE
           PERFORM TEARDOWN
           GOBACK
           .
      * SET OPERATION STATUS
       0030-ENTRY-FOR-OPER-OPEN.
           ENTRY 'SYSIN_INPUT_OPEN' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           DISPLAY 'AZU0000I FILE SYSIN OPER OPEN VALUES...'.
           MOVE 0 TO RETURN-CODE
           PERFORM 9010-TRIM-TEST-NAME
           MOVE 7 TO AZ-GRP-INDEX
           MOVE 0 TO AZ-FLAG-IN
           MOVE RETURN-CODE TO AZ-RC-WORK
           CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
             AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
           SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
           MOVE AZ-RC-WORK TO RETURN-CODE
           ADD 1 TO AZ-WK-RECORD-COUNT
           MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT
           EVALUATE TEST-NAME-TRIMMED
           WHEN SPACE
             CONTINUE
           WHEN 'TEST1'
             PERFORM P-OPER-OPEN-TEST1
           WHEN OTHER
             CONTINUE
           END-EVALUATE
           PERFORM TEARDOWN
           GOBACK
           .
       0030-ENTRY-FOR-OPER-CLOS.
           ENTRY 'SYSIN_INPUT_CLOS' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           DISPLAY 'AZU0000I FILE SYSIN OPER CLOS VALUES...'.
           MOVE 0 TO RETURN-CODE
           PERFORM 9010-TRIM-TEST-NAME
           MOVE 8 TO AZ-GRP-INDEX
           MOVE 0 TO AZ-FLAG-IN
           MOVE RETURN-CODE TO AZ-RC-WORK
           CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
             AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
           SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
           MOVE AZ-RC-WORK TO RETURN-CODE
           ADD 1 TO AZ-WK-RECORD-COUNT
           MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT
           EVALUATE TEST-NAME-TRIMMED
           WHEN SPACE
             CONTINUE
           WHEN 'TEST1'
             PERFORM P-OPER-CLOS-TEST1
           WHEN OTHER
             CONTINUE
           END-EVALUATE
           PERFORM TEARDOWN
           GOBACK
           .
      * OUTPUT FOR READ
       0015-ENTRY-FOR-OUTPUT-READ.
           ENTRY 'SYSIN_OUTPUT_READ' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           DISPLAY 'AZU0000I FILE SYSIN OUTPUT READ VALUES...'.
           MOVE 0 TO RETURN-CODE
           PERFORM 9010-TRIM-TEST-NAME
           SET ADDRESS OF WS-INPUT-RECORD TO ADDRESS OF AZ-PARM
      * SET AREA ADDRESS TO POINTER
           MOVE 1 TO AZ-GRP-INDEX
           MOVE 0 TO AZ-FLAG-IN
           MOVE RETURN-CODE TO AZ-RC-WORK
           CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
             AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
           SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
           MOVE AZ-RC-WORK TO RETURN-CODE
           ADD 1 TO AZ-WK-RECORD-COUNT
           MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT
           EVALUATE TEST-NAME-TRIMMED
           WHEN SPACE
             CONTINUE
           WHEN 'TEST1'
             PERFORM P-OUTPUT-TEST1
           WHEN OTHER
             CONTINUE
           END-EVALUATE
           PERFORM TEARDOWN
           GOBACK
           .
      * OUTPUT FOR OPEN/CLOS/STRT/DLET
       0035-ENTRY-OPER-OUTPUT-OPEN.
           ENTRY 'SYSIN_OUTPUT_OPEN' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           DISPLAY 'AZU0000I FILE SYSIN OUTPUT OPEN VALUES...'.
           MOVE 0 TO RETURN-CODE
           PERFORM 9010-TRIM-TEST-NAME
           MOVE 7 TO AZ-GRP-INDEX
           MOVE 0 TO AZ-FLAG-IN
           MOVE RETURN-CODE TO AZ-RC-WORK
           CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
             AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
           SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
           MOVE AZ-RC-WORK TO RETURN-CODE
           ADD 1 TO AZ-WK-RECORD-COUNT
           MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT
           EVALUATE TEST-NAME-TRIMMED
           WHEN SPACE
             CONTINUE
           WHEN 'TEST1'
             PERFORM P-OPER-OPEN-TEST1
           WHEN OTHER
             CONTINUE
           END-EVALUATE
           PERFORM TEARDOWN
           GOBACK
           .
       0035-ENTRY-OPER-OUTPUT-CLOS.
           ENTRY 'SYSIN_OUTPUT_CLOS' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           DISPLAY 'AZU0000I FILE SYSIN OUTPUT CLOS VALUES...'.
           MOVE 0 TO RETURN-CODE
           PERFORM 9010-TRIM-TEST-NAME
           MOVE 8 TO AZ-GRP-INDEX
           MOVE 0 TO AZ-FLAG-IN
           MOVE RETURN-CODE TO AZ-RC-WORK
           CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
             AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
           SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
           MOVE AZ-RC-WORK TO RETURN-CODE
           ADD 1 TO AZ-WK-RECORD-COUNT
           MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT
           EVALUATE TEST-NAME-TRIMMED
           WHEN SPACE
             CONTINUE
           WHEN 'TEST1'
             PERFORM P-OPER-CLOS-TEST1
           WHEN OTHER
             CONTINUE
           END-EVALUATE
           PERFORM TEARDOWN
           GOBACK
           .
       TEARDOWN.
      *     DISPLAY 'AZU0000I QSAM_SYSIN_BNK2STMT END.'
           EXIT.
       P-OUTPUT-TEST1.
             MOVE X'00' TO AZ-INFO-COND
             MOVE X'00' TO AZ-INFO-STAT
           IF AZ-RECORD-COUNT = 0
             NEXT SENTENCE
           ELSE
             NEXT SENTENCE
           .
       P-INPUT-TEST1.
           IF AZ-RECORD-COUNT = 0
             MOVE X'00' TO AZ-INFO-COND
             MOVE X'00' TO AZ-INFO-STAT
           ELSE IF AZ-RECORD-COUNT = 1
             MOVE AZU00000000 TO WS-INPUT-RECORD
             MOVE X'00' TO AZ-INFO-COND
             MOVE X'00' TO AZ-INFO-STAT
           .
       P-OPER-OPEN-TEST1.
             MOVE X'00' TO AZ-INFO-COND
             MOVE X'00' TO AZ-INFO-STAT
           .
       P-OPER-CLOS-TEST1.
             MOVE X'00' TO AZ-INFO-COND
             MOVE X'00' TO AZ-INFO-STAT
           .
       9000-UTILITY-SECTION SECTION.
       9010-TRIM-TEST-NAME.
           MOVE 0 TO TEST-NAME-LENGTH
           INSPECT TEST-NAME TALLYING TEST-NAME-LENGTH
               FOR CHARACTERS BEFORE INITIAL SPACE
           MOVE TEST-NAME(1:TEST-NAME-LENGTH) TO TEST-NAME-TRIMMED
           .
       END PROGRAM 'QSAM_SYSIN_BNK2STMT'.
      *-----------------------------------------------------------------
      * UNIT TEST FOR Z/OS: FILE QSAM
      *   FILE NAME: STMTRPT
      * TEST CASE VERSION: 203
      *-----------------------------------------------------------------
       IDENTIFICATION DIVISION.
       PROGRAM-ID. 'QSAM_STMTRPT_BNK2STMT'.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  TEST-NAME-LENGTH    PIC S9(04) COMP-5 VALUE ZERO.
       01  TEST-NAME-TRIMMED   PIC  X(80)        VALUE SPACES.
      *
       01  BZUASSRT          PIC  X(08)        VALUE 'BZUASSRT'.
       01  BZ-ASSERT.
           03 MESSAGE-LEN    PIC S9(04) COMP-4 VALUE 10.
           03 MESSAGE-TXT    PIC  X(254)       VALUE 'FILE HELLO'.
       01  BZ-P1             PIC S9(09) COMP-4 VALUE 4.
       01  BZ-P2             PIC S9(09) COMP-4 VALUE 2001.
       01  BZ-P3             PIC  X(03)        VALUE 'AZU'.
      *
       01  BZ-TRACE.
           03 TRACE-LEN        PIC S9(04) COMP-4 VALUE 5.
           03 TRACE-TXT        PIC  X(254)       VALUE 'TRACE'.
       01  BZUTRACE            PIC  X(08)        VALUE 'BZUTRACE'.
       01  AZ-TRACE-PTR        POINTER.
       01  AZ-RECORD.
           03 AZ-RECORD-COUNT  PIC  9(05) COMP-5 VALUE 0.
       01  AZ-GRP-INDEX        PIC  9(08).
       01  AZ-FLAG-IN          PIC  9(01).
       01  AZ-RECORD-PTR       POINTER.
       01  AZ-RC-WORK          PIC S9(04) BINARY.
       01  AZ-COMPARE.
           03 AZ-COMPARE-ITEM-NAME-PTR  POINTER.
           03 AZ-COMPARE-ITEM-NAME-LEN  PIC S9(9) COMP-5.
           03 AZ-COMPARE-ITEM-VALUE-PTR POINTER.
           03 AZ-COMPARE-ITEM-VALUE-LEN PIC S9(9) COMP-5.
           03 AZ-COMPARE-ITEM-EXP-VALUE-PTR POINTER.
           03 AZ-COMPARE-ITEM-EXP-VALUE-LEN PIC S9(9) COMP-5.
           03 AZ-ITEM-NAME-S            PIC S9(8) COMP.
           03 AZ-ITEM-NAME-LEN          PIC S9(8) COMP.
       01  AZ-TEST-EXPECTED-DATA-VALUE.
           03 AZU00000000.
             05 PIC X(20) VALUE 'BANK OF Z - Detailed'.
             05 PIC X(19) VALUE ' Customer Statement'.
             05 PIC X(41) VALUE SPACES.
           03 AZU00000001.
             05 PIC X(20) VALUE 'GENERATED ON: 28/10/'.
             05 PIC X(4) VALUE '2026'.
             05 PIC X(56) VALUE SPACES.
           03 AZU00000002.
             05 PIC X(20) VALUE '--------------------'.
             05 PIC X(20) VALUE '--------------------'.
             05 PIC X(20) VALUE '--------------------'.
             05 PIC X(20) VALUE '--------------------'.
           03 AZU00000003.
             05 PIC X(20) VALUE '*** CUSTOMER INFORMA'.
             05 PIC X(8) VALUE 'TION ***'.
             05 PIC X(52) VALUE SPACES.
           03 AZU00000004.
             05 PIC X(20) VALUE 'CUST-NO : 0000000001'.
             05 PIC X(60) VALUE SPACES.
           03 AZU00000005.
             05 PIC X(20) VALUE 'NAME    : Dr Zsa G H'.
             05 PIC X(5) VALUE 'igins'.
             05 PIC X(55) VALUE SPACES.
           03 AZU00000006.
             05 PIC X(20) VALUE 'DOB     : 03/06/1952'.
             05 PIC X(60) VALUE SPACES.
           03 AZU00000007.
             05 PIC X(13) VALUE 'PHONE   : N/A'.
             05 PIC X(67) VALUE SPACES.
           03 AZU00000008.
             05 PIC X(20) VALUE 'ADDR1   : 74 Joshua '.
             05 PIC X(4) VALUE 'Mews'.
             05 PIC X(56) VALUE SPACES.
           03 AZU00000009.
             05 PIC X(9) VALUE 'ADDR2   :'.
             05 PIC X(71) VALUE SPACES.
           03 AZU0000000A.
             05 PIC X(20) VALUE 'CITY    : Portsmouth'.
             05 PIC X(60) VALUE SPACES.
           03 AZU0000000B.
             05 PIC X(18) VALUE 'POST    : SW80 3CD'.
             05 PIC X(62) VALUE SPACES.
           03 AZU0000000C.
             05 PIC X(20) VALUE 'CNTRY   : United Kin'.
             05 PIC X(4) VALUE 'gdom'.
             05 PIC X(56) VALUE SPACES.
           03 AZU0000000D.
             05 PIC X(20) VALUE '*** ACCOUNT INFORMAT'.
             05 PIC X(7) VALUE 'ION ***'.
             05 PIC X(53) VALUE SPACES.
           03 AZU0000000E.
             05 PIC X(20) VALUE 'ACC-NO   TYPE     RA'.
             05 PIC X(20) VALUE 'TE  OPENED     OVERD'.
             05 PIC X(20) VALUE 'RAFT  AVAIL-BALANCE '.
             05 PIC X(14) VALUE 'ACTUAL-BALANCE'.
             05 PIC X(6) VALUE SPACES.
           03 AZU0000000F.
             05 PIC X(20) VALUE '00000001 ISA       2'.
             05 PIC X(20) VALUE '.10 09/03/2005      '.
             05 PIC X(20) VALUE '   0 +     631805.64'.
             05 PIC X(16) VALUE ' +     631805.64'.
             05 PIC X(4) VALUE SPACES.
           03 AZU00000010.
             05 PIC X(20) VALUE '00000002 SAVING    1'.
             05 PIC X(20) VALUE '.75 14/09/1955      '.
             05 PIC X(20) VALUE '   0 +     320246.03'.
             05 PIC X(16) VALUE ' +     320246.03'.
             05 PIC X(4) VALUE SPACES.
           03 AZU00000011.
             05 PIC X(20) VALUE '00000003 CURRENT   0'.
             05 PIC X(20) VALUE '.00 06/05/1968      '.
             05 PIC X(20) VALUE ' 100 +     282755.16'.
             05 PIC X(16) VALUE ' +     282755.16'.
             05 PIC X(4) VALUE SPACES.
       LOCAL-STORAGE SECTION.
       01  AZ-COMPARE-ITEM-NAMES.
           03 AZU00000012 PIC X(14) VALUE 'STMTRPT-RECORD'.
       01  AZ-COMPARE-WORK-ITEMS.
           03 AZU00000013 PIC X(80) OCCURS 2.
       LINKAGE SECTION.
       01  TEST-NAME           PIC  X(80).
       01  AZ-INFO-BLOCK.
           COPY EQAITERC.
       01  AZ-INFO-DDNM        PIC  X(08).
       01  AZ-INFO-STAT        PIC  X(01).
       01  AZ-INFO-COND        PIC  X(01).
       01  AZ-ACMDVA           PIC  X(04).
       01  AZ-PARM             PIC  X(80).
       01  AZ-WK-RECORD-COUNT  PIC  9(05) COMP-5.
       01  AZ-COMPARE-ITEM-NAME      PIC X(1000).
       01  AZ-COMPARE-ITEM-VALUE     PIC X(254).
       01  AZ-COMPARE-ITEM-EXP-VALUE PIC X(254).
       01  STMTRPT-RECORD PIC X(80).
      *
       PROCEDURE DIVISION.
       0000-MAINLINE-SECTION SECTION.
       0010-ENTRY-FOR-OUTPUT.
      * CHECK OUTPUT VALUE
           ENTRY 'STMTRPT_OUTPUT_WRITE' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           DISPLAY 'AZU0000I FILE STMTRPT CHECK VALUES...'.
           MOVE 0 TO RETURN-CODE
           PERFORM 9010-TRIM-TEST-NAME
           SET ADDRESS OF STMTRPT-RECORD TO ADDRESS OF AZ-PARM
      * SET AREA ADDRESS TO POINTER
           MOVE 2 TO AZ-GRP-INDEX
           MOVE 0 TO AZ-FLAG-IN
           MOVE RETURN-CODE TO AZ-RC-WORK
           CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
             AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
           SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
           MOVE AZ-RC-WORK TO RETURN-CODE
           ADD 1 TO AZ-WK-RECORD-COUNT
           MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT
           EVALUATE TEST-NAME-TRIMMED
           WHEN SPACE
             CONTINUE
           WHEN 'TEST1'
             PERFORM P-OUTPUT-TEST1
           WHEN OTHER
             CONTINUE
           END-EVALUATE
           PERFORM TEARDOWN
           GOBACK
           .
      * SET INPUT VALUE
       0020-ENTRY-FOR-INPUT.
           ENTRY 'STMTRPT_INPUT_READ' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           DISPLAY 'AZU0000I FILE STMTRPT INPUT VALUES...'.
           MOVE 0 TO RETURN-CODE
           PERFORM 9010-TRIM-TEST-NAME
           SET ADDRESS OF STMTRPT-RECORD TO ADDRESS OF AZ-PARM
      * SET AREA ADDRESS TO POINTER
           MOVE 2 TO AZ-GRP-INDEX
           MOVE 1 TO AZ-FLAG-IN
           MOVE RETURN-CODE TO AZ-RC-WORK
           CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
             AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
           SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
           MOVE AZ-RC-WORK TO RETURN-CODE
           ADD 1 TO AZ-WK-RECORD-COUNT
           MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT
           EVALUATE TEST-NAME-TRIMMED
           WHEN SPACE
             CONTINUE
           WHEN 'TEST1'
             PERFORM P-INPUT-TEST1
           WHEN OTHER
             CONTINUE
           END-EVALUATE
           PERFORM TEARDOWN
           GOBACK
           .
      * SET OPERATION STATUS
       0030-ENTRY-FOR-OPER-OPEN.
           ENTRY 'STMTRPT_INPUT_OPEN' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           DISPLAY 'AZU0000I FILE STMTRPT OPER OPEN VALUES...'.
           MOVE 0 TO RETURN-CODE
           PERFORM 9010-TRIM-TEST-NAME
           MOVE 9 TO AZ-GRP-INDEX
           MOVE 0 TO AZ-FLAG-IN
           MOVE RETURN-CODE TO AZ-RC-WORK
           CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
             AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
           SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
           MOVE AZ-RC-WORK TO RETURN-CODE
           ADD 1 TO AZ-WK-RECORD-COUNT
           MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT
           EVALUATE TEST-NAME-TRIMMED
           WHEN SPACE
             CONTINUE
           WHEN 'TEST1'
             PERFORM P-OPER-OPEN-TEST1
           WHEN OTHER
             CONTINUE
           END-EVALUATE
           PERFORM TEARDOWN
           GOBACK
           .
       0030-ENTRY-FOR-OPER-CLOS.
           ENTRY 'STMTRPT_INPUT_CLOS' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           DISPLAY 'AZU0000I FILE STMTRPT OPER CLOS VALUES...'.
           MOVE 0 TO RETURN-CODE
           PERFORM 9010-TRIM-TEST-NAME
           MOVE 10 TO AZ-GRP-INDEX
           MOVE 0 TO AZ-FLAG-IN
           MOVE RETURN-CODE TO AZ-RC-WORK
           CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
             AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
           SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
           MOVE AZ-RC-WORK TO RETURN-CODE
           ADD 1 TO AZ-WK-RECORD-COUNT
           MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT
           EVALUATE TEST-NAME-TRIMMED
           WHEN SPACE
             CONTINUE
           WHEN 'TEST1'
             PERFORM P-OPER-CLOS-TEST1
           WHEN OTHER
             CONTINUE
           END-EVALUATE
           PERFORM TEARDOWN
           GOBACK
           .
      * OUTPUT FOR READ
       0015-ENTRY-FOR-OUTPUT-READ.
           ENTRY 'STMTRPT_OUTPUT_READ' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           DISPLAY 'AZU0000I FILE STMTRPT OUTPUT READ VALUES...'.
           MOVE 0 TO RETURN-CODE
           PERFORM 9010-TRIM-TEST-NAME
           SET ADDRESS OF STMTRPT-RECORD TO ADDRESS OF AZ-PARM
      * SET AREA ADDRESS TO POINTER
           MOVE 2 TO AZ-GRP-INDEX
           MOVE 0 TO AZ-FLAG-IN
           MOVE RETURN-CODE TO AZ-RC-WORK
           CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
             AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
           SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
           MOVE AZ-RC-WORK TO RETURN-CODE
           ADD 1 TO AZ-WK-RECORD-COUNT
           MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT
           EVALUATE TEST-NAME-TRIMMED
           WHEN SPACE
             CONTINUE
           WHEN 'TEST1'
             PERFORM P-OUTPUT-TEST1
           WHEN OTHER
             CONTINUE
           END-EVALUATE
           PERFORM TEARDOWN
           GOBACK
           .
      * OUTPUT FOR OPEN/CLOS/STRT/DLET
       0035-ENTRY-OPER-OUTPUT-OPEN.
           ENTRY 'STMTRPT_OUTPUT_OPEN' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           DISPLAY 'AZU0000I FILE STMTRPT OUTPUT OPEN VALUES...'.
           MOVE 0 TO RETURN-CODE
           PERFORM 9010-TRIM-TEST-NAME
           MOVE 9 TO AZ-GRP-INDEX
           MOVE 0 TO AZ-FLAG-IN
           MOVE RETURN-CODE TO AZ-RC-WORK
           CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
             AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
           SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
           MOVE AZ-RC-WORK TO RETURN-CODE
           ADD 1 TO AZ-WK-RECORD-COUNT
           MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT
           EVALUATE TEST-NAME-TRIMMED
           WHEN SPACE
             CONTINUE
           WHEN 'TEST1'
             PERFORM P-OPER-OPEN-TEST1
           WHEN OTHER
             CONTINUE
           END-EVALUATE
           PERFORM TEARDOWN
           GOBACK
           .
       0035-ENTRY-OPER-OUTPUT-CLOS.
           ENTRY 'STMTRPT_OUTPUT_CLOS' USING TEST-NAME
             AZ-INFO-BLOCK AZ-INFO-DDNM AZ-INFO-STAT AZ-INFO-COND
             AZ-ACMDVA AZ-PARM
           DISPLAY 'AZU0000I FILE STMTRPT OUTPUT CLOS VALUES...'.
           MOVE 0 TO RETURN-CODE
           PERFORM 9010-TRIM-TEST-NAME
           MOVE 10 TO AZ-GRP-INDEX
           MOVE 0 TO AZ-FLAG-IN
           MOVE RETURN-CODE TO AZ-RC-WORK
           CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
             AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
           SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
           MOVE AZ-RC-WORK TO RETURN-CODE
           ADD 1 TO AZ-WK-RECORD-COUNT
           MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT
           EVALUATE TEST-NAME-TRIMMED
           WHEN SPACE
             CONTINUE
           WHEN 'TEST1'
             PERFORM P-OPER-CLOS-TEST1
           WHEN OTHER
             CONTINUE
           END-EVALUATE
           PERFORM TEARDOWN
           GOBACK
           .
       TEARDOWN.
      *     DISPLAY 'AZU0000I QSAM_STMTRPT_BNK2STMT END.'
           EXIT.
       P-OUTPUT-TEST1.
           INITIALIZE AZ-COMPARE-WORK-ITEMS
             MOVE X'00' TO AZ-INFO-COND
             MOVE X'00' TO AZ-INFO-STAT
           IF AZ-RECORD-COUNT = 0
             NEXT SENTENCE
           ELSE
             NEXT SENTENCE
           .
       P-INPUT-TEST1.
             MOVE X'00' TO AZ-INFO-COND
             MOVE X'00' TO AZ-INFO-STAT
            .
       P-OPER-OPEN-TEST1.
             MOVE X'00' TO AZ-INFO-COND
             MOVE X'00' TO AZ-INFO-STAT
           .
       P-OPER-CLOS-TEST1.
             MOVE X'00' TO AZ-INFO-COND
             MOVE X'00' TO AZ-INFO-STAT
           .
       THROW-ASSERTION.
           SET ADDRESS OF AZ-COMPARE-ITEM-NAME TO
           AZ-COMPARE-ITEM-NAME-PTR.
           SET ADDRESS OF AZ-COMPARE-ITEM-VALUE TO
           AZ-COMPARE-ITEM-VALUE-PTR.
           SET ADDRESS OF AZ-COMPARE-ITEM-EXP-VALUE TO
           AZ-COMPARE-ITEM-EXP-VALUE-PTR.
      *    DISPLAY ERROR MESSAGE AND ENDS TEST
           DISPLAY 'AZU0000I *******************************************
      -    '*************************************'
           DISPLAY 'AZU2001W THE TEST "' TEST-NAME-TRIMMED
           '" FAILED DUE TO AN ASSERTION.'
           DISPLAY 'AZU1101I ' MESSAGE-TXT OF BZ-ASSERT(1:MESSAGE-LEN
           OF BZ-ASSERT)
           DISPLAY 'AZU0000I  DATA ITEM NAME : '
           AZ-COMPARE-ITEM-NAME(1:AZ-COMPARE-ITEM-NAME-LEN)
           DISPLAY 'AZU0000I   VALUE         : '
           AZ-COMPARE-ITEM-VALUE(1:AZ-COMPARE-ITEM-VALUE-LEN)
           DISPLAY 'AZU0000I   EXPECTED VALUE: '
           AZ-COMPARE-ITEM-EXP-VALUE(1:AZ-COMPARE-ITEM-EXP-VALUE-LEN)
           DISPLAY 'AZU0000I *******************************************
      -    '*************************************'
           CALL BZUASSRT USING BZ-P1 BZ-P2 BZ-P3 BZ-ASSERT
           MOVE 1 TO TRACE-LEN OF BZ-TRACE
           MOVE 1 TO AZ-ITEM-NAME-S
           PERFORM UNTIL AZ-ITEM-NAME-S > AZ-COMPARE-ITEM-NAME-LEN
             MOVE 206 TO AZ-ITEM-NAME-LEN
             IF AZ-ITEM-NAME-S + 206 > AZ-COMPARE-ITEM-NAME-LEN
               MOVE AZ-COMPARE-ITEM-NAME-LEN TO AZ-ITEM-NAME-LEN
               SUBTRACT AZ-ITEM-NAME-S FROM AZ-ITEM-NAME-LEN
               ADD 1 TO AZ-ITEM-NAME-LEN
             END-IF
             STRING 'ITEM NAME='
             AZ-COMPARE-ITEM-NAME(AZ-ITEM-NAME-S:AZ-ITEM-NAME-LEN)
               DELIMITED BY SIZE INTO TRACE-TXT OF BZ-TRACE
               WITH POINTER TRACE-LEN OF BZ-TRACE
             END-STRING
             SUBTRACT 1 FROM TRACE-LEN OF BZ-TRACE
             SET AZ-TRACE-PTR TO ADDRESS OF TRACE-TXT OF BZ-TRACE
             CALL BZUTRACE USING BZ-TRACE
             MOVE 1 TO TRACE-LEN OF BZ-TRACE
             ADD AZ-ITEM-NAME-LEN TO AZ-ITEM-NAME-S
           END-PERFORM
           STRING 'VALUE   ='
           AZ-COMPARE-ITEM-VALUE(1:AZ-COMPARE-ITEM-VALUE-LEN)
               DELIMITED BY SIZE INTO TRACE-TXT OF BZ-TRACE
               WITH POINTER TRACE-LEN OF BZ-TRACE
             END-STRING
           SUBTRACT 1 FROM TRACE-LEN OF BZ-TRACE
           CALL BZUTRACE USING BZ-TRACE
           MOVE 1 TO TRACE-LEN OF BZ-TRACE
           STRING 'EXPECTED='
           AZ-COMPARE-ITEM-EXP-VALUE(1:AZ-COMPARE-ITEM-EXP-VALUE-LEN)
               DELIMITED BY SIZE INTO TRACE-TXT OF BZ-TRACE
               WITH POINTER TRACE-LEN OF BZ-TRACE
             END-STRING
           SUBTRACT 1 FROM TRACE-LEN OF BZ-TRACE
           CALL BZUTRACE USING BZ-TRACE
           .
       9000-UTILITY-SECTION SECTION.
       9010-TRIM-TEST-NAME.
           MOVE 0 TO TEST-NAME-LENGTH
           INSPECT TEST-NAME TALLYING TEST-NAME-LENGTH
               FOR CHARACTERS BEFORE INITIAL SPACE
           MOVE TEST-NAME(1:TEST-NAME-LENGTH) TO TEST-NAME-TRIMMED
           .
       END PROGRAM 'QSAM_STMTRPT_BNK2STMT'.
      *-----------------------------------------------------------------
      * TEST'S ROUTINE TO GET DATA AREA FOR RECORD COUNTS
      *-----------------------------------------------------------------
       IDENTIFICATION DIVISION.
       PROGRAM-ID. 'GTMEMRC'.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  BZUGTMEM            PIC  X(08) VALUE 'BZUGTMEM'.
       01  DATA-SIZE           PIC  9(08) COMP-4.
       LINKAGE SECTION.
       01  AZ-TC-WORK-AREA     PIC  X(256).
       01  AZ-GRP-INDEX        PIC  9(08).
       01  AZ-FLAG-IN          PIC  9(01).
       01  AZ-RECORD-PTR       POINTER.
       01  AZ-RECORD-PTR-VALUE
            REDEFINES AZ-RECORD-PTR PIC S9(09) COMP-5.
       01  DATA-PTR            POINTER.
       01  DATA-PTR-VALUE
            REDEFINES DATA-PTR PIC S9(09) COMP-5.
       01  DATA-AREA.
           03 RECORD-COUNT-IO OCCURS 10.
             05 RECORD-COUNT-OT PIC 9(05) COMP-5.
             05 RECORD-COUNT-IN PIC 9(05) COMP-5.
       01  WK-RECORD-COUNT     PIC  9(05) COMP-5.
       01  TEST-NAME           PIC  X(80).
       01  AZ-INFO-BLOCK.
          COPY EQAITERC.
       PROCEDURE DIVISION USING AZ-TC-WORK-AREA
                                AZ-GRP-INDEX
                                AZ-FLAG-IN
                                AZ-RECORD-PTR
           .
       0000-MAINLINE-SECTION SECTION.
       0010-MAINLINE.
           ENTRY "PGM_INPT_GTMEMRC" USING TEST-NAME
                                          AZ-INFO-BLOCK
                                          AZ-TC-WORK-AREA
                                          AZ-GRP-INDEX
                                          AZ-FLAG-IN
                                          AZ-RECORD-PTR
           SET ADDRESS OF DATA-PTR TO ADDRESS OF AZ-TC-WORK-AREA
           IF DATA-PTR-VALUE = 0
             COMPUTE DATA-SIZE = LENGTH OF WK-RECORD-COUNT * 2 * 10
             PERFORM 9020-CALL-BZUGTMEM
             SET ADDRESS OF DATA-AREA TO DATA-PTR
             DISPLAY 'AZU0000I AREA ALLOCATED FOR RECORD COUNT:'
           DATA-SIZE
           .
           SET AZ-RECORD-PTR TO DATA-PTR
           COMPUTE AZ-RECORD-PTR-VALUE = AZ-RECORD-PTR-VALUE +
             LENGTH OF WK-RECORD-COUNT * 2 * (AZ-GRP-INDEX - 1)
           IF AZ-FLAG-IN = 1
             ADD LENGTH OF WK-RECORD-COUNT TO AZ-RECORD-PTR-VALUE
           .
           SET ADDRESS OF WK-RECORD-COUNT TO AZ-RECORD-PTR
           GOBACK
           .
       9000-UTILITY-SECTION SECTION.
       9020-CALL-BZUGTMEM.
           CALL BZUGTMEM USING DATA-SIZE
                         RETURNING DATA-PTR
           .
       END PROGRAM 'GTMEMRC'.
      *+---------------------------------------------------------------+
      *| UNIT TEST FOR Z/OS: EXEC SQL SELECT_INTO                      |
      *|    FUNCTION CODE: 00E7                                        |
      *| TEST CASE VERSION: 203                                        |
      *+---------------------------------------------------------------+
       IDENTIFICATION DIVISION.
       PROGRAM-ID. 'DB2_00E7_BNK2STMT'.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *
       01  BZUASSRT          PIC  X(08)        VALUE 'BZUASSRT'.
       01  BZ-ASSERT.
           03 MESSAGE-LEN    PIC S9(04) COMP-4 VALUE 9.
           03 MESSAGE-TXT    PIC  X(254)       VALUE 'DB2 HELLO'.
       01  BZ-P1             PIC S9(09) COMP-4 VALUE 4.
       01  BZ-P2             PIC S9(09) COMP-4 VALUE 2001.
       01  BZ-P3             PIC  X(03)        VALUE 'AZU'.
      *
       01 BZ-TRACE.
         03 TRACE-LEN       PIC S9(4) COMP-4 VALUE 5.
         03 TRACE-TXT       PIC X(254) VALUE 'TRACE'.
       01 BZUTRACE          PIC X(8) VALUE 'BZUTRACE'.
       01 AZ-TRACE-PTR      POINTER.
       01 AZ-TEST-LEN        PIC S9(8) COMP.
       01 AZ-RECORD.
         03 AZ-RECORD-COUNT-OT OCCURS 1 PIC 9(5) COMP-5 VALUE 0.
         03 AZ-RECORD-COUNT-IN OCCURS 1 PIC 9(5) COMP-5 VALUE 0.
         03 AZ-OUT-PARM-NUM  PIC 9(8).
         03 AZ-IN-PARM-NUM   PIC 9(8).
         03 AZ-STMT-NUM      PIC 9(9).
       01 AZ-GRP-INDEX       PIC 9(8).
       01 AZ-FLAG-IN         PIC 9(1).
       01 AZ-RECORD-PTR      POINTER.
       01 AZ-RC-WORK         PIC S9(4) USAGE BINARY.
       01  AZ-TEST-INPUT-DATA-VALUE.
           03 AZU00000000 PIC X(4) VALUE 'CUST'.
           03 AZU00000001 PIC X(6) VALUE '987654'.
           03 AZU00000002 PIC X(10) VALUE '0000000001'.
           03 AZU00000003.
             05 PIC X(2) VALUE 'Dr'.
             05 PIC X(8) VALUE SPACES.
           03 AZU00000004.
             05 PIC X(5) VALUE 'Zsa G'.
             05 PIC X(45) VALUE SPACES.
           03 AZU00000005.
             05 PIC X(6) VALUE 'Higins'.
             05 PIC X(44) VALUE SPACES.
           03 AZU00000006 PIC X(20) VALUE SPACES.
           03 AZU00000007.
             05 PIC X(14) VALUE '74 Joshua Mews'.
             05 PIC X(36) VALUE SPACES.
           03 AZU00000008 PIC X(50) VALUE SPACES.
           03 AZU00000009.
             05 PIC X(10) VALUE 'Portsmouth'.
             05 PIC X(40) VALUE SPACES.
           03 AZU0000000A.
             05 PIC X(8) VALUE 'SW80 3CD'.
             05 PIC X(2) VALUE SPACES.
           03 AZU0000000B.
             05 PIC X(14) VALUE 'United Kingdom'.
             05 PIC X(36) VALUE SPACES.
           03 AZU0000000C.
             05 PIC X(6) VALUE 'ACTIVE'.
             05 PIC X(4) VALUE SPACES.
       01  AZ-SQLCA.
           03 AZS00000000 PIC X(136) VALUE
           X'E2D8D3C3C14040400000008800000000000040404040404040404040404
      -    '040404040404040404040404040404040404040404040404040404040404
      -    '040404040404040404040404040404040404040404040404040404040C4E
      -    '2D54040404040000000000000000000000000FFFFFFFF000000000000000
      -    '04040404040404040404040F0F0F0F0F0'.
       LOCAL-STORAGE SECTION.
       01 AZ-HOSTVAR-PTR     POINTER.
       01 AZ-HOSTVAR-PTR-ADDR
           REDEFINES AZ-HOSTVAR-PTR PIC 9(9) COMP-5.
       LINKAGE SECTION.
       01 AZ-TEST            PIC X(80).
       01 AZ-INFO-BLOCK.
          COPY EQAITERC.
       01 AZ-APLIST.
          COPY EQADB2CP.
       01 AZ-WK-RECORD-COUNT PIC 9(5) COMP-5.
       01 ARGO1.
          COPY EQADB2CV.
       01 ARGI1          .
          COPY EQADB2CV.
       01 ARGI2          .
          COPY EQADB2CV.
       01 ARGI3          .
          COPY EQADB2CV.
       01 ARGI4          .
          COPY EQADB2CV.
       01 ARGI5          .
          COPY EQADB2CV.
       01 ARGI6          .
          COPY EQADB2CV.
       01 ARGI7          .
          COPY EQADB2CV.
       01 ARGI8          .
          COPY EQADB2CV.
       01 ARGI9          .
          COPY EQADB2CV.
       01 ARGI10         .
          COPY EQADB2CV.
       01 ARGI11         .
          COPY EQADB2CV.
       01 ARGI12         .
          COPY EQADB2CV.
       01 ARGI13         .
          COPY EQADB2CV.
       01 ARGI14         .
          COPY EQADB2CV.
       01 ARGI15         .
          COPY EQADB2CV.
       01 ARGI16         .
          COPY EQADB2CV.
       01 ARGI17         .
          COPY EQADB2CV.
       01  AZU0000000D.
           03 HV-CUST-NUMBER PIC X(10).
       01  AZU0000000E.
           03 HV-CUST-EYECATCHER PIC X(4).
       01  AZU0000000F.
           03 HV-CUST-SORTCODE PIC X(6).
       01  AZU00000010.
           03 HV-CUST-NUMBER PIC X(10).
       01  AZU00000011.
           03 HV-CUST-TITLE PIC X(10).
       01  AZU00000012.
           03 HV-CUST-FIRST-NAME PIC X(50).
       01  AZU00000013.
           03 HV-CUST-LAST-NAME PIC X(50).
       01  AZU00000014.
           03 HV-CUST-DOB PIC S9(9) USAGE BINARY.
       01  AZU00000015.
           03 HV-CUST-PHONE PIC X(20).
       01  AZU00000016.
           03 HV-CUST-ADDR1 PIC X(50).
       01  AZU00000017.
           03 HV-CUST-ADDR2 PIC X(50).
       01  AZU00000018.
           03 HV-CUST-CITY PIC X(50).
       01  AZU00000019.
           03 HV-CUST-POSTCODE PIC X(10).
       01  AZU0000001A.
           03 HV-CUST-COUNTRY PIC X(50).
       01  AZU0000001B.
           03 HV-CUST-STATUS PIC X(10).
       01  AZU0000001C.
           03 HV-CUST-CREATE-DATE PIC S9(9) USAGE BINARY.
       01  AZU0000001D.
           03 HV-CUST-CREDIT-SCORE PIC S9(4) USAGE BINARY.
       01  AZU0000001E.
           03 HV-CUST-CS-REVIEW-DATE PIC S9(9) USAGE BINARY.
       01  SQLCA.
           05 SQLCAID PIC X(8).
           05 SQLCABC PIC S9(9) USAGE COMP-5.
           05 SQLCODE PIC S9(9) USAGE COMP-5.
           05 SQLERRM.
              49 SQLERRML PIC S9(4) USAGE COMP-5.
              49 SQLERRMC PIC X(70).
           05 SQLERRP PIC X(8).
           05 SQLERRD OCCURS 6 TIMES PIC S9(9) USAGE COMP-5.
           05 SQLWARN.
              10 SQLWARN0 PIC X.
              10 SQLWARN1 PIC X.
              10 SQLWARN2 PIC X.
              10 SQLWARN3 PIC X.
              10 SQLWARN4 PIC X.
              10 SQLWARN5 PIC X.
              10 SQLWARN6 PIC X.
              10 SQLWARN7 PIC X.
           05 SQLEXT.
              10 SQLWARN8 PIC X.
              10 SQLWARN9 PIC X.
              10 SQLWARNA PIC X.
              10 SQLSTATE PIC X(5).
       01 AZ-SQLDA.
          COPY EQADB2CA.
       PROCEDURE DIVISION.
      * CHECK OUTPUT VALUE
      * DB2_INPT_00E7_BNK2STMT.
           ENTRY 'DB2_INPT_00E7_BNK2STMT' USING AZ-TEST
           AZ-INFO-BLOCK AZ-APLIST ARGO1.
           DISPLAY 'AZU0000I DB2_00E7_BNK2STMT CHECK VALUES...'
           MOVE 0 TO RETURN-CODE.
           MOVE SQL-STMT-NUM OF AZ-APLIST TO AZ-STMT-NUM
           SET ADDRESS OF AZ-SQLDA TO SQL-VPARMPTR
           MOVE SQLDA-NUM OF AZ-SQLDA TO AZ-OUT-PARM-NUM
           SET ADDRESS OF AZ-SQLDA TO SQL-APARMPTR
           MOVE SQLDA-NUM OF AZ-SQLDA TO AZ-IN-PARM-NUM
           SET ADDRESS OF SQLCA TO SQL-CODEPTR OF AZ-APLIST
           MOVE 0 TO AZ-TEST-LEN.
           INSPECT AZ-TEST TALLYING AZ-TEST-LEN FOR
           CHARACTERS BEFORE INITIAL SPACE.
      * EXEC SQL SELECT_INTO : OUT=1 IN=17
           IF AZ-OUT-PARM-NUM = 1 AND
              AZ-IN-PARM-NUM = 17 THEN
             DISPLAY 'AZU0000I EXEC SQL SELECT_INTO'
              ' : OUT=' 1 ' IN=' 17
              ' L=' AZ-STMT-NUM
             MOVE SQL-AVAR-ADDR OF ARGO1 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU0000000D
             TO AZ-HOSTVAR-PTR
             MOVE 3 TO AZ-GRP-INDEX
             MOVE 0 TO AZ-FLAG-IN
             MOVE RETURN-CODE TO AZ-RC-WORK
             CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
               AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
             SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
             MOVE AZ-RC-WORK TO RETURN-CODE
             ADD 1 TO AZ-WK-RECORD-COUNT
             MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT-OT(1)
             EVALUATE AZ-TEST(1:AZ-TEST-LEN)
               WHEN SPACE
                 CONTINUE
               WHEN 'TEST1'
                 CONTINUE
               WHEN OTHER
                 CONTINUE
             END-EVALUATE
           END-IF.
           PERFORM TEARDOWN.
           GOBACK.
      * SET INPUT VALUE
      * DB2_OUTP_00E7_BNK2STMT.
           ENTRY 'DB2_OUTP_00E7_BNK2STMT' USING AZ-TEST
           AZ-INFO-BLOCK AZ-APLIST ARGI1 ARGI2 ARGI3 ARGI4 ARGI5 ARGI6
           ARGI7 ARGI8 ARGI9 ARGI10 ARGI11 ARGI12 ARGI13 ARGI14
           ARGI15 ARGI16 ARGI17.
           DISPLAY 'AZU0000I DB2_00E7_BNK2STMT INPUT VALUES...'
           MOVE 0 TO RETURN-CODE.
           MOVE SQL-STMT-NUM OF AZ-APLIST TO AZ-STMT-NUM
           SET ADDRESS OF AZ-SQLDA TO SQL-VPARMPTR
           MOVE SQLDA-NUM OF AZ-SQLDA TO AZ-OUT-PARM-NUM
           SET ADDRESS OF AZ-SQLDA TO SQL-APARMPTR
           MOVE SQLDA-NUM OF AZ-SQLDA TO AZ-IN-PARM-NUM
           SET ADDRESS OF SQLCA TO SQL-CODEPTR OF AZ-APLIST
           MOVE 0 TO AZ-TEST-LEN.
           INSPECT AZ-TEST TALLYING AZ-TEST-LEN FOR
           CHARACTERS BEFORE INITIAL SPACE.
      * EXEC SQL SELECT_INTO : OUT=1 IN=17
           IF AZ-OUT-PARM-NUM = 1 AND
              AZ-IN-PARM-NUM = 17 THEN
             DISPLAY 'AZU0000I EXEC SQL SELECT_INTO'
              ' : OUT=' 1 ' IN=' 17
              ' L=' AZ-STMT-NUM
             MOVE SQL-AVAR-ADDR OF ARGI1 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU0000000E
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI2 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU0000000F
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI3 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU00000010
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI4 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU00000011
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI5 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU00000012
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI6 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU00000013
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI7 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU00000014
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI8 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU00000015
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI9 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU00000016
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI10 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU00000017
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI11 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU00000018
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI12 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU00000019
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI13 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU0000001A
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI14 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU0000001B
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI15 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU0000001C
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI16 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU0000001D
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI17 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU0000001E
             TO AZ-HOSTVAR-PTR
             MOVE 3 TO AZ-GRP-INDEX
             MOVE 1 TO AZ-FLAG-IN
             MOVE RETURN-CODE TO AZ-RC-WORK
             CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
               AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
             SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
             MOVE AZ-RC-WORK TO RETURN-CODE
             ADD 1 TO AZ-WK-RECORD-COUNT
             MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT-IN(1)
             EVALUATE AZ-TEST(1:AZ-TEST-LEN)
               WHEN SPACE
                 CONTINUE
               WHEN 'TEST1'
                 PERFORM I00E70-TEST1
                 CONTINUE
               WHEN OTHER
                 CONTINUE
             END-EVALUATE
           END-IF.
           PERFORM TEARDOWN.
           GOBACK.
       I00E70-TEST1.
           IF AZ-RECORD-COUNT-IN(1) = 0
             NEXT SENTENCE
           ELSE IF AZ-RECORD-COUNT-IN(1) = 1
             MOVE AZS00000000 TO SQLCA
           MOVE AZU00000000 TO HV-CUST-EYECATCHER
           MOVE AZU00000001 TO HV-CUST-SORTCODE
           MOVE AZU00000002 TO HV-CUST-NUMBER OF AZU00000010
           MOVE AZU00000003 TO HV-CUST-TITLE
           MOVE AZU00000004 TO HV-CUST-FIRST-NAME
           MOVE AZU00000005 TO HV-CUST-LAST-NAME
           MOVE 19520603 TO HV-CUST-DOB
           MOVE AZU00000006 TO HV-CUST-PHONE
           MOVE AZU00000007 TO HV-CUST-ADDR1
           MOVE AZU00000008 TO HV-CUST-ADDR2
           MOVE AZU00000009 TO HV-CUST-CITY
           MOVE AZU0000000A TO HV-CUST-POSTCODE
           MOVE AZU0000000B TO HV-CUST-COUNTRY
           MOVE AZU0000000C TO HV-CUST-STATUS
           MOVE 20261027 TO HV-CUST-CREATE-DATE
           MOVE 64 TO HV-CUST-CREDIT-SCORE
           MOVE 20261116 TO HV-CUST-CS-REVIEW-DATE
           ELSE
             NEXT SENTENCE
           .
       TEARDOWN.
           DISPLAY 'AZU0000I DB2_00E7_BNK2STMT END.'
           EXIT.
       END PROGRAM 'DB2_00E7_BNK2STMT'.
      *+---------------------------------------------------------------+
      *| UNIT TEST FOR Z/OS: EXEC SQL OPEN                             |
      *|    FUNCTION CODE: 0003                                        |
      *| TEST CASE VERSION: 203                                        |
      *+---------------------------------------------------------------+
       IDENTIFICATION DIVISION.
       PROGRAM-ID. 'DB2_0003_BNK2STMT'.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *
       01  BZUASSRT          PIC  X(08)        VALUE 'BZUASSRT'.
       01  BZ-ASSERT.
           03 MESSAGE-LEN    PIC S9(04) COMP-4 VALUE 9.
           03 MESSAGE-TXT    PIC  X(254)       VALUE 'DB2 HELLO'.
       01  BZ-P1             PIC S9(09) COMP-4 VALUE 4.
       01  BZ-P2             PIC S9(09) COMP-4 VALUE 2001.
       01  BZ-P3             PIC  X(03)        VALUE 'AZU'.
      *
       01 BZ-TRACE.
         03 TRACE-LEN       PIC S9(4) COMP-4 VALUE 5.
         03 TRACE-TXT       PIC X(254) VALUE 'TRACE'.
       01 BZUTRACE          PIC X(8) VALUE 'BZUTRACE'.
       01 AZ-TRACE-PTR      POINTER.
       01 AZ-TEST-LEN        PIC S9(8) COMP.
       01 AZ-RECORD.
         03 AZ-RECORD-COUNT-OT OCCURS 1 PIC 9(5) COMP-5 VALUE 0.
         03 AZ-RECORD-COUNT-IN OCCURS 1 PIC 9(5) COMP-5 VALUE 0.
         03 AZ-OUT-PARM-NUM  PIC 9(8).
         03 AZ-IN-PARM-NUM   PIC 9(8).
         03 AZ-STMT-NUM      PIC 9(9).
       01 AZ-GRP-INDEX       PIC 9(8).
       01 AZ-FLAG-IN         PIC 9(1).
       01 AZ-RECORD-PTR      POINTER.
       01 AZ-RC-WORK         PIC S9(4) USAGE BINARY.
       01 AZ-COMPARE.
         03 AZ-COMPARE-ITEM-NAME-PTR POINTER.
         03 AZ-COMPARE-ITEM-NAME-LEN PIC S9(9) COMP-5.
         03 AZ-COMPARE-ITEM-VALUE-PTR POINTER.
         03 AZ-COMPARE-ITEM-VALUE-LEN PIC S9(9) COMP-5.
         03 AZ-COMPARE-ITEM-EXP-VALUE-PTR POINTER.
         03 AZ-COMPARE-ITEM-EXP-VALUE-LEN PIC S9(9) COMP-5.
         03 AZ-ITEM-NAME-S            PIC S9(8) COMP.
         03 AZ-ITEM-NAME-LEN          PIC S9(8) COMP.
       01  AZ-TEST-EXPECTED-DATA-VALUE.
           03 AZU00000000 PIC X(10) VALUE '0000000001'.
       01  AZ-SQLCA.
           03 AZS00000000 PIC X(136) VALUE
           X'E2D8D3C3C14040400000008800000000000040404040404040404040404
      -    '040404040404040404040404040404040404040404040404040404040404
      -    '040404040404040404040404040404040404040404040404040404040C4E
      -    '2D54040404040000000000000000000000000FFFFFFFF000000000000000
      -    '040D5404040F14040404040F0F0F0F0F0'.
       LOCAL-STORAGE SECTION.
       01 AZ-HOSTVAR-PTR     POINTER.
       01 AZ-HOSTVAR-PTR-ADDR
           REDEFINES AZ-HOSTVAR-PTR PIC 9(9) COMP-5.
       01  AZ-COMPARE-ITEM-NAMES.
           03 AZU00000001 PIC X(14) VALUE 'HV-CUST-NUMBER'.
       01  AZ-COMPARE-WORK-ITEMS.
           03 AZU00000002 PIC X(10) OCCURS 2.
       LINKAGE SECTION.
       01 AZ-TEST            PIC X(80).
       01 AZ-INFO-BLOCK.
          COPY EQAITERC.
       01 AZ-APLIST.
          COPY EQADB2CP.
       01 AZ-WK-RECORD-COUNT PIC 9(5) COMP-5.
       01 AZ-COMPARE-ITEM-NAME      PIC X(1000).
       01 AZ-COMPARE-ITEM-VALUE     PIC X(254).
       01 AZ-COMPARE-ITEM-EXP-VALUE PIC X(254).
       01 ARGO1.
          COPY EQADB2CV.
       01  AZU00000003.
           03 HV-CUST-NUMBER PIC X(10).
       01  SQLCA.
           05 SQLCAID PIC X(8).
           05 SQLCABC PIC S9(9) USAGE COMP-5.
           05 SQLCODE PIC S9(9) USAGE COMP-5.
           05 SQLERRM.
              49 SQLERRML PIC S9(4) USAGE COMP-5.
              49 SQLERRMC PIC X(70).
           05 SQLERRP PIC X(8).
           05 SQLERRD OCCURS 6 TIMES PIC S9(9) USAGE COMP-5.
           05 SQLWARN.
              10 SQLWARN0 PIC X.
              10 SQLWARN1 PIC X.
              10 SQLWARN2 PIC X.
              10 SQLWARN3 PIC X.
              10 SQLWARN4 PIC X.
              10 SQLWARN5 PIC X.
              10 SQLWARN6 PIC X.
              10 SQLWARN7 PIC X.
           05 SQLEXT.
              10 SQLWARN8 PIC X.
              10 SQLWARN9 PIC X.
              10 SQLWARNA PIC X.
              10 SQLSTATE PIC X(5).
       01 AZ-SQLDA.
          COPY EQADB2CA.
       PROCEDURE DIVISION.
      * CHECK OUTPUT VALUE
      * DB2_INPT_0003_BNK2STMT.
           ENTRY 'DB2_INPT_0003_BNK2STMT' USING AZ-TEST
           AZ-INFO-BLOCK AZ-APLIST ARGO1.
           DISPLAY 'AZU0000I DB2_0003_BNK2STMT CHECK VALUES...'
           MOVE 0 TO RETURN-CODE.
           MOVE SQL-STMT-NUM OF AZ-APLIST TO AZ-STMT-NUM
           SET ADDRESS OF AZ-SQLDA TO SQL-VPARMPTR
           MOVE SQLDA-NUM OF AZ-SQLDA TO AZ-OUT-PARM-NUM
           SET ADDRESS OF AZ-SQLDA TO SQL-APARMPTR
           MOVE SQLDA-NUM OF AZ-SQLDA TO AZ-IN-PARM-NUM
           SET ADDRESS OF SQLCA TO SQL-CODEPTR OF AZ-APLIST
           MOVE 0 TO AZ-TEST-LEN.
           INSPECT AZ-TEST TALLYING AZ-TEST-LEN FOR
           CHARACTERS BEFORE INITIAL SPACE.
      * EXEC SQL OPEN : OUT=1 IN=0
           IF AZ-OUT-PARM-NUM = 1 AND
              AZ-IN-PARM-NUM = 0 THEN
             DISPLAY 'AZU0000I EXEC SQL OPEN'
              ' : OUT=' 1 ' IN=' 0
              ' L=' AZ-STMT-NUM
             MOVE SQL-AVAR-ADDR OF ARGO1 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU00000003
             TO AZ-HOSTVAR-PTR
             MOVE 4 TO AZ-GRP-INDEX
             MOVE 0 TO AZ-FLAG-IN
             MOVE RETURN-CODE TO AZ-RC-WORK
             CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
               AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
             SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
             MOVE AZ-RC-WORK TO RETURN-CODE
             ADD 1 TO AZ-WK-RECORD-COUNT
             MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT-OT(1)
             EVALUATE AZ-TEST(1:AZ-TEST-LEN)
               WHEN SPACE
                 CONTINUE
               WHEN 'TEST1'
                 PERFORM O00030-TEST1
                 CONTINUE
               WHEN OTHER
                 CONTINUE
             END-EVALUATE
           END-IF.
           PERFORM TEARDOWN.
           GOBACK.
      * SET INPUT VALUE
      * DB2_OUTP_0003_BNK2STMT.
           ENTRY 'DB2_OUTP_0003_BNK2STMT' USING AZ-TEST
           AZ-INFO-BLOCK AZ-APLIST .
           DISPLAY 'AZU0000I DB2_0003_BNK2STMT INPUT VALUES...'
           MOVE 0 TO RETURN-CODE.
           MOVE SQL-STMT-NUM OF AZ-APLIST TO AZ-STMT-NUM
           SET ADDRESS OF AZ-SQLDA TO SQL-VPARMPTR
           MOVE SQLDA-NUM OF AZ-SQLDA TO AZ-OUT-PARM-NUM
           SET ADDRESS OF AZ-SQLDA TO SQL-APARMPTR
           MOVE SQLDA-NUM OF AZ-SQLDA TO AZ-IN-PARM-NUM
           SET ADDRESS OF SQLCA TO SQL-CODEPTR OF AZ-APLIST
           MOVE 0 TO AZ-TEST-LEN.
           INSPECT AZ-TEST TALLYING AZ-TEST-LEN FOR
           CHARACTERS BEFORE INITIAL SPACE.
      * EXEC SQL OPEN : OUT=1 IN=0
           IF AZ-OUT-PARM-NUM = 1 AND
              AZ-IN-PARM-NUM = 0 THEN
             DISPLAY 'AZU0000I EXEC SQL OPEN'
              ' : OUT=' 1 ' IN=' 0
              ' L=' AZ-STMT-NUM
             MOVE 4 TO AZ-GRP-INDEX
             MOVE 1 TO AZ-FLAG-IN
             MOVE RETURN-CODE TO AZ-RC-WORK
             CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
               AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
             SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
             MOVE AZ-RC-WORK TO RETURN-CODE
             ADD 1 TO AZ-WK-RECORD-COUNT
             MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT-IN(1)
             EVALUATE AZ-TEST(1:AZ-TEST-LEN)
               WHEN SPACE
                 CONTINUE
               WHEN 'TEST1'
                 CONTINUE
               WHEN OTHER
                 CONTINUE
             END-EVALUATE
           END-IF.
           PERFORM TEARDOWN.
           GOBACK.
       O00030-TEST1.
           INITIALIZE AZ-COMPARE-WORK-ITEMS
           IF AZ-RECORD-COUNT-OT(1) = 0
             NEXT SENTENCE
           ELSE
             NEXT SENTENCE
           .
       THROW-ASSERTION.
           SET ADDRESS OF AZ-COMPARE-ITEM-NAME TO
           AZ-COMPARE-ITEM-NAME-PTR.
           SET ADDRESS OF AZ-COMPARE-ITEM-VALUE TO
           AZ-COMPARE-ITEM-VALUE-PTR.
           SET ADDRESS OF AZ-COMPARE-ITEM-EXP-VALUE TO
           AZ-COMPARE-ITEM-EXP-VALUE-PTR.
      *    DISPLAY ERROR MESSAGE AND ENDS TEST
           DISPLAY 'AZU0000I *******************************************
      -    '*************************************'
           DISPLAY 'AZU2001W THE TEST "' AZ-TEST(1:AZ-TEST-LEN) '" FAILE
      -    'D DUE TO AN ASSERTION.'
           DISPLAY 'AZU1101I ' MESSAGE-TXT OF BZ-ASSERT(1:MESSAGE-LEN
           OF BZ-ASSERT)
           DISPLAY 'AZU0000I  DATA ITEM NAME : '
           AZ-COMPARE-ITEM-NAME(1:AZ-COMPARE-ITEM-NAME-LEN)
           DISPLAY 'AZU0000I   VALUE         : '
           AZ-COMPARE-ITEM-VALUE(1:AZ-COMPARE-ITEM-VALUE-LEN)
           DISPLAY 'AZU0000I   EXPECTED VALUE: '
           AZ-COMPARE-ITEM-EXP-VALUE(1:AZ-COMPARE-ITEM-EXP-VALUE-LEN)
           DISPLAY 'AZU0000I *******************************************
      -    '*************************************'
           CALL BZUASSRT USING BZ-P1 BZ-P2 BZ-P3 BZ-ASSERT
           MOVE 1 TO TRACE-LEN OF BZ-TRACE
           MOVE 1 TO AZ-ITEM-NAME-S
           PERFORM UNTIL AZ-ITEM-NAME-S > AZ-COMPARE-ITEM-NAME-LEN
             MOVE 206 TO AZ-ITEM-NAME-LEN
             IF AZ-ITEM-NAME-S + 206 > AZ-COMPARE-ITEM-NAME-LEN THEN
               MOVE AZ-COMPARE-ITEM-NAME-LEN TO AZ-ITEM-NAME-LEN
               SUBTRACT AZ-ITEM-NAME-S FROM AZ-ITEM-NAME-LEN
               ADD 1 TO AZ-ITEM-NAME-LEN
             END-IF
             STRING 'ITEM NAME='
             AZ-COMPARE-ITEM-NAME(AZ-ITEM-NAME-S:AZ-ITEM-NAME-LEN)
               DELIMITED BY SIZE INTO TRACE-TXT OF BZ-TRACE
               WITH POINTER TRACE-LEN OF BZ-TRACE
             END-STRING
             SUBTRACT 1 FROM TRACE-LEN OF BZ-TRACE
             SET AZ-TRACE-PTR TO ADDRESS OF TRACE-TXT OF BZ-TRACE
             CALL BZUTRACE USING BZ-TRACE
             MOVE 1 TO TRACE-LEN OF BZ-TRACE
             ADD AZ-ITEM-NAME-LEN TO AZ-ITEM-NAME-S
           END-PERFORM
           STRING 'VALUE   ='
           AZ-COMPARE-ITEM-VALUE(1:AZ-COMPARE-ITEM-VALUE-LEN)
               DELIMITED BY SIZE INTO TRACE-TXT OF BZ-TRACE
               WITH POINTER TRACE-LEN OF BZ-TRACE
             END-STRING
           SUBTRACT 1 FROM TRACE-LEN OF BZ-TRACE
           CALL BZUTRACE USING BZ-TRACE
           MOVE 1 TO TRACE-LEN OF BZ-TRACE
           STRING 'EXPECTED='
           AZ-COMPARE-ITEM-EXP-VALUE(1:AZ-COMPARE-ITEM-EXP-VALUE-LEN)
               DELIMITED BY SIZE INTO TRACE-TXT OF BZ-TRACE
               WITH POINTER TRACE-LEN OF BZ-TRACE
             END-STRING
           SUBTRACT 1 FROM TRACE-LEN OF BZ-TRACE
           CALL BZUTRACE USING BZ-TRACE
           EXIT.
           EXIT.
       TEARDOWN.
           DISPLAY 'AZU0000I DB2_0003_BNK2STMT END.'
           EXIT.
       END PROGRAM 'DB2_0003_BNK2STMT'.
      *+---------------------------------------------------------------+
      *| UNIT TEST FOR Z/OS: EXEC SQL FETCH                            |
      *|    FUNCTION CODE: 0004                                        |
      *| TEST CASE VERSION: 203                                        |
      *+---------------------------------------------------------------+
       IDENTIFICATION DIVISION.
       PROGRAM-ID. 'DB2_0004_BNK2STMT'.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *
       01  BZUASSRT          PIC  X(08)        VALUE 'BZUASSRT'.
       01  BZ-ASSERT.
           03 MESSAGE-LEN    PIC S9(04) COMP-4 VALUE 9.
           03 MESSAGE-TXT    PIC  X(254)       VALUE 'DB2 HELLO'.
       01  BZ-P1             PIC S9(09) COMP-4 VALUE 4.
       01  BZ-P2             PIC S9(09) COMP-4 VALUE 2001.
       01  BZ-P3             PIC  X(03)        VALUE 'AZU'.
      *
       01 BZ-TRACE.
         03 TRACE-LEN       PIC S9(4) COMP-4 VALUE 5.
         03 TRACE-TXT       PIC X(254) VALUE 'TRACE'.
       01 BZUTRACE          PIC X(8) VALUE 'BZUTRACE'.
       01 AZ-TRACE-PTR      POINTER.
       01 AZ-TEST-LEN        PIC S9(8) COMP.
       01 AZ-RECORD.
         03 AZ-RECORD-COUNT-OT OCCURS 1 PIC 9(5) COMP-5 VALUE 0.
         03 AZ-RECORD-COUNT-IN OCCURS 1 PIC 9(5) COMP-5 VALUE 0.
         03 AZ-OUT-PARM-NUM  PIC 9(8).
         03 AZ-IN-PARM-NUM   PIC 9(8).
         03 AZ-STMT-NUM      PIC 9(9).
       01 AZ-GRP-INDEX       PIC 9(8).
       01 AZ-FLAG-IN         PIC 9(1).
       01 AZ-RECORD-PTR      POINTER.
       01 AZ-RC-WORK         PIC S9(4) USAGE BINARY.
       01  AZ-TEST-INPUT-DATA-VALUE.
           03 AZU00000000 PIC X(8) VALUE '00000001'.
           03 AZU00000001 PIC X(8) VALUE '00000002'.
           03 AZU00000002 PIC X(8) VALUE '00000003'.
           03 AZU00000003.
             05 PIC X(3) VALUE 'ISA'.
             05 PIC X(5) VALUE SPACES.
           03 AZU00000004.
             05 PIC X(6) VALUE 'SAVING'.
             05 PIC X(2) VALUE SPACES.
           03 AZU00000005.
             05 PIC X(7) VALUE 'CURRENT'.
             05 PIC X(1) VALUE SPACES.
           03 AZU00000006 PIC X(10) VALUE '2005-03-09'.
           03 AZU00000007 PIC X(10) VALUE '1955-09-14'.
           03 AZU00000008 PIC X(10) VALUE '1968-05-06'.
       01  AZ-SQLCA.
           03 AZS00000000 PIC X(136) VALUE
           X'E2D8D3C3C14040400000008800000000000040404040404040404040404
      -    '040404040404040404040404040404040404040404040404040404040404
      -    '040404040404040404040404040404040404040404040404040404040C4E
      -    '2D54040404040000000000000000000000000FFFFFFFF000000000000000
      -    '04040404040404040404040F0F0F0F0F0'.
           03 AZS00000001 PIC X(136) VALUE
           X'E2D8D3C3C14040400000008800000000000040404040404040404040404
      -    '040404040404040404040404040404040404040404040404040404040404
      -    '040404040404040404040404040404040404040404040404040404040C4E
      -    '2D54040404040000000000000000000000000FFFFFFFF000000000000000
      -    '04040404040404040404040F0F0F0F0F0'.
           03 AZS00000002 PIC X(136) VALUE
           X'E2D8D3C3C14040400000008800000000000040404040404040404040404
      -    '040404040404040404040404040404040404040404040404040404040404
      -    '040404040404040404040404040404040404040404040404040404040C4E
      -    '2D54040404040000000000000000000000000FFFFFFFF000000000000000
      -    '04040404040404040404040F0F0F0F0F0'.
           03 AZS00000003 PIC X(136) VALUE
           X'E2D8D3C3C14040400000008800000064000040404040404040404040404
      -    '040404040404040404040404040404040404040404040404040404040404
      -    '040404040404040404040404040404040404040404040404040404040C4E
      -    '2D5E7C5C2D940FFFFFF920000000000000000FFFFFFFF000000000000000
      -    '04040404040404040404040F0F2F0F0F0'.
       LOCAL-STORAGE SECTION.
       01 AZ-HOSTVAR-PTR     POINTER.
       01 AZ-HOSTVAR-PTR-ADDR
           REDEFINES AZ-HOSTVAR-PTR PIC 9(9) COMP-5.
       LINKAGE SECTION.
       01 AZ-TEST            PIC X(80).
       01 AZ-INFO-BLOCK.
          COPY EQAITERC.
       01 AZ-APLIST.
          COPY EQADB2CP.
       01 AZ-WK-RECORD-COUNT PIC 9(5) COMP-5.
       01 ARGI1          .
          COPY EQADB2CV.
       01 ARGI2          .
          COPY EQADB2CV.
       01 ARGI3          .
          COPY EQADB2CV.
       01 ARGI4          .
          COPY EQADB2CV.
       01 ARGI5          .
          COPY EQADB2CV.
       01 ARGI6          .
          COPY EQADB2CV.
       01 ARGI7          .
          COPY EQADB2CV.
       01  AZU00000009.
           03 HV-ACC-NUMBER PIC X(8).
       01  AZU0000000A.
           03 HV-ACC-TYPE PIC X(8).
       01  AZU0000000B.
           03 HV-ACC-INT-RATE PIC S9(4)V99 USAGE PACKED-DECIMAL.
           03 HV-ACC-INT-RATE-AZ REDEFINES HV-ACC-INT-RATE.
           04 PIC X(4).
       01  AZU0000000C.
           03 HV-ACC-OPENED PIC X(10).
       01  AZU0000000D.
           03 HV-ACC-OVERDRAFT-LIM PIC S9(9) USAGE BINARY.
       01  AZU0000000E.
           03 HV-ACC-AVAIL-BAL PIC S9(10)V99 USAGE PACKED-DECIMAL.
           03 HV-ACC-AVAIL-BAL-AZ REDEFINES HV-ACC-AVAIL-BAL.
           04 PIC X(7).
       01  AZU0000000F.
           03 HV-ACC-ACTUAL-BAL PIC S9(10)V99 USAGE PACKED-DECIMAL.
           03 HV-ACC-ACTUAL-BAL-AZ REDEFINES HV-ACC-ACTUAL-BAL.
           04 PIC X(7).
       01  SQLCA.
           05 SQLCAID PIC X(8).
           05 SQLCABC PIC S9(9) USAGE COMP-5.
           05 SQLCODE PIC S9(9) USAGE COMP-5.
           05 SQLERRM.
              49 SQLERRML PIC S9(4) USAGE COMP-5.
              49 SQLERRMC PIC X(70).
           05 SQLERRP PIC X(8).
           05 SQLERRD OCCURS 6 TIMES PIC S9(9) USAGE COMP-5.
           05 SQLWARN.
              10 SQLWARN0 PIC X.
              10 SQLWARN1 PIC X.
              10 SQLWARN2 PIC X.
              10 SQLWARN3 PIC X.
              10 SQLWARN4 PIC X.
              10 SQLWARN5 PIC X.
              10 SQLWARN6 PIC X.
              10 SQLWARN7 PIC X.
           05 SQLEXT.
              10 SQLWARN8 PIC X.
              10 SQLWARN9 PIC X.
              10 SQLWARNA PIC X.
              10 SQLSTATE PIC X(5).
       01 AZ-SQLDA.
          COPY EQADB2CA.
       PROCEDURE DIVISION.
      * CHECK OUTPUT VALUE
      * DB2_INPT_0004_BNK2STMT.
           ENTRY 'DB2_INPT_0004_BNK2STMT' USING AZ-TEST
           AZ-INFO-BLOCK AZ-APLIST .
           DISPLAY 'AZU0000I DB2_0004_BNK2STMT CHECK VALUES...'
           MOVE 0 TO RETURN-CODE.
           MOVE SQL-STMT-NUM OF AZ-APLIST TO AZ-STMT-NUM
           SET ADDRESS OF AZ-SQLDA TO SQL-VPARMPTR
           MOVE SQLDA-NUM OF AZ-SQLDA TO AZ-OUT-PARM-NUM
           SET ADDRESS OF AZ-SQLDA TO SQL-APARMPTR
           MOVE SQLDA-NUM OF AZ-SQLDA TO AZ-IN-PARM-NUM
           SET ADDRESS OF SQLCA TO SQL-CODEPTR OF AZ-APLIST
           MOVE 0 TO AZ-TEST-LEN.
           INSPECT AZ-TEST TALLYING AZ-TEST-LEN FOR
           CHARACTERS BEFORE INITIAL SPACE.
      * EXEC SQL FETCH : OUT=0 IN=7
           IF AZ-OUT-PARM-NUM = 0 AND
              AZ-IN-PARM-NUM = 7 THEN
             DISPLAY 'AZU0000I EXEC SQL FETCH'
              ' : OUT=' 0 ' IN=' 7
              ' L=' AZ-STMT-NUM
             MOVE 5 TO AZ-GRP-INDEX
             MOVE 0 TO AZ-FLAG-IN
             MOVE RETURN-CODE TO AZ-RC-WORK
             CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
               AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
             SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
             MOVE AZ-RC-WORK TO RETURN-CODE
             ADD 1 TO AZ-WK-RECORD-COUNT
             MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT-OT(1)
             EVALUATE AZ-TEST(1:AZ-TEST-LEN)
               WHEN SPACE
                 CONTINUE
               WHEN 'TEST1'
                 CONTINUE
               WHEN OTHER
                 CONTINUE
             END-EVALUATE
           END-IF.
           PERFORM TEARDOWN.
           GOBACK.
      * SET INPUT VALUE
      * DB2_OUTP_0004_BNK2STMT.
           ENTRY 'DB2_OUTP_0004_BNK2STMT' USING AZ-TEST
           AZ-INFO-BLOCK AZ-APLIST ARGI1 ARGI2 ARGI3 ARGI4 ARGI5 ARGI6
           ARGI7.
           DISPLAY 'AZU0000I DB2_0004_BNK2STMT INPUT VALUES...'
           MOVE 0 TO RETURN-CODE.
           MOVE SQL-STMT-NUM OF AZ-APLIST TO AZ-STMT-NUM
           SET ADDRESS OF AZ-SQLDA TO SQL-VPARMPTR
           MOVE SQLDA-NUM OF AZ-SQLDA TO AZ-OUT-PARM-NUM
           SET ADDRESS OF AZ-SQLDA TO SQL-APARMPTR
           MOVE SQLDA-NUM OF AZ-SQLDA TO AZ-IN-PARM-NUM
           SET ADDRESS OF SQLCA TO SQL-CODEPTR OF AZ-APLIST
           MOVE 0 TO AZ-TEST-LEN.
           INSPECT AZ-TEST TALLYING AZ-TEST-LEN FOR
           CHARACTERS BEFORE INITIAL SPACE.
      * EXEC SQL FETCH : OUT=0 IN=7
           IF AZ-OUT-PARM-NUM = 0 AND
              AZ-IN-PARM-NUM = 7 THEN
             DISPLAY 'AZU0000I EXEC SQL FETCH'
              ' : OUT=' 0 ' IN=' 7
              ' L=' AZ-STMT-NUM
             MOVE SQL-AVAR-ADDR OF ARGI1 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU00000009
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI2 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU0000000A
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI3 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU0000000B
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI4 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU0000000C
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI5 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU0000000D
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI6 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU0000000E
             TO AZ-HOSTVAR-PTR
             MOVE SQL-AVAR-ADDR OF ARGI7 TO AZ-HOSTVAR-PTR-ADDR
             SET ADDRESS OF AZU0000000F
             TO AZ-HOSTVAR-PTR
             MOVE 5 TO AZ-GRP-INDEX
             MOVE 1 TO AZ-FLAG-IN
             MOVE RETURN-CODE TO AZ-RC-WORK
             CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
               AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
             SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
             MOVE AZ-RC-WORK TO RETURN-CODE
             ADD 1 TO AZ-WK-RECORD-COUNT
             MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT-IN(1)
             EVALUATE AZ-TEST(1:AZ-TEST-LEN)
               WHEN SPACE
                 CONTINUE
               WHEN 'TEST1'
                 PERFORM I00040-TEST1
                 CONTINUE
               WHEN OTHER
                 CONTINUE
             END-EVALUATE
           END-IF.
           PERFORM TEARDOWN.
           GOBACK.
       I00040-TEST1.
           IF AZ-RECORD-COUNT-IN(1) = 0
             NEXT SENTENCE
           ELSE IF AZ-RECORD-COUNT-IN(1) = 1
             MOVE AZS00000000 TO SQLCA
           MOVE AZU00000000 TO HV-ACC-NUMBER
           MOVE AZU00000003 TO HV-ACC-TYPE
           MOVE 2.10 TO HV-ACC-INT-RATE
           MOVE AZU00000006 TO HV-ACC-OPENED
           MOVE 0 TO HV-ACC-OVERDRAFT-LIM
           MOVE 631805.64 TO HV-ACC-AVAIL-BAL
           MOVE 631805.64 TO HV-ACC-ACTUAL-BAL
           ELSE IF AZ-RECORD-COUNT-IN(1) = 2
             MOVE AZS00000001 TO SQLCA
           MOVE AZU00000001 TO HV-ACC-NUMBER
           MOVE AZU00000004 TO HV-ACC-TYPE
           MOVE 1.75 TO HV-ACC-INT-RATE
           MOVE AZU00000007 TO HV-ACC-OPENED
           MOVE 0 TO HV-ACC-OVERDRAFT-LIM
           MOVE 320246.03 TO HV-ACC-AVAIL-BAL
           MOVE 320246.03 TO HV-ACC-ACTUAL-BAL
           ELSE IF AZ-RECORD-COUNT-IN(1) = 3
             MOVE AZS00000002 TO SQLCA
           MOVE AZU00000002 TO HV-ACC-NUMBER
           MOVE AZU00000005 TO HV-ACC-TYPE
           MOVE 0 TO HV-ACC-INT-RATE
           MOVE AZU00000008 TO HV-ACC-OPENED
           MOVE 100 TO HV-ACC-OVERDRAFT-LIM
           MOVE 282755.16 TO HV-ACC-AVAIL-BAL
           MOVE 282755.16 TO HV-ACC-ACTUAL-BAL
           ELSE IF AZ-RECORD-COUNT-IN(1) = 4
             MOVE AZS00000003 TO SQLCA
           MOVE AZU00000002 TO HV-ACC-NUMBER
           MOVE AZU00000005 TO HV-ACC-TYPE
           MOVE 0 TO HV-ACC-INT-RATE
           MOVE AZU00000008 TO HV-ACC-OPENED
           MOVE 100 TO HV-ACC-OVERDRAFT-LIM
           MOVE 282755.16 TO HV-ACC-AVAIL-BAL
           MOVE 282755.16 TO HV-ACC-ACTUAL-BAL
           ELSE
             NEXT SENTENCE
           .
       TEARDOWN.
           DISPLAY 'AZU0000I DB2_0004_BNK2STMT END.'
           EXIT.
       END PROGRAM 'DB2_0004_BNK2STMT'.
      *+---------------------------------------------------------------+
      *| UNIT TEST FOR Z/OS: EXEC SQL CLOSE                            |
      *|    FUNCTION CODE: 0005                                        |
      *| TEST CASE VERSION: 203                                        |
      *+---------------------------------------------------------------+
       IDENTIFICATION DIVISION.
       PROGRAM-ID. 'DB2_0005_BNK2STMT'.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *
       01  BZUASSRT          PIC  X(08)        VALUE 'BZUASSRT'.
       01  BZ-ASSERT.
           03 MESSAGE-LEN    PIC S9(04) COMP-4 VALUE 9.
           03 MESSAGE-TXT    PIC  X(254)       VALUE 'DB2 HELLO'.
       01  BZ-P1             PIC S9(09) COMP-4 VALUE 4.
       01  BZ-P2             PIC S9(09) COMP-4 VALUE 2001.
       01  BZ-P3             PIC  X(03)        VALUE 'AZU'.
      *
       01 BZ-TRACE.
         03 TRACE-LEN       PIC S9(4) COMP-4 VALUE 5.
         03 TRACE-TXT       PIC X(254) VALUE 'TRACE'.
       01 BZUTRACE          PIC X(8) VALUE 'BZUTRACE'.
       01 AZ-TRACE-PTR      POINTER.
       01 AZ-TEST-LEN        PIC S9(8) COMP.
       01 AZ-RECORD.
         03 AZ-RECORD-COUNT-OT OCCURS 1 PIC 9(5) COMP-5 VALUE 0.
         03 AZ-RECORD-COUNT-IN OCCURS 1 PIC 9(5) COMP-5 VALUE 0.
         03 AZ-OUT-PARM-NUM  PIC 9(8).
         03 AZ-IN-PARM-NUM   PIC 9(8).
         03 AZ-STMT-NUM      PIC 9(9).
       01 AZ-GRP-INDEX       PIC 9(8).
       01 AZ-FLAG-IN         PIC 9(1).
       01 AZ-RECORD-PTR      POINTER.
       01 AZ-RC-WORK         PIC S9(4) USAGE BINARY.
       01  AZ-SQLCA.
           03 AZS00000000 PIC X(136) VALUE
           LOW-VALUES.
       LOCAL-STORAGE SECTION.
       01 AZ-HOSTVAR-PTR     POINTER.
       01 AZ-HOSTVAR-PTR-ADDR
           REDEFINES AZ-HOSTVAR-PTR PIC 9(9) COMP-5.
       LINKAGE SECTION.
       01 AZ-TEST            PIC X(80).
       01 AZ-INFO-BLOCK.
          COPY EQAITERC.
       01 AZ-APLIST.
          COPY EQADB2CP.
       01 AZ-WK-RECORD-COUNT PIC 9(5) COMP-5.
       01  SQLCA.
           05 SQLCAID PIC X(8).
           05 SQLCABC PIC S9(9) USAGE COMP-5.
           05 SQLCODE PIC S9(9) USAGE COMP-5.
           05 SQLERRM.
              49 SQLERRML PIC S9(4) USAGE COMP-5.
              49 SQLERRMC PIC X(70).
           05 SQLERRP PIC X(8).
           05 SQLERRD OCCURS 6 TIMES PIC S9(9) USAGE COMP-5.
           05 SQLWARN.
              10 SQLWARN0 PIC X.
              10 SQLWARN1 PIC X.
              10 SQLWARN2 PIC X.
              10 SQLWARN3 PIC X.
              10 SQLWARN4 PIC X.
              10 SQLWARN5 PIC X.
              10 SQLWARN6 PIC X.
              10 SQLWARN7 PIC X.
           05 SQLEXT.
              10 SQLWARN8 PIC X.
              10 SQLWARN9 PIC X.
              10 SQLWARNA PIC X.
              10 SQLSTATE PIC X(5).
       01 AZ-SQLDA.
          COPY EQADB2CA.
       PROCEDURE DIVISION.
      * CHECK OUTPUT VALUE
      * DB2_INPT_0005_BNK2STMT.
           ENTRY 'DB2_INPT_0005_BNK2STMT' USING AZ-TEST
           AZ-INFO-BLOCK AZ-APLIST .
           DISPLAY 'AZU0000I DB2_0005_BNK2STMT CHECK VALUES...'
           MOVE 0 TO RETURN-CODE.
           MOVE SQL-STMT-NUM OF AZ-APLIST TO AZ-STMT-NUM
           SET ADDRESS OF AZ-SQLDA TO SQL-VPARMPTR
           MOVE SQLDA-NUM OF AZ-SQLDA TO AZ-OUT-PARM-NUM
           SET ADDRESS OF AZ-SQLDA TO SQL-APARMPTR
           MOVE SQLDA-NUM OF AZ-SQLDA TO AZ-IN-PARM-NUM
           SET ADDRESS OF SQLCA TO SQL-CODEPTR OF AZ-APLIST
           MOVE 0 TO AZ-TEST-LEN.
           INSPECT AZ-TEST TALLYING AZ-TEST-LEN FOR
           CHARACTERS BEFORE INITIAL SPACE.
      * EXEC SQL CLOSE : OUT=0 IN=0
           IF AZ-OUT-PARM-NUM = 0 AND
              AZ-IN-PARM-NUM = 0 THEN
             DISPLAY 'AZU0000I EXEC SQL CLOSE'
              ' : OUT=' 0 ' IN=' 0
              ' L=' AZ-STMT-NUM
             MOVE 6 TO AZ-GRP-INDEX
             MOVE 0 TO AZ-FLAG-IN
             MOVE RETURN-CODE TO AZ-RC-WORK
             CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
               AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
             SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
             MOVE AZ-RC-WORK TO RETURN-CODE
             ADD 1 TO AZ-WK-RECORD-COUNT
             MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT-OT(1)
             EVALUATE AZ-TEST(1:AZ-TEST-LEN)
               WHEN SPACE
                 CONTINUE
               WHEN 'TEST1'
                 CONTINUE
               WHEN OTHER
                 CONTINUE
             END-EVALUATE
           END-IF.
           PERFORM TEARDOWN.
           GOBACK.
      * SET INPUT VALUE
      * DB2_OUTP_0005_BNK2STMT.
           ENTRY 'DB2_OUTP_0005_BNK2STMT' USING AZ-TEST
           AZ-INFO-BLOCK AZ-APLIST .
           DISPLAY 'AZU0000I DB2_0005_BNK2STMT INPUT VALUES...'
           MOVE 0 TO RETURN-CODE.
           MOVE SQL-STMT-NUM OF AZ-APLIST TO AZ-STMT-NUM
           SET ADDRESS OF AZ-SQLDA TO SQL-VPARMPTR
           MOVE SQLDA-NUM OF AZ-SQLDA TO AZ-OUT-PARM-NUM
           SET ADDRESS OF AZ-SQLDA TO SQL-APARMPTR
           MOVE SQLDA-NUM OF AZ-SQLDA TO AZ-IN-PARM-NUM
           SET ADDRESS OF SQLCA TO SQL-CODEPTR OF AZ-APLIST
           MOVE 0 TO AZ-TEST-LEN.
           INSPECT AZ-TEST TALLYING AZ-TEST-LEN FOR
           CHARACTERS BEFORE INITIAL SPACE.
      * EXEC SQL CLOSE : OUT=0 IN=0
           IF AZ-OUT-PARM-NUM = 0 AND
              AZ-IN-PARM-NUM = 0 THEN
             DISPLAY 'AZU0000I EXEC SQL CLOSE'
              ' : OUT=' 0 ' IN=' 0
              ' L=' AZ-STMT-NUM
             MOVE 6 TO AZ-GRP-INDEX
             MOVE 1 TO AZ-FLAG-IN
             MOVE RETURN-CODE TO AZ-RC-WORK
             CALL 'GTMEMRC' USING TC-WORK-AREA OF AZ-INFO-BLOCK
               AZ-GRP-INDEX AZ-FLAG-IN AZ-RECORD-PTR
             SET ADDRESS OF AZ-WK-RECORD-COUNT TO AZ-RECORD-PTR
             MOVE AZ-RC-WORK TO RETURN-CODE
             ADD 1 TO AZ-WK-RECORD-COUNT
             MOVE AZ-WK-RECORD-COUNT TO AZ-RECORD-COUNT-IN(1)
             EVALUATE AZ-TEST(1:AZ-TEST-LEN)
               WHEN SPACE
                 CONTINUE
               WHEN 'TEST1'
                 PERFORM I00050-TEST1
                 CONTINUE
               WHEN OTHER
                 CONTINUE
             END-EVALUATE
           END-IF.
           PERFORM TEARDOWN.
           GOBACK.
       I00050-TEST1.
           IF AZ-RECORD-COUNT-IN(1) = 0
             NEXT SENTENCE
           ELSE IF AZ-RECORD-COUNT-IN(1) = 1
             MOVE AZS00000000 TO SQLCA
           ELSE
             NEXT SENTENCE
           .
       TEARDOWN.
           DISPLAY 'AZU0000I DB2_0005_BNK2STMT END.'
           EXIT.
       END PROGRAM 'DB2_0005_BNK2STMT'.
