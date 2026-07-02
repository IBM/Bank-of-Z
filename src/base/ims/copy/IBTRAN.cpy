      ******************************************************************
      * Licensed Materials - Property of IBM
      *
      * (c) Copyright IBM Corp. 2026.
      *
      * US Government Users Restricted Rights - Use, duplication or
      * disclosure restricted by GSA ADP Schedule Contract
      * with IBM Corp.
      ******************************************************************
      
      ******************************************************************
      *INPUT/OUTPUT MESSAGE AREA
      ******************************************************************
       01  INPUT-AREA.
           05  LL-IN           PIC  9(04) COMP.
           05  ZZ-IN           PIC  9(04) COMP.
           05  TRAN-CODE       PIC  X(08).
           05  IN-ACCID        PIC  X(18).
           05  IN-AMOUNT       PIC  X(16).
           05  IN-TRXTYPE      PIC  X(01).
           05  IN-CUSTID       PIC  X(09).

       01  OUTPUT-AREA.
           05  LL-OUT          PIC  9(04) COMP.
           05  ZZ-OUT          PIC  9(04) COMP.
           05  MSG-OUT         PIC  X(43).
           05  BAL   REDEFINES MSG-OUT.
               10 BALANCE-ZONED1      PIC  Z(13).99.
               10 FILLER              PIC  X(27).
           05  TOTAL-ACCS      PIC  9.
           05  ACCOUNT-SUMMARY OCCURS 1 TO 6 TIMES
                 DEPENDING ON TOTAL-ACCS.
               10  BALANCE-AS  PIC  S9(13)V9(2) COMP-3.
               10  ACCTYPE-AS  PIC  X(1).
               10  ACCID-AS    PIC  S9(18) COMP-5.