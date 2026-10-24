//BNKSTMTC JOB 'BATCH',NOTIFY=&SYSUID,CLASS=A,MSGCLASS=H,
//          MSGLEVEL=(1,1),REGION=0M
//*
//* Copyright IBM Corp. 2026
//*
//********************************************************************
//*
//*  BNKSTMTC - Bank of Z Monthly Customer Statement (COBOL)
//*
//*  Happy-path: prints the October 2026 statement for customer
//*  C000000001.  Change the SYSIN record to run for a different
//*  customer or period.
//*
//*  DD names:
//*    SYSIN    - 80-byte control card  (<CustID> <YYYY-MM>)
//*    SYSOUT   - Diagnostic / informational messages (SYSOUT=*)
//*    SYSPRINT - FBA 133-byte formatted statement report
//*
//*  Return codes:
//*    0  - Clean run, all accounts and transactions present
//*    4  - Informational condition (BNKZI messages emitted)
//*    8  - Error condition     (BNKZE messages emitted)
//*   12  - SYSOUT unavailable (no diagnostics possible)
//*
//********************************************************************
//*
//* Execute BNKSTMTC via DSN to attach to Db2
//*
//BNKSTMTC EXEC PGM=IKJEFT01,DYNAMNBR=20
//STEPLIB  DD  DISP=SHR,DSN=BANKZ.V0R1M0.LOAD
//         DD  DISP=SHR,DSN=DB2V13.SDSNEXIT
//         DD  DISP=SHR,DSN=DB2V13.SDSNLOAD
//         DD  DISP=SHR,DSN=DBD1.RUNLIB.LOAD
//         DD  DISP=SHR,DSN=CEE.SCEERUN
//         DD  DISP=SHR,DSN=CEE.SCEERUN2
//*
//*  Control card: <CustomerID> <YYYY-MM>
//*  Customer ID format: C<digits> (CICS) or I<digits> (IMS)
//*  Change C000000001 to the desired customer number.
//*  Change 2026-10 to the desired statement period.
//*
//SYSIN    DD  *
C000000001 2026-10
/*
//SYSPRINT DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//CEEDUMP  DD  SYSOUT=*
//SYSTSPRT DD  SYSOUT=*
//SYSTSIN  DD  *
 DSN SYSTEM(DBD1)
 RUN PROGRAM(BNKSTMTC) -
 PLAN(BANKZPLN) -
 LIB('BANKZ.V0R1M0.LOAD')
 END
/*
