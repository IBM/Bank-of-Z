//EQAWTIMS JOB
//*
//*********************************************************************
//* Licensed Materials - Property of IBM                              *
//* 5724-T07                                                          *
//* Copyright IBM Corp. 1997, 2024 All Rights Reserved                *
//*                                                                   *
//* US Government Users Restricted Rights - Use, duplication or       *
//* disclosure restricted by GSA ADP Schedule Contract with IBM Corp. *
//*                                                                   *
//*********************************************************************
//*                                                                   *
//*  This JCL will link edit the IMS user exit routines supplied by   *
//*  z/OS Debugger with your system's IMS RESLIB library and produce  *
//*  load modules which can be included in your IMS control region    *
//*  search path to enable the exits.                                 *
//*                                                                   *
//*  CAUTION: This is neither a JCL procedure nor a complete job.     *
//*  Before using this job step, you will have to make the following  *
//*  modifications:                                                   *
//*                                                                   *
//*  1) Change the <ims-load-library> values to the name of the load  *
//*     library where you like the user exits to reside.  This data   *
//*     set should be in the search path for any IMS control region   *
//*     that wishes to utilize these exits.                           *
//*  2) Change the DTHLQ symbolic parameter to the appropriate data   *
//*     set prefix for your installed z/OS Debugger data sets.        *
//*  3) Change the IMSHLQ symbolic parameter to the appropriate data  *
//*     set prefix for your installed IMS data sets.                  *
//*                                                                   *
//*  Notes:                                                           *
//*                                                                   *
//*  1. This job will complete with a return code 0.                  *
//*                                                                   *
//*********************************************************************
// SET DTHLQ=EQAW
// SET IMSHLQ=IMSV15
//*********************************************************************
//* Link-edit the EQATIEDT user exit (transaction message edit)       *
//*********************************************************************
//LINK1  EXEC  PGM=IEWL,COND=(4,LE),REGION=17M,
// PARM=('OPTIONS=OPTIONS')
//SYSUT1   DD  UNIT=SYSVIO,SPACE=(TRK,(10,80))
//SYSPRINT DD  SYSOUT=*
//SYSLMOD  DD DSN=&SYSUID..IMSISO.LOADLIB,DISP=SHR
//SYSLIB   DD DSN=&DTHLQ..SEQAMOD,DISP=SHR
//         DD DSN=&IMSHLQ..SDFSRESL,DISP=SHR
//OPTIONS  DD  *
 LIST,XREF,LET,MAP
//SYSLIN   DD  *
  MODE AMODE(31),RMODE(ANY)
  INCLUDE  SYSLIB(DFSCSI00)
  REPLACE  DFSCSII0
  INCLUDE  SYSLIB(EQATIEDT)
  ENTRY    EQATIEDT
  NAME     EQATIEDT(R)
/*
//*********************************************************************
//* Link-edit the DFSMSCE0 user exit (transaction routing)            *
//*********************************************************************
//LINK2  EXEC  PGM=IEWL,COND=(4,LE),REGION=17M,
// PARM=('OPTIONS=OPTIONS')
//SYSUT1   DD  UNIT=SYSVIO,SPACE=(TRK,(10,80))
//SYSPRINT DD  SYSOUT=*
//SYSLMOD  DD DSN=IBMUSER.IMSISO.LOADLIB,DISP=SHR
//SYSLIB   DD DSN=&DTHLQ..SEQAMOD,DISP=SHR
//         DD DSN=&IMSHLQ..SDFSRESL,DISP=SHR
//OPTIONS  DD  *
 LIST,XREF,LET,MAP
//SYSLIN   DD  *
  MODE AMODE(31),RMODE(ANY)
  INCLUDE  SYSLIB(DFSCSI00)
  REPLACE  DFSCSIF0
  INCLUDE  SYSLIB(EQATIEXT)
  ENTRY    EQATIEXT
  ALIAS    DFSMSCE0
  NAME     EQATIEXT(R)
/*
