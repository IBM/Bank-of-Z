//DB2CRE JOB (ACCT),'IMS BANK',CLASS=A,MSGCLASS=H,NOTIFY=&SYSUID
//*********************************************************************
//*                                                                   *
//* CREATE DB2 DATABASE - IMSBANK                                     *
//*                                                                   *
//*********************************************************************
//CREATEDB EXEC PGM=IKJEFT01,DYNAMNBR=20
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
/*
//SYSIN    DD  *
CREATE DATABASE IMSBANK
CCSID EBCDIC;

CREATE TABLE "IMSBANK"."HISTORY"
(
	"TXID" BIGINT UNIQUE NOT NULL,
	"TIMESTMP" TIMESTAMP NOT NULL,
	"TRANSTYP" CHAR(1) NOT NULL,
	"AMOUNT" DECIMAL(15,2) NOT NULL,
	"REFTXID" BIGINT NOT NULL,
	"ACCID" BIGINT NOT NULL,
	"BALANCE" DECIMAL(15,2) NOT NULL
)
	AUDIT NONE
	DATA CAPTURE NONE;

GRANT ALL ON IMSBANK.HISTORY TO PUBLIC;

/*

//* Made with Bob
