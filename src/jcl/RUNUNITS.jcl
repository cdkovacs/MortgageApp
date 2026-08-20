//ZUTST    JOB (ACCT),'ZUNIT',CLASS=A,MSGCLASS=H,NOTIFY=&SYSUID
//*------------------------------------------------------------------*
//* RUNUNITS - Run all MortgageApplication zUnit test suites         *
//*                                                                   *
//* Suites:                                                           *
//*   Step RUNPMT  - EPSMTST  tests EPSMPMT  (payment calculator)    *
//*   Step RUNNBR  - EPSNBVTS tests EPSNBRVL (numeric validator)     *
//*                                                                   *
//* Load library:  MORTAPP.INT.LOADLIB                               *
//* Return codes:  0 = all tests pass                                 *
//*               12 = one or more test cases failed                  *
//*                                                                   *
//* Customise MORTAPP.INT.LOADLIB to match your site HLQ.            *
//*------------------------------------------------------------------*
//*
//*------------------------------------------------------------------*
//* Step 1: EPSMTST — Monthly Payment Calculator test suite          *
//*         Calls EPSMPMT via the zUnit EPSMTST driver               *
//*------------------------------------------------------------------*
//RUNPMT   EXEC PGM=EPSMTST
//STEPLIB  DD  DISP=SHR,DSN=MORTAPP.INT.LOADLIB
//SYSOUT   DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//*
//*------------------------------------------------------------------*
//* Step 2: EPSNBVTS — Numeric String Validator test suite           *
//*         Calls EPSNBRVL via the zUnit EPSNBVTS driver             *
//*------------------------------------------------------------------*
//RUNNBR   EXEC PGM=EPSNBVTS,COND=(0,NE,RUNPMT)
//STEPLIB  DD  DISP=SHR,DSN=MORTAPP.INT.LOADLIB
//SYSOUT   DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//*
