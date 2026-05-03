//EQAWCCSD JOB (IBMUSER),MSGCLASS=X,CLASS=A,NOTIFY=&SYSUID,REGION=0M
//*
//*********************************************************************
//*                                                                  */
//*  IBM z/OS Debugger                                               */
//*               17.0                                               */
//*                                                                  */
//*********************************************************************
//*                                                                   *
//* Licensed Materials - Property of IBM                              *
//*                                                                   *
//* 5724-T07: IBM z/OS Debugger                                       *
//* Copyright IBM Corp. 1997, 2024 All Rights Reserved                *
//*                                                                   *
//* US Government Users Restricted Rights - Use, duplication or       *
//* disclosure restricted by GSA ADP Schedule Contract with IBM Corp. *
//*                                                                   *
//********************************************************************
//*                                                                  *
//* EQAWCCSD JOB                                                     *
//*                                                                  *
//* This job will define all z/OS Debugger CICS programs,            *
//* transactions and transient data queues.                          *
//*                                                                  *
//* Caution: This is neither a JCL procedure nor a complete job.     *
//* Before using this job, you will have to make the following       *
//* modifications:                                                   *
//*                                                                  *
//* 1. Change the job card to meet your system requirements.         *
//* 2. Change the DFHPRFX DSN prefix value below to to meet your     *
//*    installation requirements for SDFHLOAD.                       *
//* 3. Change the CSDPRFX DSN prefix value below to meet your        *
//*    installation requirements for DFHCCSD.                        *
//* 4. Change the DTPRFX  DSN prefix value below to meet your        *
//*    installation requirements for SEQASAMP.                       *
//* 5. Change/verify the use of group name "EQA" in member EQACCSD.  *
//* 6. Change <list-name> to the appropriate CICS startup group      *
//*    list name in member EQACCSD.                                  *
//* 7. Review the TDQUEUE definitions if you use macro DCTs or       *
//*    wish to remove definitions for COBOL or PLI sidefile access.  *
//*                                                                  *
//* This job will complete with a return code of 4.                  *
//*                                                                  *
//********************************************************************
//        SET DFHPRFX=CICSTS63.CICS                   <<<
//        SET DTPRFX=EQAW                             <<<
//EQACICS EXEC PGM=DFHCSDUP,REGION=1024K,
//             PARM='CSD(READWRITE),PAGESIZE(60),NOCOMPAT'
//STEPLIB  DD DISP=SHR,DSN=&DFHPRFX..SDFHLOAD
//DFHCSD   DD DISP=SHR,DSN=#CSDPRFX..DFHCSD
//SYSIN    DD DISP=SHR,DSN=#CSDPRFX..TAZ(TAZCSD)
//SYSPRINT DD SYSOUT=*
/*
//*********************************************************************
//*        DELETE THE EXISTING FILE                                   *
//*********************************************************************
//DELETE    EXEC PGM=IDCAMS,REGION=1M
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
 DELETE #CSDPRFX..EQADPFMB
 SET MAXCC=0
/*
//*********************************************************************
//*        DEFINE A NEW VSAM DEBUGGING PROFILE DATASET                *
//*********************************************************************
//DEFINE    EXEC PGM=IDCAMS,REGION=1M
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
 /*                           */
 /* DEFINE DEBUGGING PROFILES */
 /* BASE AND PATH DATA SETS   */
 /*                           */
    DEFINE CLUSTER (RECORDS(256) -
     NAME (#CSDPRFX..EQADPFMB) -
     SHAREOPTIONS(2 3) -
     LOG(NONE) -
     IXD)             -
    DATA -
     (RECSZ(3000,3000) -
     NAME (#CSDPRFX..EQADPFMB.DATA) -
     KEYS(8 16) -
     FREESPACE(10 10) -
     BUFFERSPACE (20000)) -
   INDEX -
     (NAME(#CSDPRFX..EQADPFMB.INDX))
/*
//*