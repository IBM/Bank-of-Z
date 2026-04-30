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
                CUSTOMER_TITLE                 CHAR(10),
                CUSTOMER_FIRST_NAME            CHAR(50),
                CUSTOMER_LAST_NAME             CHAR(50),
                CUSTOMER_DATE_OF_BIRTH         INTEGER,
                CUSTOMER_PHONE                 CHAR(20),
                CUSTOMER_ADDR_LINE1            CHAR(50),
                CUSTOMER_ADDR_LINE2            CHAR(50),
                CUSTOMER_CITY                  CHAR(50),
                CUSTOMER_POSTCODE              CHAR(10),
                CUSTOMER_COUNTRY               CHAR(50),
                CUSTOMER_STATUS                CHAR(10),
                CUSTOMER_CREATED_DATE          INTEGER,
                CUSTOMER_CREDIT_SCORE          SMALLINT,
                CUSTOMER_CS_REVIEW_DATE        INTEGER,
                CUSTOMER_EMAIL                 CHAR(60) )
           END-EXEC.
