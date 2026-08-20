//ZUTST    JOB (ACCT),'ZUNIT',CLASS=A,MSGCLASS=H,NOTIFY=&SYSUID
//*------------------------------------------------------------------*
//* RUNPMT - Run EPSMTST zUnit test suite for EPSMPMT               *
//*                                                                   *
//* Program under test: EPSMPMT  (monthly payment calculator)        *
//* Test suite:         EPSMTST                                      *
//*                                                                   *
//* Test cases:                                                       *
//*   TC01 - 30-year loan at 5%   => payment ~$1,073.64              *
//*   TC02 - 15-year loan at 4.5% => payment ~$1,147.49              *
//*   TC03 - 24-month loan at 6%  => payment ~$443.21                *
//*   TC04 - Negative principal   => error PRINCIPLE AMOUNT IS       *
//*                                   NEGATIVE                        *
//*   TC05 - Zero principal       => error PRINCIPLE AMOUNT IS       *
//*                                   NEGATIVE                        *
//*   TC06 - Exceeds maximum      => error PRINCIPLE EXCEEDED        *
//*                                   MAXIMUM AMOUNT                  *
//*   TC07 - Zero interest rate   => error NEGATIVE INTEREST RATE    *
//*   TC08 - Negative interest    => error NEGATIVE INTEREST RATE    *
//*   TC09 - Year ind, 0 years    => documented behaviour (no assert) *
//*   TC10 - Month ind, 0 months  => documented behaviour (no assert) *
//*                                                                   *
//* Return codes:  0 = all tests pass                                 *
//*               12 = one or more test cases failed                  *
//*------------------------------------------------------------------*
//RUNPMT   EXEC PGM=EPSMTST
//STEPLIB  DD  DISP=SHR,DSN=MORTAPP.INT.LOADLIB
//SYSOUT   DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//*
