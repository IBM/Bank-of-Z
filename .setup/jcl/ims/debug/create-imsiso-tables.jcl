//EQAWTIVS JOB
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
//*  This JCL will define the VSAM file used by the IMS Transaction   *
//*  Isolation Facility to store the system configuration and user    *
//*  selections on IMS shutdown.  The data will be restored when the  *
//*  IMS region restarts.                                             *
//*                                                                   *
//*  CAUTION: This is neither a JCL procedure nor a complete job.     *
//*  Before using this job step, you will have to make the following  *
//*  modifications:                                                   *
//*                                                                   *
//*  1) Change the <dsname-prefix> values to your preferred dataset   *
//*     name prefix for the EQATIVSM VSAM file.                       *
//*  2) If you wish the data set to be created on a specific volume,  *
//*     change the value &RGNVOL. to the volume serial.  If this      *
//*     field can be defaulted, you should delete the VOLUME line     *
//*     from the DEFINE CLUSTER statement.                            *
//*                                                                   *
//*  Notes:                                                           *
//*                                                                   *
//*  1. This job will complete with a return code 0.                  *
//*                                                                   *
//*********************************************************************
//*        DELETE THE EXISTING FILE                                   *
//*********************************************************************
//DELETE    EXEC PGM=IDCAMS,REGION=1M
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
 DELETE &SYSUID..DEBUG.EQATITBL
 SET MAXCC=0
/*
//*********************************************************************
//*        DEFINE A NEW VSAM DEBUGGING PROFILE DATASET                *
//*********************************************************************
//DEFINE    EXEC PGM=IDCAMS,REGION=1M
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
 /*                           */
 /* DEFINE IMS ISOLATION      */
 /* TABLE INDEX AND PATH      */
 /* DATA SETS                 */
 /*                           */
    DEFINE CLUSTER (RECORDS(999) -
     NAME (&SYSUID..ZDEBUG.EQATITBL) -
     SHAREOPTIONS(2 3) -
     LOG(NONE) -
     INDEXED)         -
    DATA -
     (RECSZ(200,200)   -
     NAME (&SYSUID..ZDEBUG.EQATITBL.DATA) -
     KEYS(11 0)  -
     FREESPACE(10 10) -
     BUFFERSPACE (20000)) -
   INDEX -
     (NAME(&SYSUID..ZDEBUG.EQATITBL.INDX))
/*
