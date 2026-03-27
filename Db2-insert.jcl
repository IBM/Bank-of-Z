//INSTDB2 JOB 'DB2',NOTIFY=&SYSUID,CLASS=A,MSGCLASS=H,
//          MSGLEVEL=(1,1),REGION=4M
//JOBLIB  DD  DISP=SHR,DSN=DB2V13.SDSNLOAD
//GRANT   EXEC PGM=IKJEFT01,DYNAMNBR=20
//SYSTSPRT DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//* //SYSTSIN  DD  *
//*   DSN SYSTEM(DBD1)
//*   RUN PROGRAM(DSNTEP2)  PLAN(DSNTEP13) -
//*        LIB('DBD1.RUNLIB.LOAD') PARMS('/ALIGN(MID)')
//*   END
//* /*
//SYSTSIN    DD  *
 DSN SYSTEM(DBD1)
 RUN PROGRAM(BANKDATA)  -
 PLAN(CBSAPLAN) -
 PARM('1,10000,1,1000000000000000') -
 LIB('IBMUSER.BOZ.BLD.LOAD')
 END
/*
//* //SYSIN    DD  *
//* SET CURRENT SQLID = 'IBMUSER';

//* DELETE * FROM IBMUSER.CUSTOMER;
//* DELETE * FROM IBMUSER.ACCOUNT;
//* DELETE * FROM IBMUSER.CONTROL;

//* -- Insert CONTROL records for customer counters

//* -- Default sortcode from SORTCODE.cpy (987654)
//* -- Set to 1 since test data already has customer 0000000001
//* INSERT INTO IBMUSER.CONTROL (
//*     CONTROL_NAME,
//*     CONTROL_VALUE_NUM,
//*     CONTROL_VALUE_STR
//* ) VALUES (
//*     'CBSACUST987654  ',
//*     1,
//*     ''
//* );

//* -- Common test sortcodes (0005OCCS through 0009OCCS)
//* INSERT INTO IBMUSER.CONTROL (
//*     CONTROL_NAME,
//*     CONTROL_VALUE_NUM,
//*     CONTROL_VALUE_STR
//* ) VALUES (
//*     'CBSACUST0005OCCS  ',
//*     0,
//*     ''
//* );

//* INSERT INTO IBMUSER.CONTROL (
//*     CONTROL_NAME,
//*     CONTROL_VALUE_NUM,
//*     CONTROL_VALUE_STR
//* ) VALUES (
//*     'CBSACUST0006OCCS  ',
//*     0,
//*     ''
//* );

//* INSERT INTO IBMUSER.CONTROL (
//*     CONTROL_NAME,
//*     CONTROL_VALUE_NUM,
//*     CONTROL_VALUE_STR
//* ) VALUES (
//*     'CBSACUST0007OCCS  ',
//*     0,
//*     ''
//* );

//* INSERT INTO IBMUSER.CONTROL (
//*     CONTROL_NAME,
//*     CONTROL_VALUE_NUM,
//*     CONTROL_VALUE_STR
//* ) VALUES (
//*     'CBSACUST0008OCCS  ',
//*     0,
//*     ''
//* );

//* INSERT INTO IBMUSER.CONTROL (
//*     CONTROL_NAME,
//*     CONTROL_VALUE_NUM,
//*     CONTROL_VALUE_STR
//* ) VALUES (
//*     'CBSACUST0009OCCS  ',
//*     0,
//*     ''
//* );

//* -- Default sortcode 987654
//* INSERT INTO IBMUSER.CONTROL (
//*     CONTROL_NAME,
//*     CONTROL_VALUE_NUM,
//*     CONTROL_VALUE_STR
//* ) VALUES (
//*     '987654-ACCOUNT-LAST',
//*     1,
//*     ''
//* );

//* INSERT INTO IBMUSER.CONTROL (
//*     CONTROL_NAME,
//*     CONTROL_VALUE_NUM,
//*     CONTROL_VALUE_STR
//* ) VALUES (
//*     '987654-ACCOUNT-COUNT',
//*     1,
//*     ''
//* );

//* INSERT INTO IBMUSER.CUSTOMER (
//*     CUSTOMER_EYECATCHER,
//*     CUSTOMER_SORTCODE,
//*     CUSTOMER_NUMBER,
//*     CUSTOMER_NAME,
//*     CUSTOMER_ADDRESS,
//*     CUSTOMER_DATE_OF_BIRTH,
//*     CUSTOMER_CREDIT_SCORE,
//*     CUSTOMER_CS_REVIEW_DATE
//* ) VALUES (
//*     'CUST',
//*     '987654',
//*     '0000000001',
//*     'John Smith',
//*     '123 Main Street, London, UK, SW1A 1AA',
//*     19850615,
//*     750,
//*     20240101
//* );

//* INSERT INTO IBMUSER.ACCOUNT (
//*     ACCOUNT_EYECATCHER,
//*     ACCOUNT_CUSTOMER_NUMBER,
//*     ACCOUNT_SORTCODE,
//*     ACCOUNT_NUMBER,
//*     ACCOUNT_TYPE,
//*     ACCOUNT_INTEREST_RATE,
//*     ACCOUNT_OPENED,
//*     ACCOUNT_OVERDRAFT_LIMIT,
//*     ACCOUNT_LAST_STATEMENT,
//*     ACCOUNT_NEXT_STATEMENT,
//*     ACCOUNT_AVAILABLE_BALANCE,
//*     ACCOUNT_ACTUAL_BALANCE
//* ) VALUES (
//*     'ACCT',
//*     '0000000001',
//*     '987654',
//*     '00000001',
//*     'CURRENT',
//*     0.50,
//*     '2024-01-01',
//*     1000,
//*     '2024-01-31',
//*     '2024-02-29',
//*     2500.00,
//*     2500.00
//* );

//* SELECT * FROM IBMUSER.CUSTOMER;

//* SELECT * FROM IBMUSER.ACCOUNT;

//* /*
