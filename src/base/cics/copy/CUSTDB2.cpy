      ******************************************************************
      *                                                                *
      *  Copyright IBM Corp. 2023                                      *
      *                                                                *
      *  Db2 CUSTOMER Table Declaration                               *
      *                                                                *
      ******************************************************************
           EXEC SQL DECLARE CUSTOMER TABLE
              ( CUSTOMER_EYECATCHER            CHAR(4),
                CUSTOMER_SORTCODE              CHAR(6) NOT NULL,
                CUSTOMER_NUMBER                CHAR(10) NOT NULL,
                CUSTOMER_NAME                  CHAR(60),
                CUSTOMER_ADDRESS               CHAR(160),
                CUSTOMER_DATE_OF_BIRTH         INTEGER,
                CUSTOMER_CREDIT_SCORE          SMALLINT,
                CUSTOMER_CS_REVIEW_DATE        INTEGER,
                CUSTOMER_EMAIL                 CHAR(60) )
           END-EXEC.
