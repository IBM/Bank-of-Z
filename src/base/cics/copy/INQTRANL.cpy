      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2026                                      *
      *                                                                *
      ******************************************************************
      * INQTRANL - Inquire Transaction List Copybook                  *
      *                                                                *
      * This copybook defines the COMMAREA structure for querying     *
      * transaction lists by account with date filtering and          *
      * pagination support.                                            *
      ******************************************************************
       01 INQTRANL-COMMAREA.
          03 INQTRANL-EYE                PIC X(4).
             88 INQTRANL-EYE-VALID       VALUE 'ITRL'.
          
          *> Input parameters
          03 INQTRANL-SORTCODE           PIC 9(6).
          03 INQTRANL-ACCNO              PIC 9(8).
          03 INQTRANL-FROM-DATE          PIC 9(8).
             88 INQTRANL-NO-FROM-DATE    VALUE 0.
          03 INQTRANL-TO-DATE            PIC 9(8).
             88 INQTRANL-NO-TO-DATE      VALUE 99999999.
          03 INQTRANL-LIMIT              PIC 9(3).
             88 INQTRANL-DEFAULT-LIMIT   VALUE 50.
          03 INQTRANL-OFFSET             PIC 9(5).
          
          *> Output metadata
          03 INQTRANL-TOTAL-COUNT        PIC 9(5).
          03 INQTRANL-RETURNED-COUNT     PIC 9(3).
          03 INQTRANL-SUCCESS            PIC X.
             88 INQTRANL-SUCCESS-TRUE    VALUE 'Y'.
             88 INQTRANL-SUCCESS-FALSE   VALUE 'N'.
          
          *> Transaction array (max 100 per OpenAPI spec)
          03 INQTRANL-TRANSACTIONS OCCURS 100 TIMES.
             05 INQTRANL-TRAN-ID         PIC X(50).
             05 INQTRANL-TRAN-SORTCODE   PIC 9(6).
             05 INQTRANL-TRAN-ACCNO      PIC 9(8).
             05 INQTRANL-TRAN-DATE       PIC 9(8).
             05 INQTRANL-TRAN-DATE-GRP REDEFINES INQTRANL-TRAN-DATE.
                07 INQTRANL-TRAN-DATE-YYYY PIC 9999.
                07 INQTRANL-TRAN-DATE-MM   PIC 99.
                07 INQTRANL-TRAN-DATE-DD   PIC 99.
             05 INQTRANL-TRAN-TIME       PIC 9(6).
             05 INQTRANL-TRAN-TIME-GRP REDEFINES INQTRANL-TRAN-TIME.
                07 INQTRANL-TRAN-TIME-HH   PIC 99.
                07 INQTRANL-TRAN-TIME-MM   PIC 99.
                07 INQTRANL-TRAN-TIME-SS   PIC 99.
             05 INQTRANL-TRAN-REF        PIC 9(12).
             05 INQTRANL-TRAN-TYPE       PIC X(3).
             05 INQTRANL-TRAN-DESC       PIC X(40).
             05 INQTRANL-TRAN-AMOUNT     PIC S9(10)V99.

      *> Made with Bob
