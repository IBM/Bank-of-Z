//DB2DROP JOB (ACCT),'IMS BANK',CLASS=A,MSGCLASS=H,NOTIFY=&SYSUID
//*********************************************************************
//*                                                                   *
//* DROP DB2 DATABASE - IMSBANK                                       *
//*                                                                   *
//*********************************************************************
//DROPDB2 EXEC PGM=IKJEFT01,DYNAMNBR=20
//STEPLIB  DD  DISP=SHR,DSN=DB2V13.SDSNEXIT
//         DD  DISP=SHR,DSN=DB2V13.SDSNLOAD
//SYSTSPRT DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//SYSTSIN  DD  *
  DSN SYSTEM(DBD1)
  RUN PROGRAM(DSNTEP2) PLAN(DSNTEP13) -
       LIB('DBD1.RUNLIB.LOAD')
  END
//SYSIN    DD  *
DROP TABLE "IMSBANK"."HISTORY";
DROP DATABASE IMSBANK ;
/*

//* Made with Bob
