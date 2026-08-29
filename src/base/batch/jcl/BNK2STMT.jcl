//*
//* Copyright IBM Corp. 2023
//*
//*
//********************************************************************
//BNKCSTTX JOB 'BATCH',NOTIFY=&SYSUID,CLASS=A,MSGCLASS=H,
//          MSGLEVEL=(1,1),REGION=0M
//*
//BNKCSTMT EXEC PGM=IKJEFT01,DYNAMNBR=20
//STEPLIB  DD  DISP=SHR,DSN=BANKZ.V0R1M0.LOAD
//         DD  DISP=SHR,DSN=DB2V13.SDSNEXIT
//         DD  DISP=SHR,DSN=DB2V13.SDSNLOAD
//         DD  DISP=SHR,DSN=DBD1.RUNLIB.LOAD
//         DD  DISP=SHR,DSN=CEE.SCEERUN
//         DD  DISP=SHR,DSN=CEE.SCEERUN2
//         DD  DISP=SHR,DSN=EQAW.SEQAMOD
//*
//*  Customer number input - change 0000000001 to desired customer
//*
//SYSIN    DD  *
0000000001
/*
//*
//*  Customer statement output
//*
//STMTRPT  DD  DISP=(MOD,CATLG,DELETE),
//             DSN=BANKZ.V0R1M0.BNKCSTMT.REPORT2,
//             UNIT=SYSALLDA,
//             SPACE=(TRK,(5,5),RLSE),
//             DCB=(RECFM=FB,LRECL=80,BLKSIZE=0)
//SYSPRINT DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//CEEDUMP  DD  SYSOUT=*
//SYSTSPRT DD  SYSOUT=*
//SYSTSIN  DD  *
 DSN SYSTEM(DBD1)
 RUN PROGRAM(BNK2STMT) -
 PLAN(BANKZPLN) -
 LIB('BANKZ.V0R1M0.LOAD')
 END
/*
