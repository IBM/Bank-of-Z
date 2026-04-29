      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      *                                                                *
      ******************************************************************
          03 INQCUST-EYE                  PIC X(4).
          03 INQCUST-SCODE                PIC X(6).
          03 INQCUST-CUSTNO               PIC 9(10).
          03 INQCUST-TITLE                PIC X(10).
          03 INQCUST-FIRST-NAME           PIC X(50).
          03 INQCUST-LAST-NAME            PIC X(50).
          03 INQCUST-DOB.
            05 INQCUST-DOB-DD             PIC 99.
            05 INQCUST-DOB-MM             PIC 99.
            05 INQCUST-DOB-YYYY           PIC 9999.
          03 INQCUST-EMAIL                PIC X(100).
          03 INQCUST-PHONE                PIC X(20).
          03 INQCUST-ADDR.
            05 INQCUST-ADDR-LINE1         PIC X(50).
            05 INQCUST-ADDR-LINE2         PIC X(50).
            05 INQCUST-CITY               PIC X(50).
            05 INQCUST-POSTCODE           PIC X(10).
            05 INQCUST-COUNTRY            PIC X(50).
          03 INQCUST-STATUS               PIC X(10).
          03 INQCUST-CREATED-DATE.
            05 INQCUST-CREATED-DD         PIC 99.
            05 INQCUST-CREATED-MM         PIC 99.
            05 INQCUST-CREATED-YYYY       PIC 9999.
          03 INQCUST-CREDIT-SCORE         PIC 999.
          03 INQCUST-CS-REVIEW-DT.
            05 INQCUST-CS-REVIEW-DD       PIC 99.
            05 INQCUST-CS-REVIEW-MM       PIC 99.
            05 INQCUST-CS-REVIEW-YYYY     PIC 9999.
          03 INQCUST-INQ-SUCCESS          PIC X.
          03 INQCUST-INQ-FAIL-CD          PIC X.
          03 INQCUST-PCB-POINTER          POINTER.
