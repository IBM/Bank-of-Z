      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *
      *                                                                *
      ******************************************************************
           03 CUSTOMER-RECORD.
              05 CUSTOMER-EYECATCHER                 PIC X(4).
                 88 CUSTOMER-EYECATCHER-VALUE        VALUE 'CUST'.
              05 CUSTOMER-KEY.
                 07 CUSTOMER-SORTCODE                PIC 9(6) DISPLAY.
                 07 CUSTOMER-NUMBER                  PIC 9(10) DISPLAY.
              05 CUSTOMER-TITLE                      PIC X(10).
              05 CUSTOMER-FIRST-NAME                 PIC X(50).
              05 CUSTOMER-LAST-NAME                  PIC X(50).
              05 CUSTOMER-DATE-OF-BIRTH              PIC 9(8).
              05 CUSTOMER-DOB-GROUP REDEFINES CUSTOMER-DATE-OF-BIRTH.
                 07 CUSTOMER-BIRTH-DAY               PIC 99.
                 07 CUSTOMER-BIRTH-MONTH             PIC 99.
                 07 CUSTOMER-BIRTH-YEAR              PIC 9999.
              05 CUSTOMER-EMAIL                      PIC X(100).
              05 CUSTOMER-PHONE                      PIC X(20).
              05 CUSTOMER-ADDRESS.
                 07 CUSTOMER-ADDR-LINE1              PIC X(50).
                 07 CUSTOMER-ADDR-LINE2              PIC X(50).
                 07 CUSTOMER-CITY                    PIC X(50).
                 07 CUSTOMER-POSTCODE                PIC X(10).
                 07 CUSTOMER-COUNTRY                 PIC X(50).
              05 CUSTOMER-STATUS                     PIC X(10).
                 88 CUSTOMER-STATUS-ACTIVE           VALUE 'ACTIVE'.
                 88 CUSTOMER-STATUS-INACTIVE         VALUE 'INACTIVE'.
                 88 CUSTOMER-STATUS-SUSPENDED        VALUE 'SUSPENDED'.
              05 CUSTOMER-CREATED-DATE               PIC 9(8).
              05 CUSTOMER-CREATED-GROUP REDEFINES CUSTOMER-CREATED-DATE.
                 07 CUSTOMER-CREATED-DAY             PIC 99.
                 07 CUSTOMER-CREATED-MONTH           PIC 99.
                 07 CUSTOMER-CREATED-YEAR            PIC 9999.
              05 CUSTOMER-CREDIT-SCORE               PIC 999.
              05 CUSTOMER-CS-REVIEW-DATE             PIC 9(8).
              05 CUSTOMER-CS-GROUP
                 REDEFINES CUSTOMER-CS-REVIEW-DATE.
                 07 CUSTOMER-CS-REVIEW-DAY           PIC 99.
                 07 CUSTOMER-CS-REVIEW-MONTH         PIC 99.
                 07 CUSTOMER-CS-REVIEW-YEAR          PIC 9999.
