//*
//* Copyright IBM Corp. 2023
//*
//********************************************************************
//*
//********************************************************************
//BNKSTMTX JOB 'BATCH',NOTIFY=&SYSUID,CLASS=A,MSGCLASS=H,
//          MSGLEVEL=(1,1),REGION=0M
//*
//* Step 1 - Execute
//*
//BNK1STMT EXEC PGM=IKJEFT01,DYNAMNBR=20
//STEPLIB  DD  DISP=SHR,DSN=BANKZ.V0R1M0.LOADLIB
//         DD  DISP=SHR,DSN=DB2V13.SDSNEXIT
//         DD  DISP=SHR,DSN=DB2V13.SDSNLOAD
//         DD  DISP=SHR,DSN=DBD1.RUNLIB.LOAD
//         DD  DISP=SHR,DSN=CEE.SCEERUN
//         DD  DISP=SHR,DSN=CEE.SCEERUN2
//         DD  DISP=SHR,DSN=EQAW.SEQAMOD
//*
//*  Savings Account Statement report
//*
//SAVRPT   DD  DISP=(NEW,CATLG,DELETE),
//             DSN=BANKZ.V0R1M0.BNK1STMT.SAV.REPORT,
//             UNIT=SYSALLDA,
//             SPACE=(TRK,(10,10),RLSE),
//             DCB=(RECFM=FB,LRECL=250,BLKSIZE=0)
//*
//*  ISA Account Statement report
//*
//ISARPT   DD  DISP=(NEW,CATLG,DELETE),
//             DSN=BANKZ.V0R1M0.BNK1STMT.ISA.REPORT,
//             UNIT=SYSALLDA,
//             SPACE=(TRK,(10,10),RLSE),
//             DCB=(RECFM=FB,LRECL=250,BLKSIZE=0)
//*
//*  Current Account Statement report
//*
//CURRPT   DD  DISP=(NEW,CATLG,DELETE),
//             DSN=BANKZ.V0R1M0.BNK1STMT.CUR.REPORT,
//             UNIT=SYSALLDA,
//             SPACE=(TRK,(10,10),RLSE),
//             DCB=(RECFM=FB,LRECL=250,BLKSIZE=0)
//SYSPRINT DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//CEEDUMP  DD  SYSOUT=*
//SYSTSPRT DD  SYSOUT=*
//SYSTSIN  DD  *
 DSN SYSTEM(DBD1)
 RUN PROGRAM(BNK1STMT) -
 PLAN(BANKZPLN) -
 LIB('BANKZ.V0R1M0.LOADLIB')
 END
/*
