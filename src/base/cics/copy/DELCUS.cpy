      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      *                                                                *
      ******************************************************************
          03 COMM-EYE                PIC X(4).
          03 COMM-SCODE              PIC X(6).
          03 COMM-CUSTNO             PIC X(10).
          03 COMM-TITLE              PIC X(10).
          03 COMM-FIRST-NAME         PIC X(50).
          03 COMM-LAST-NAME          PIC X(50).
          03 COMM-DOB                PIC 9(8).
          03 COMM-DOB-GROUP REDEFINES COMM-DOB.
             05 COMM-BIRTH-DAY       PIC 99.
             05 COMM-BIRTH-MONTH     PIC 99.
             05 COMM-BIRTH-YEAR      PIC 9999.
          03 COMM-EMAIL              PIC X(100).
          03 COMM-PHONE              PIC X(20).
          03 COMM-ADDR-LINE1         PIC X(50).
          03 COMM-ADDR-LINE2         PIC X(50).
          03 COMM-CITY               PIC X(50).
          03 COMM-POSTCODE           PIC X(10).
          03 COMM-COUNTRY            PIC X(50).
          03 COMM-STATUS             PIC X(10).
          03 COMM-CREATED-DATE       PIC 9(8).
          03 COMM-CREATED-DATE-GRP REDEFINES COMM-CREATED-DATE.
             05 COMM-CREATED-DD      PIC 99.
             05 COMM-CREATED-MM      PIC 99.
             05 COMM-CREATED-YYYY    PIC 9999.
          03 COMM-CREDIT-SCORE       PIC 9(3).
          03 COMM-CS-REVIEW-DATE     PIC 9(8).
          03 COMM-CS-REVIEW-GROUP REDEFINES COMM-CS-REVIEW-DATE.
             05 COMM-CS-REVIEW-DD    PIC 99.
             05 COMM-CS-REVIEW-MM    PIC 99.
             05 COMM-CS-REVIEW-YYYY  PIC 9999.
          03 COMM-DEL-SUCCESS        PIC X.
          03 COMM-DEL-FAIL-CD        PIC X.