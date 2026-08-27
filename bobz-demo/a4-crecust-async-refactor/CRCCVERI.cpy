      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      *  CRCCVERI - Credit Check Verification COMMAREA                *
      *                                                                *
      *  Input  : CCVERI-SORTCODE, CCVERI-NAME, CCVERI-DOB,           *
      *           CCVERI-PHONE, CCVERI-ADDR, CCVERI-STATUS,           *
      *           CCVERI-CREATED-DATE                                  *
      *  Output : CCVERI-CREDIT-SCORE, CCVERI-CS-REVIEW-DATE,         *
      *           CCVERI-SUCCESS, CCVERI-FAIL-CODE                     *
      *                                                                *
      ******************************************************************
          03 CCVERI-SORTCODE             PIC 9(6)  DISPLAY.
          03 CCVERI-NAME.
             05 CCVERI-TITLE             PIC X(10).
             05 CCVERI-FIRST-NAME        PIC X(50).
             05 CCVERI-LAST-NAME         PIC X(50).
          03 CCVERI-DOB.
             05 CCVERI-DOB-DAY           PIC 99 DISPLAY.
             05 CCVERI-DOB-MONTH         PIC 99 DISPLAY.
             05 CCVERI-DOB-YEAR          PIC 9999 DISPLAY.
          03 CCVERI-PHONE                PIC X(20).
          03 CCVERI-ADDR.
             05 CCVERI-ADDR-LINE1        PIC X(50).
             05 CCVERI-ADDR-LINE2        PIC X(50).
             05 CCVERI-CITY              PIC X(50).
             05 CCVERI-POSTCODE          PIC X(10).
             05 CCVERI-COUNTRY           PIC X(50).
          03 CCVERI-STATUS               PIC X(10).
          03 CCVERI-CREATED-DATE.
             05 CCVERI-CREATED-DAY       PIC 99 DISPLAY.
             05 CCVERI-CREATED-MONTH     PIC 99 DISPLAY.
             05 CCVERI-CREATED-YEAR      PIC 9999 DISPLAY.
      *   --- OUTPUT fields ---
          03 CCVERI-CREDIT-SCORE         PIC 999.
          03 CCVERI-CS-REVIEW-DATE.
             05 CCVERI-CS-REVIEW-DAY     PIC 99 DISPLAY.
             05 CCVERI-CS-REVIEW-MONTH   PIC 99 DISPLAY.
             05 CCVERI-CS-REVIEW-YEAR    PIC 9999 DISPLAY.
          03 CCVERI-SUCCESS              PIC X.
          03 CCVERI-FAIL-CODE            PIC X.
