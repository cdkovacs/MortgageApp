//ZUTST    JOB (ACCT),'ZUNIT',CLASS=A,MSGCLASS=H,NOTIFY=&SYSUID
//*------------------------------------------------------------------*
//* RUNNBR - Run EPSNBVTS zUnit test suite for EPSNBRVL             *
//*                                                                   *
//* Program under test: EPSNBRVL  (numeric string validator)         *
//* Test suite:         EPSNBVTS                                      *
//*                                                                   *
//* Test cases:                                                       *
//*   TC01 - Valid integer '42'          => number=42, no error      *
//*   TC02 - Valid decimal '999.99'      => number=999.99, no error  *
//*   TC03 - Comma in number '1,234'     => number=1234, no error    *
//*   TC04 - All spaces                  => NO NUMBER PRESENT        *
//*   TC05 - Embedded space '12 34'      => SPACES IN NUMBER         *
//*   TC06 - Two decimal points '9.9.9'  => TOO MANY DEICMAL POINTS  *
//*   TC07 - Max-length enforced (max=5) => number=12345, no error   *
//*   TC08 - Single digit '5'            => number=5, no error       *
//*   TC09 - Zero-padded '00099'         => number=99, no error      *
//*   TC10 - Exact max-length '12345'    => number=12345, no error   *
//*                                                                   *
//* Return codes:  0 = all tests pass                                 *
//*               12 = one or more test cases failed                  *
//*------------------------------------------------------------------*
//RUNNBR   EXEC PGM=EPSNBVTS
//STEPLIB  DD  DISP=SHR,DSN=MORTAPP.INT.LOADLIB
//SYSOUT   DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//*
