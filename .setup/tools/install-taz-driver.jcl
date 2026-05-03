//RELOAD   JOB (ACCT),
//            NOTIFY=&SYSUID,
//            TIME=1,MSGCLASS=H,CLASS=A,REGION=256M
//*--------------------------------------------------
//* Idempotent reload of VHR0M0 MANZ package
//*--------------------------------------------------
//*
//* Input USS file:
//*   /usr/local/sandboxes/tools/vhr0m0.manz.pds.trs
//*
//* Temporary datasets:
//*   IBMUSER.VHR0M0.MANZ.PDS.TRS
//*   IBMUSER.VHR0M0.MANZ.PDS
//*
//* Output datasets:
//*   EQAW.VHR0M0.PTF.*
//*
//*--------------------------------------------------
//* STEP0 : DELETE everything that may already exist
//*--------------------------------------------------
//CLEAN0   EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  DELETE IBMUSER.VHR0M0.MANZ.PDS.TRS PURGE
  DELETE IBMUSER.VHR0M0.MANZ.PDS PURGE

  DELETE EQAW.VHR0M0.PTF.AEQAZFS PURGE
  DELETE EQAW.VHR0M0.PTF.SEQAEXEC PURGE
  DELETE EQAW.VHR0M0.PTF.SEQAMENU PURGE
  DELETE EQAW.VHR0M0.PTF.SEQAAUTH PURGE
  DELETE EQAW.VHR0M0.PTF.SEQAMOD PURGE
  DELETE EQAW.VHR0M0.PTF.SEQALPA PURGE
  DELETE EQAW.VHR0M0.PTF.SEQAPENU PURGE
  DELETE EQAW.VHR0M0.PTF.SEQASAMP PURGE
  DELETE EQAW.VHR0M0.PTF.SEQASENU PURGE
  DELETE EQAW.VHR0M0.PTF.SEQATLIB PURGE

  IF MAXCC > 0 THEN SET MAXCC = 0
/*
//*--------------------------------------------------
//* STEP1 : ALLOCATE TRS sequential dataset
//*--------------------------------------------------
//ALLOC1   EXEC PGM=IEFBR14
//TRS      DD DSN=IBMUSER.VHR0M0.MANZ.PDS.TRS,
//            DISP=(NEW,CATLG,DELETE),
//            UNIT=3390,
//            SPACE=(CYL,(300,50)),
//            DCB=(RECFM=FB,LRECL=1024,BLKSIZE=0)
//*--------------------------------------------------
//* STEP2 : COPY USS binary TRS file to MVS dataset
//*--------------------------------------------------
//COPYTRS  EXEC PGM=IKJEFT01
//SYSTSPRT DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSUDUMP DD SYSOUT=*
//INFILE   DD PATH='#TOOLS_BIN_DIR/vhr0m0.manz.pds.trs',
//            PATHOPTS=(ORDONLY),
//            FILEDATA=BINARY
//OUTFILE  DD DSN=IBMUSER.VHR0M0.MANZ.PDS.TRS,DISP=OLD
//SYSTSIN  DD *
  OCOPY INDD(INFILE) OUTDD(OUTFILE) BINARY
/*
//*--------------------------------------------------
//* STEP3 : UNTERSE TRS into temporary PDS
//*--------------------------------------------------
//TERSE    EXEC PGM=AMATERSE,PARM=UNPACK
//SYSPRINT DD SYSOUT=*
//SYSUT1   DD DISP=SHR,DSN=IBMUSER.VHR0M0.MANZ.PDS.TRS
//SYSUT2   DD DISP=(NEW,CATLG,DELETE),
//            DSN=IBMUSER.VHR0M0.MANZ.PDS,
//            UNIT=3390,
//            SPACE=(CYL,(150,150,10)),
//            DSORG=PO
//SYSUT3   DD DISP=(NEW,DELETE),
//            UNIT=3390,
//            SPACE=(CYL,(100,50))
//*--------------------------------------------------
//* STEP4 : RECEIVE each member into final datasets
//*--------------------------------------------------
//RECEIVE  EXEC PGM=IKJEFT01,DYNAMNBR=100
//SYSTSPRT DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSUDUMP DD SYSOUT=*
//SYSTSIN  DD *
  RECEIVE INDA('IBMUSER.VHR0M0.MANZ.PDS(AEQAZFS)')
  DSN('EQAW.VHR0M0.PTF.AEQAZFS')

  RECEIVE INDA('IBMUSER.VHR0M0.MANZ.PDS(SEQAEXEC)')
  DSN('EQAW.VHR0M0.PTF.SEQAEXEC')

  RECEIVE INDA('IBMUSER.VHR0M0.MANZ.PDS(SEQAMENU)')
  DSN('EQAW.VHR0M0.PTF.SEQAMENU')

  RECEIVE INDA('IBMUSER.VHR0M0.MANZ.PDS(SEQAAUTH)')
  DSN('EQAW.VHR0M0.PTF.SEQAAUTH')

  RECEIVE INDA('IBMUSER.VHR0M0.MANZ.PDS(SEQAMOD)')
  DSN('EQAW.VHR0M0.PTF.SEQAMOD')

  RECEIVE INDA('IBMUSER.VHR0M0.MANZ.PDS(SEQALPA)')
  DSN('EQAW.VHR0M0.PTF.SEQALPA')

  RECEIVE INDA('IBMUSER.VHR0M0.MANZ.PDS(SEQAPENU)')
  DSN('EQAW.VHR0M0.PTF.SEQAPENU')

  RECEIVE INDA('IBMUSER.VHR0M0.MANZ.PDS(SEQASAMP)')
  DSN('EQAW.VHR0M0.PTF.SEQASAMP')

  RECEIVE INDA('IBMUSER.VHR0M0.MANZ.PDS(SEQASENU)')
  DSN('EQAW.VHR0M0.PTF.SEQASENU')

  RECEIVE INDA('IBMUSER.VHR0M0.MANZ.PDS(SEQATLIB)')
  DSN('EQAW.VHR0M0.PTF.SEQATLIB')
/*
//*--------------------------------------------------
//* STEP5 : CLEAN temporary datasets only if reload OK
//*--------------------------------------------------
//CLEAN1   EXEC PGM=IDCAMS,COND=(0,NE)
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  DELETE IBMUSER.VHR0M0.MANZ.PDS.TRS PURGE
  DELETE IBMUSER.VHR0M0.MANZ.PDS PURGE

  IF MAXCC > 0 THEN SET MAXCC = 0
/*