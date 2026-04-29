      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      *                                                                *
      ******************************************************************
          03 COMM-EYE                PIC X(4).
          03 COMM-SCODE              PIC X(6).
          03 COMM-CUSTNO             PIC X(10).
          03 COMM-NAME.
             05 COMM-TITLE           PIC X(10).
             05 COMM-FIRST-NAME      PIC X(50).
             05 COMM-LAST-NAME       PIC X(50).
          03 COMM-DOB.
             05 COMM-DOB-DAY         PIC 99 DISPLAY.
             05 COMM-DOB-MONTH       PIC 99 DISPLAY.
             05 COMM-DOB-YEAR        PIC 9999 DISPLAY.
          03 COMM-EMAIL              PIC X(100).
          03 COMM-PHONE              PIC X(20).
          03 COMM-ADDR.
             05 COMM-ADDR-LINE1      PIC X(50).
             05 COMM-ADDR-LINE2      PIC X(50).
             05 COMM-CITY            PIC X(50).
             05 COMM-POSTCODE        PIC X(10).
             05 COMM-COUNTRY         PIC X(50).
          03 COMM-STATUS             PIC X(10).
          03 COMM-CREATED-DATE.
             05 COMM-CREATED-DAY     PIC 99 DISPLAY.
             05 COMM-CREATED-MONTH   PIC 99 DISPLAY.
             05 COMM-CREATED-YEAR    PIC 9999 DISPLAY.
          03 COMM-CREDIT-SCORE       PIC 9(3).
          03 COMM-CS-REVIEW-DATE.
             05 COMM-CS-REVIEW-DAY   PIC 99 DISPLAY.
             05 COMM-CS-REVIEW-MONTH PIC 99 DISPLAY.
             05 COMM-CS-REVIEW-YEAR  PIC 9999 DISPLAY.
          03 COMM-DEL-SUCCESS        PIC X.
          03 COMM-DEL-FAIL-CD        PIC X.