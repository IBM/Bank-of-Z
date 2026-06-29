//DEFCFG  JOB ,
// CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),NOTIFY=&SYSUID
//*
//* ------ Delete old copy of file if any.
//*
//DEL      EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
   DELETE -
      BANKZ.CICSBOZ.TCP.CONFIG -
      PURGE -
      ERASE
//*
//* ------ Define the new file.
//*
//DEFINE   EXEC PGM=IDCAMS
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  DEFINE CLUSTER (NAME(BANKZ.CICSBOZ.TCP.CONFIG) VOLUMES(USRVS1) -
      CYL(1 1) -
      RECORDSIZE(150 150) FREESPACE(0 15) -
      INDEXED ) -
      DATA ( -
        NAME(BANKZ.CICSBOZ.TCP.CONFIG.DATA) -
        KEYS (16 0) ) -
      INDEX ( -
        NAME(BANKZ.CICSBOZ.TCP.CONFIG.INDEX) )
/*
/*
//*
//* ------ Assemble the initialization program
//*
//ASM      EXEC PGM=ASMA90,PARM='OBJECT,TERM',REGION=1024K
//SYSLIB   DD DISP=SHR,DSNAME=SYS1.MACLIB
//         DD DISP=SHR,DSNAME=TCPIP.SEZACMAC
//SYSUT1   DD UNIT=SYSDA,SPACE=(CYL,(5,1))
//SYSUT2   DD UNIT=SYSDA,SPACE=(CYL,(2,1))
//SYSUT3   DD UNIT=SYSDA,SPACE=(CYL,(2,1))
//SYSPUNCH DD DISP=SHR,DSNAME=NULLFILE
//SYSLIN   DD DSNAME=&&OBJSET,DISP=(MOD,PASS),UNIT=SYSDA,
//            SPACE=(400,(500,50)),
//            DCB=(RECFM=FB,BLKSIZE=400,LRECL=80)
//SYSTERM  DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
         EZACICD TYPE=INITIAL,    Initialize generation environment    X
               PRGNAME=EZACICDF,  Name of the generated program        X
               FILNAME=EZACONFG   DD name of the configuration file
         EZACICD TYPE=CICS,       Generate configuration record        X
               APPLID=CICSBOZ,    APPLID of CICS                       X
               TCPADDR=TCPIP,     Address space name for TCP/IP        X
               NTASKS=20,         Number of reusable MVS subtasks      X
               DPRTY=10,          Priority difference (CICS-Subtask)   X
               CACHMIN=15,        Minimum refresh time for CACHE       X
               CACHMAX=30,        Maximum refresh time for CACHE       X
               CACHRES=10,        Maximum number of active resolvers   X
               ERRORTD=CSMT       Name of TD queue for error messages
         EZACICD TYPE=LISTENER,   Create Listener Record               X
               FORMAT=STANDARD,   Standard Listener                    X
               APPLID=CICSBOZ,    APPLID of CICS                       X
               TRANID=CSKL,       Use standard transaction ID          X
               PORT=3010,         Use port number 3010                 X
               AF=INET,           Listener Address Family              X
               IMMED=YES,         Listener starts up at initialization?X
               BACKLOG=50,        Set backlog value to 50              X
               NUMSOCK=50,        # of sockets supported by Listener   X
               MINMSGL=4,         Minimum input message length         X
               ACCTIME=60,        Set timeout value to 30 seconds      X
               GIVTIME=0,                                              X
               REATIME=0,                                              X
               RTYTIME=15,        Wait 15 seconds for TCP to come back X
               LAPPLD=YES,        Register Application Data            X
               TRANTRN=YES,       Is TRANUSR=YES conditional?          X
               TRANUSR=YES
         EZACICD TYPE=FINAL
/*
//*
//* ------ Link the initialization program
//*
//LINK     EXEC PGM=IEWL,PARM='LIST,MAP,XREF',
//            REGION=512K,COND=(4,LT,ASM)
//SYSPRINT DD SYSOUT=*
//SYSUT1   DD SPACE=(CYL,(5,1)),DISP=(NEW,PASS),UNIT=SYSDA
//SYSLMOD  DD DSNAME=&&LOADSET(EZACICDF),DISP=(MOD,PASS),UNIT=SYSDA,
//            SPACE=(TRK,(1,1,1)),
//            DCB=(DSORG=PO,RECFM=U,BLKSIZE=32760)
//SYSLIN   DD DSNAME=&&OBJSET,DISP=(OLD,DELETE)
//*
//* ------ Execute the initialization program
//*
//FILELOAD EXEC PGM=*.LINK.SYSLMOD,
//            COND=((4,LT,DEFINE),(4,LT,ASM),(4,LT,LINK))
//EZACONFG DD DSNAME=BANKZ.CICSBOZ.TCP.CONFIG,DISP=OLD
//*