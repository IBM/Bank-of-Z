      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2026                                      *
      *                                                                *
      ******************************************************************
      * INQTRAND - Inquire Transaction Detail Copybook                *
      *                                                                *
      * This copybook defines the COMMAREA structure for querying     *
      * a single transaction by its composite key.                    *
      ******************************************************************
       01 INQTRAND-COMMAREA.
          03 INQTRAND-EYE                PIC X(4).
             88 INQTRAND-EYE-VALID       VALUE 'ITRD'.
          
          *> Input parameters (composite key)
          03 INQTRAND-SORTCODE           PIC 9(6).
          03 INQTRAND-ACCNO              PIC 9(8).
          03 INQTRAND-DATE               PIC 9(8).
          03 INQTRAND-TIME               PIC 9(6).
          03 INQTRAND-REF                PIC 9(12).
          
          *> Output fields
          03 INQTRAND-SUCCESS            PIC X.
             88 INQTRAND-SUCCESS-TRUE    VALUE 'Y'.
             88 INQTRAND-SUCCESS-FALSE   VALUE 'N'.
          03 INQTRAND-FOUND              PIC X.
             88 INQTRAND-FOUND-TRUE      VALUE 'Y'.
             88 INQTRAND-FOUND-FALSE     VALUE 'N'.
          
          *> Transaction details
          03 INQTRAND-TRAN-ID            PIC X(50).
          03 INQTRAND-TRAN-SORTCODE      PIC 9(6).
          03 INQTRAND-TRAN-ACCNO         PIC 9(8).
          03 INQTRAND-TRAN-DATE          PIC 9(8).
          03 INQTRAND-TRAN-DATE-GRP REDEFINES INQTRAND-TRAN-DATE.
             05 INQTRAND-TRAN-DATE-YYYY  PIC 9999.
             05 INQTRAND-TRAN-DATE-MM    PIC 99.
             05 INQTRAND-TRAN-DATE-DD    PIC 99.
          03 INQTRAND-TRAN-TIME          PIC 9(6).
          03 INQTRAND-TRAN-TIME-GRP REDEFINES INQTRAND-TRAN-TIME.
             05 INQTRAND-TRAN-TIME-HH    PIC 99.
             05 INQTRAND-TRAN-TIME-MM    PIC 99.
             05 INQTRAND-TRAN-TIME-SS    PIC 99.
          03 INQTRAND-TRAN-REF           PIC 9(12).
          03 INQTRAND-TRAN-TYPE          PIC X(3).
          03 INQTRAND-TRAN-DESC          PIC X(40).
          03 INQTRAND-TRAN-AMOUNT        PIC S9(10)V99.

      *> Made with Bob
