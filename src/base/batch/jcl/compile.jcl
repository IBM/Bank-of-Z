//BNKSTMTC JOB ,
//    MSGCLASS=H,MSGLEVEL=1,TIME=(20,0),
//    REGION=0M,NOTIFY=&SYSUID
//*
//* NOTE: This JCL is not required - the code is being built by DBB
//* 
//********************************************************************
//* BNKSTMTC - Compile, Link-Edit and DB2 Bind for BNK1STMT
//*
//* Uses the same CLBIND proc pattern as compile_DONE.jcl.
//*
//* Prerequisites:
//*   BNK1STMT.cbl uploaded to USER.VK.COBOL(BNK1STMT)
//*   Copybooks (CUSTDB2, ACCDB2) in BANKZ.DBB.COPY
//*
//********************************************************************
//*
//*-------------------------------------------------------------------*
//* CLBIND proc - Compile then Link-Edit
//*-------------------------------------------------------------------*
//CLBIND PROC
//*
//COBOL  EXEC PGM=IGYCRCTL,REGION=&REG.,
//        PARM=('&EPARM1.,&EPARM2.,&EPARM3.')
//STEPLIB DD  DISP=SHR,DSN=&IGY..SIGYCOMP
//        DD  DISP=SHR,DSN=&SDSNLOAD.
//        DD  DISP=SHR,DSN=&LEHLQ..SCEERUN
//        DD  DISP=SHR,DSN=&LEHLQ..SCEERUN
//        DD  DISP=SHR,DSN=&LEHLQ..SCEERUN2
//        DD  DISP=SHR,DSN=SYS1.MIGLIB
//SYSLIB DD  DISP=SHR,DSN=&COPYLIB.
//       DD  DISP=SHR,DSN=CEE.SCEESAMP
//SYSIN  DD  DISP=SHR,DSN=&SRCLIB.(&MEM.)
//SYSLIN DD  DSN=&&LOADSET,DISP=(MOD,PASS),
//           UNIT=SYSDA,SPACE=(CYL,(1,1))
//DBRMLIB DD  DSN=&DBRMLIB.(&MEM.),DISP=OLD
//SYSMDECK DD  UNIT=SYSDA,SPACE=(CYL,(1,2))
//SYSPRINT DD  SYSOUT=*
//SYSUT1  DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSUT2  DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSUT3  DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSUT4  DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSUT5  DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSUT6  DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSUT7  DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSUT8  DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSUT9  DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSUT10 DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSUT11 DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSUT12 DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSUT13 DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSUT14 DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSUT15 DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//*
//*-------------------------------------------------------------------*
//* BIND (Link-Edit) step
//*-------------------------------------------------------------------*
//BIND   EXEC PGM=IEWBLINK,COND=(16,LT,COBOL),REGION=0M,
//        PARM=('&EBPARM.')
//STEPLIB DD  DISP=SHR,DSN=SYS1.MIGLIB
//        DD  DISP=SHR,DSN=&LEHLQ..SCEERUN
//        DD  DISP=SHR,DSN=&LEHLQ..SCEERUN2
//        DD  DISP=SHR,DSN=&SDSNLOAD.
//RESLIB  DD  DISP=SHR,DSN=&SDSNLOAD.
//SYSLIB  DD  DISP=SHR,DSN=&LOADLIB.
//        DD  DISP=SHR,DSN=&SDSNLOAD.
//        DD  DISP=SHR,DSN=&LEHLQ..SCEELKED
//        DD  DISP=SHR,DSN=&LEHLQ..SCEELKEX
//SYSLIN  DD  DSN=&&LOADSET,DISP=(OLD,DELETE)
//        DD  DDNAME=SYSIN
//SYSIN   DD  DUMMY
//SYSLMOD DD  DISP=SHR,DSN=&LOADLIB.(&MEM.)
//SYSPRINT DD SYSOUT=*
//SYSUIT1 DD  UNIT=SYSDA,SPACE=(CYL,(1,1))
//*
//        PEND
//*
//*-------------------------------------------------------------------*
//* DB2BIND proc
//*-------------------------------------------------------------------*
//DB2BIND PROC
//DB2BIND EXEC PGM=IKJEFT01
//STEPLIB DD  DISP=SHR,DSN=&SDSNEXIT.
//        DD  DISP=SHR,DSN=&SDSNLOAD.
//DBRMLIB DD  DISP=SHR,DSN=&DBRMLIB.(&MEM.)
//SYSTSPRT DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSUDUMP DD SYSOUT=*
//SYSTSIN  DD DUMMY
//*
//        PEND
//*
//*-------------------------------------------------------------------*
//* System-specific dataset name variables (matches compile_DONE.jcl)
//*-------------------------------------------------------------------*
// SET IGY=IGY.V6R5M0
// SET LEHLQ=CEE
// SET TCHLQ=BANKZ
// SET COPYLIB=BANKZ.DBB.COPY
// SET SRCLIB=USER.VK.COBOL
// SET LOADLIB=BANKZ.V0R1M0.LOADLIB
// SET SDSNLOAD=DB2V13.SDSNLOAD
// SET SDSNEXIT=DB2V13.SDSNEXIT
// SET DBRMLIB=BANKZ.V0R1M0.DBRM
//*
// SET REG=0M
// SET EPARM1='NODYNAM,NSYMBOL(NATIONAL),TRUNC(STD),SQL,LIST,XREF'
// SET EPARM2='TEST'
// SET EPARM3=''
// SET EBPARM='LIST,XREF,LET,RENT,REUS'
//*
//*-------------------------------------------------------------------*
//* Step 1 - Compile and link-edit BNK1STMT
//*          Source must be in USER.VK.COBOL(BNK1STMT)
//*-------------------------------------------------------------------*
//BNK1B  EXEC CLBIND,MEM=BNK1STMT
//*
//*-------------------------------------------------------------------*
//* Step 2 - DB2 Bind BNK1STMT into BANKZPACK / BANKZPLN
//*-------------------------------------------------------------------*
//BNK1D  EXEC DB2BIND,MEM=BNK1STMT
//DB2BIND.SYSTSIN DD *
 DSN SYSTEM(DBD1)
 BIND PACKAGE(BANKZPACK) OWNER(IBMUSER) -
 QUALIFIER(BANKZ) -
 MEMBER(BNK1STMT) -
 ACTION(REPLACE) -
 SQLERROR(CONTINUE) -
 VALIDATE(BIND)

 BIND PLAN(BANKZPLN) -
 OWNER(IBMUSER) -
 ISOLATION(UR) -
 PKLIST( -
 NULLID.*,BANKZPACK.* )

 END
/*
//*
