       CBL LIST,MAP,XREF,FLAG(I)
       IDENTIFICATION DIVISION.
       PROGRAM-ID. IBSCUDAT.

      ******************************************************************
      * Licensed Materials - Property of IBM
      *
      * (c) Copyright IBM Corp. 2026.
      *
      * US Government Users Restricted Rights - Use, duplication or
      * disclosure restricted by GSA ADP Schedule Contract
      * with IBM Corp.
      ******************************************************************

       ENVIRONMENT DIVISION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

      ******************************************************************
      * CONSTANTS
      ******************************************************************
      * RS.NEXT FAILED TO GET A ROW
       77  NOCUSTOMER      PIC  X(23) VALUE "CUSTOMER DOES NOT EXIST".

      * MESSAGE PROCESSING
       77  TERM-IO             PIC 9 VALUE 0.
       77  TERM-LOOP           PIC 9 VALUE 0.
       77  MESSAGE-EXIST       PIC X(2) VALUE 'CF'.
       77  NO-MORE-MESSAGE     PIC X(2) VALUE 'QC'.

      ******************************************************************
      *DATABASE CALL CODES
      ******************************************************************

       77  GU                  PIC  X(04)        VALUE "GU  ".
       77  GHU                 PIC  X(04)        VALUE "GHU ".
       77  GN                  PIC  X(04)        VALUE "GN  ".
       77  GHN                 PIC  X(04)        VALUE "GHN ".
       77  ISRT                PIC  X(04)        VALUE "ISRT".
       77  REPL                PIC  X(04)        VALUE "REPL".

      ******************************************************************
      *IMS STATUS CODES
      ******************************************************************

       77  GE                  PIC  X(02)        VALUE "GE".
       77  GB                  PIC  X(02)        VALUE "GB".

      ******************************************************************
      *ERROR STATUS CODE AREA
      ******************************************************************

       01  BAD-STATUS.
           05  SC-MSG  PIC X(30) VALUE "BAD STATUS CODE WAS RECEIVED: ".
           05  SC             PIC X(2).

       01  REPLFAILED.
           05  RF-MSG    PIC  X(27) VALUE "UNABLE TO UPDATE CUSTOMER: ".
           05  RF-SC       PIC X(2).

      ******************************************************************
      *SEGMENT AREAS
      ******************************************************************

       01 CUSTOMER-SEG.
           05  CUSTID-CD       PIC  S9(9) COMP-5.
           05  LASTNAME-CD     PIC  X(50).
           05  FIRSTNAME-CD    PIC  X(50).
           05  ADDRESS-CD      PIC  X(80).
           05  CITY-CD         PIC  X(25).
           05  STATE-CD        PIC  X(2).
           05  ZIPCODE-CD      PIC  X(15).
           05  PHONE-CD        PIC  X(12).
           05  STATUS-CD       PIC  X(1).
           05  PASSWORD-CD     PIC  X(16).
           05  CUSTOMERTYPE-CD PIC  X(1).
           05  LASTLOGIN-CD    PIC  X(23).

      ******************************************************************
      *INPUT/OUTPUT MESSAGE AREA
      ******************************************************************

       01  INPUT-AREA.
           05  LL-IN           PIC  9(04) COMP.
           05  ZZ-IN           PIC  9(04) COMP.
           05  TRAN-CODE       PIC  X(08).
           05  CUSTOMER-IN.
             10  CUSTID-IN       PIC  S9(9) COMP-5.
             10  LASTNAME-IN     PIC  X(50).
             10  FIRSTNAME-IN    PIC  X(50).
             10  ADDRESS-IN      PIC  X(80).
             10  CITY-IN         PIC  X(25).
             10  STATE-IN        PIC  X(2).
             10  ZIPCODE-IN      PIC  X(15).
             10  PHONE-IN        PIC  X(12).

       01  OUTPUT-AREA.
           05  LL-OUT          PIC  9(04) COMP.
           05  ZZ-OUT          PIC  9(04) COMP.
           05  MSG-OUT         PIC  X(32).
           05  CUSTOMER-OUT.
             10  CUSTID-OUT      PIC  S9(9) COMP-5.
             10  LASTNAME-OUT    PIC  X(50).
             10  FIRSTNAME-OUT   PIC  X(50).
             10  ADDRESS-OUT     PIC  X(80).
             10  CITY-OUT        PIC  X(25).
             10  STATE-OUT       PIC  X(2).
             10  ZIPCODE-OUT     PIC  X(15).
             10  PHONE-OUT       PIC  X(12).

      ******************************************************************
      *SEGMENT SEARCH ARGUMENTS
      ******************************************************************

      *    CUSTOMER-SSA1 IS USED TO FIND INFO FROM THE CUSTOMER RECORD
      *    SELECT ... WHERE sa.customer.custid = ?
      *    ALSO USED TO MARK CUSTOMER TABLE THAT USER IS LOGGED IN
      *    UPDATE ... WHERE sa.customer.custid = ?
      *    ALSO USED TO LOGOUT CUSTOMER
      *    ALSO USED TO RETRIEVE CUSTOMER INFO
      *    ALSO USED TO UPDATE CUSTOMER INFO
       01  CUSTOMER-SSA1.
           05  FILLER          PIC  X(08)        VALUE "CUSTOMER".
           05  FILLER          PIC  X(01)        VALUE "(".
           05  FILLER          PIC  X(08)        VALUE "CUSTID  ".
           05  FILLER          PIC  X(02)        VALUE "EQ".
           05  CUSTID          PIC  S9(9) COMP-5 VALUE +0.
           05  FILLER          PIC  X(01)        VALUE ")".
           05  FILLER          PIC  X(01)        VALUE ' '.

       LINKAGE SECTION.

       01  IOPCBA POINTER.
       01  DBPCB1 POINTER.

      ******************************************************************
      *I/O PCB
      ******************************************************************

       01  LTERMPCB.
           05  LOGTTERM        PIC  X(08).
           05  FILLER          PIC  X(02).
           05  TPSTAT          PIC  X(02).
           05  IODATE          PIC  X(04).
           05  IOTIME          PIC  X(04).
           05  FILLER          PIC  X(02).
           05  SEQNUM          PIC  X(02).
           05  MOD             PIC  X(08).

      ******************************************************************
      *DATABASE PCB
      ******************************************************************

       01  DBPCB.
           05  DBDNAME         PIC  X(08).
           05  SEGLEVEL        PIC  X(02).
           05  DBSTAT          PIC  X(02).
           05  PROCOPTS        PIC  X(04).
           05  FILLER          PIC  9(08) COMP.
           05  SEGNAMFB        PIC  X(08).
           05  LENKEY          PIC  9(08) COMP.
           05  SENSSSEGS       PIC  9(08) COMP.
           05  KEYFB           PIC  X(20).
           05  FILLER REDEFINES KEYFB.
               07  KEYFB1      PIC  X(9).
               07  FILLER      PIC  X(11).

       PROCEDURE DIVISION.
             ENTRY "DLITCBL"
             USING  IOPCBA, DBPCB1.

       BEGIN.
           DISPLAY '*** IBSCUDAT: PROGRAM STARTED ***'.
           MOVE 0 TO TERM-IO.
           SET ADDRESS OF LTERMPCB TO ADDRESS OF IOPCBA.
           DISPLAY '*** IBSCUDAT: ENTERING MESSAGE LOOP ***'.
           PERFORM WITH TEST BEFORE UNTIL TERM-IO = 1
              DISPLAY '*** IBSCUDAT: CALLING GU FOR INPUT MESSAGE ***'
              CALL 'CBLTDLI' USING GU, LTERMPCB, INPUT-AREA
              DISPLAY '*** IBSCUDAT: GU RETURNED, TPSTAT = ' TPSTAT
              IF TPSTAT  = '  ' OR TPSTAT = MESSAGE-EXIST
              THEN
                DISPLAY '*** IBSCUDAT: MESSAGE RECEIVED ***'
                DISPLAY '*** IBSCUDAT: TRAN-CODE = ' TRAN-CODE
                DISPLAY '*** IBSCUDAT: CUSTID-IN = ' CUSTID-IN
      * RETRIEVE CUSTOMER ACCOUNT INFO
                PERFORM SET-CUSTOMER-DATA thru SET-CUSTOMER-DATA-END

                PERFORM INSERT-IO THRU INSERT-IO-END
              ELSE
                IF TPSTAT = NO-MORE-MESSAGE
                THEN
                  DISPLAY '*** IBSCUDAT: NO MORE MESSAGES ***'
                  MOVE 1 TO TERM-IO
                ELSE
                  DISPLAY 'GU FROM IOPCB FAILED WITH STATUS CODE: '
                    TPSTAT
                END-IF
              END-IF
           END-PERFORM.
           DISPLAY '*** IBSCUDAT: PROGRAM ENDING ***'.
           STOP RUN.

      * PROCEDURE SET-CUSTOMER-DATA
       SET-CUSTOMER-DATA.
      *    SET A CUSTOMER'S DATA
           DISPLAY '*** SET-CUSTOMER-DATA: STARTING ***'.
           DISPLAY '*** INPUT DATA RECEIVED: ***'.
           DISPLAY '*** CUSTID-IN = ' CUSTID-IN.
           DISPLAY '*** FIRSTNAME-IN = ' FIRSTNAME-IN.
           DISPLAY '*** LASTNAME-IN = ' LASTNAME-IN.
           DISPLAY '*** ADDRESS-IN = ' ADDRESS-IN.
           DISPLAY '*** CITY-IN = ' CITY-IN.
           DISPLAY '*** STATE-IN = ' STATE-IN.
           DISPLAY '*** ZIPCODE-IN = ' ZIPCODE-IN.
           DISPLAY '*** PHONE-IN = ' PHONE-IN.
           MOVE ZEROS TO OUTPUT-AREA.
           MOVE CUSTID-IN TO CUSTID.
           DISPLAY '*** SET-CUSTOMER-DATA: CUSTID = ' CUSTID.
           SET ADDRESS OF DBPCB TO ADDRESS OF DBPCB1.
           DISPLAY '*** SET-CUSTOMER-DATA: CALLING GHU ***'.
           CALL 'CBLTDLI'
             USING GHU, DBPCB, CUSTOMER-SEG, CUSTOMER-SSA1.
           DISPLAY '*** SET-CUSTOMER-DATA: GHU RETURNED, DBSTAT = '
             DBSTAT.
           IF DBSTAT = SPACES
      *      UPDATE THE CUSTOMER'S DATA
             DISPLAY '*** SET-CUSTOMER-DATA: CUSTOMER FOUND ***'
             DISPLAY '*** OLD DATA FROM DATABASE: ***'
             DISPLAY '*** OLD FIRSTNAME-CD = ' FIRSTNAME-CD
             DISPLAY '*** OLD LASTNAME-CD = ' LASTNAME-CD
             DISPLAY '*** OLD ADDRESS-CD = ' ADDRESS-CD
             DISPLAY '*** OLD CITY-CD = ' CITY-CD
             DISPLAY '*** OLD STATE-CD = ' STATE-CD
             DISPLAY '*** OLD ZIPCODE-CD = ' ZIPCODE-CD
             DISPLAY '*** OLD PHONE-CD = ' PHONE-CD
             MOVE FIRSTNAME-IN TO FIRSTNAME-CD
             MOVE LASTNAME-IN TO LASTNAME-CD
             MOVE ADDRESS-IN TO ADDRESS-CD
             MOVE CITY-IN TO CITY-CD
             MOVE STATE-IN TO STATE-CD
             MOVE ZIPCODE-IN TO ZIPCODE-CD
             MOVE PHONE-IN TO PHONE-CD
             DISPLAY '*** NEW DATA TO UPDATE: ***'
             DISPLAY '*** NEW FIRSTNAME-CD = ' FIRSTNAME-CD
             DISPLAY '*** NEW LASTNAME-CD = ' LASTNAME-CD
             DISPLAY '*** NEW ADDRESS-CD = ' ADDRESS-CD
             DISPLAY '*** NEW CITY-CD = ' CITY-CD
             DISPLAY '*** NEW STATE-CD = ' STATE-CD
             DISPLAY '*** NEW ZIPCODE-CD = ' ZIPCODE-CD
             DISPLAY '*** NEW PHONE-CD = ' PHONE-CD
             DISPLAY '*** SET-CUSTOMER-DATA: CALLING REPL ***'
             CALL 'CBLTDLI'
               USING REPL, DBPCB, CUSTOMER-SEG
             DISPLAY '*** SET-CUSTOMER-DATA: REPL RETURNED, DBSTAT = '
               DBSTAT
             IF DBSTAT = SPACES
               DISPLAY '*** SET-CUSTOMER-DATA: UPDATE SUCCESSFUL ***'
               MOVE CUSTOMER-IN TO CUSTOMER-OUT
             ELSE
               DISPLAY '*** SET-CUSTOMER-DATA: UPDATE FAILED ***'
               MOVE DBSTAT TO RF-SC
               MOVE REPLFAILED TO MSG-OUT
             END-IF
           ELSE
             IF DBSTAT = GB OR DBSTAT = GE
               DISPLAY '*** SET-CUSTOMER-DATA: CUSTOMER NOT FOUND ***'
               MOVE NOCUSTOMER TO MSG-OUT
             ELSE
               DISPLAY '*** SET-CUSTOMER-DATA: BAD STATUS CODE ***'
               MOVE DBSTAT TO SC
               MOVE BAD-STATUS TO MSG-OUT
             END-IF
           END-IF.
           DISPLAY '*** SET-CUSTOMER-DATA: ENDING ***'.
       SET-CUSTOMER-DATA-END.

      * PROCEDURE INSERT-IO : INSERT FOR IOPCB REQUEST HANDLER

       INSERT-IO.
           DISPLAY '*** INSERT-IO: STARTING ***'.
           COMPUTE LL-OUT = LENGTH OF OUTPUT-AREA.
           MOVE 0 TO ZZ-OUT.
           DISPLAY '*** INSERT-IO: LL-OUT = ' LL-OUT.
           DISPLAY '*** INSERT-IO: MSG-OUT = ' MSG-OUT.
           DISPLAY '*** INSERT-IO: CALLING ISRT ***'.
           CALL 'CBLTDLI' USING ISRT, LTERMPCB, OUTPUT-AREA.
           DISPLAY '*** INSERT-IO: ISRT RETURNED, TPSTAT = ' TPSTAT.
           IF TPSTAT NOT = SPACES
             THEN
             DISPLAY 'INSERT TO IOPCB FAILED WITH STATUS CODE: '
                TPSTAT
           ELSE
             DISPLAY '*** INSERT-IO: OUTPUT SENT SUCCESSFULLY ***'
           END-IF.
           DISPLAY '*** INSERT-IO: ENDING ***'.
       INSERT-IO-END.