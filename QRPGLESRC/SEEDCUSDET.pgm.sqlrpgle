**free

//==============================================================================
// SEEDCUSDET - Seed the CUSTOMER_DETAILS table
//
// I'm using a sample set of customer data downloaded from the following page.
//   https://www.briandunning.com/sample-data/
//
// 08/04/2021 - RM - created
//==============================================================================

/define APP_ACTGRP_NEW
/include 'QCPYSRC/APP_H.rpgleinc'
ctl-opt main(SEEDCUSDET);
ctl-opt bnddir('CSV');

//==============================================================================
// Define global data structures
//==============================================================================

dcl-s g_index like(SMALLINT_t);

//==============================================================================
// Copybook definitions
//==============================================================================

/include 'QCPYSRC/APP_D.rpgleinc'
/include 'QCPYSRC/APMSAL_D.rpgleinc'
/include 'QCPYSRC/CSV_H.rpgleinc'
/include 'QCPYSRC/CUSDET_D.rpgleinc'
/include 'QCPYSRC/RMEMBSQL_D.rpgleinc'
/include 'QCPYSRC/RMAPP_D.rpgleinc'

dcl-c CMD_YES const('*YES');

//==============================================================================
// Copybook procedures
//==============================================================================

/include 'QCPYSRC/RMEMBSQL_P.rpgleinc'

//==============================================================================
// Program entry point
//==============================================================================

dcl-proc SEEDCUSDET;
  dcl-pi *n;
    truncate_in char(4) const;
    csv_stmf_in like(CMD_PARM_PNAME_t) const;
  end-pi;

  dcl-ds cusdet likeds(CUSDET_t) inz(*likeds);
  dcl-ds msg likeds(APMSAL_t) inz(*likeds);

  dcl-s csvfile       like(CSV_HANDLE);

  dcl-s first_name    varchar(20);
  dcl-s last_name     varchar(20);
  dcl-s company_name  varchar(40);
  dcl-s address       varchar(40);
  dcl-s city          varchar(40);
  dcl-s county        varchar(40);
  dcl-s postal        varchar(10);
  dcl-s phone1        varchar(20);
  dcl-s phone2        varchar(20);
  dcl-s email         varchar(80);
  dcl-s web           varchar(80);
  dcl-s csv_stmf      varchar(5000);
  dcl-s row_count     like(INTEGER_t);

  g_index = 0;
  csv_stmf = %trim(csv_stmf_in);
  csvfile = CSV_open(csv_stmf);

  snd-msg 'CSV Data Stream File: ' + csv_stmf;

  if truncate_in = CMD_YES;
    truncate_customers();
    snd-msg 'Table CUSDET truncated';
  endif;

  dow CSV_loadrec(csvfile);
    if g_index > 0; // Skips the header row
      CSV_getfld(csvfile: first_name:   %size(first_name));
      CSV_getfld(csvfile: last_name:    %size(last_name));
      CSV_getfld(csvfile: company_name: %size(company_name));
      CSV_getfld(csvfile: address:      %size(address));
      CSV_getfld(csvfile: city:         %size(city));
      CSV_getfld(csvfile: county:       %size(county));
      CSV_getfld(csvfile: postal:       %size(postal));
      CSV_getfld(csvfile: phone1:       %size(phone1));
      CSV_getfld(csvfile: phone2:       %size(phone2));
      CSV_getfld(csvfile: email:        %size(email));
      CSV_getfld(csvfile: web:          %size(web));

      // Create CUSTOMER_DETAILS row
      cusdet = CUSDET_new();
      cusdet.CODE            = gen_code(company_name);
      cusdet.NAME            = company_name;
      cusdet.ADDRESS_LINE1   = address;
      cusdet.ADDRESS_LINE2   = city;
      cusdet.ADDRESS_LINE3   = county;
      cusdet.POSTCODE        = postal;
      cusdet.CONTACT_NAME    = first_name + ' ' + last_name;
      cusdet.CONTACT_TELP    = phone1;
      cusdet.CONTACT_EMAIL   = email;
      cusdet.VAT_CODE        = gen_vat_code();
      cusdet.CURRENCY        = gen_currency();
      cusdet.CREDIT_LIMIT    = gen_credit_limit();
      cusdet.CURRENT_BALANCE = gen_current_balance();
      CUSDET_add(cusdet);

      if CUSDET_error();
        msg.TYPE = APMSAL_TYPE_ERROR;
        APMSAL_fetch_last(msg);
        APP_escape(msg.TEXT);
      endif;
      row_count += 1;
    endif;
    g_index += 1;
  enddo;

  CSV_close(csvfile);

  snd-msg 'CUSDET seeded with ' + %char(row_count) + ' rows';

  return;
end-proc;

//==============================================================================
// gen_code
//   Generate a unique customer code
//==============================================================================

dcl-proc gen_code;
  dcl-pi *n like(CUSDET_CODE_t);
    name like(CUSDET_NAME_t) const;
  end-pi;

  dcl-s code like(CUSDET_CODE_t);

  code = %subst(%trim(name): 1: 1)
       + %editc(g_index: 'X');

  return code;
end-proc;

//==============================================================================
// gen_vat_code
//   Generate a random vat code
//==============================================================================

dcl-proc gen_vat_code;
  dcl-pi *n like(CUSDET_VAT_CODE_t) end-pi;

  dcl-s vat_code like(CUSDET_VAT_CODE_t);

  if %inth(random(10)) < 9;
    vat_code = 'S';
  else;
    vat_code = 'Z';
  endif;

  return vat_code;
end-proc;

//==============================================================================
// gen_currency
//   Generate a random currency code
//==============================================================================

dcl-proc gen_currency;
  dcl-pi *n like(CUSDET_CURRENCY_t) end-pi;

  dcl-s currency like(CUSDET_CURRENCY_t);

  if %inth(random(10)) < 9;
    currency = 'GBP';
  else;
    currency = 'EUR';
  endif;

  return currency;
end-proc;

//==============================================================================
// gen_credit_limit
//   Generate a random credit limit
//==============================================================================

dcl-proc gen_credit_limit;
  dcl-pi *n like(CUSDET_CREDIT_LIMIT_t) end-pi;

  dcl-s credit_limit like(CUSDET_CREDIT_LIMIT_t);

  credit_limit = %inth(random(20)) * 500;

  return credit_limit;
end-proc;

//==============================================================================
// gen_current_balance
//   Generate a random current balance
//==============================================================================

dcl-proc gen_current_balance;
  dcl-pi *n like(CUSDET_CURRENT_BALANCE_t) end-pi;

  dcl-s current_balance like(CUSDET_CURRENT_BALANCE_t);

  if %inth(random(10)) < 5;
    current_balance = %inth(random(100000)) / 2;
  endif;

  return current_balance;
end-proc;

//==============================================================================
// random
//   Generate a random number
//==============================================================================

dcl-proc random;
  dcl-pi *n like(INTEGER_t);
    factor like(INTEGER_t) const;
  end-pi;

  dcl-s number  like(INTEGER_t);
  dcl-s randnum like(DOUBLE_t);
  dcl-s seednum like(INTEGER_t);

  dcl-pr randnum_gen extproc('CEERAN0');
    seednum  like(INTEGER_t);
    randnum  like(DOUBLE_t);
    feedback char(12) options(*omit);
  end-pr;

  // ....+....1....+....2....+....3..
  // 2014-06-27-01.02.03.123456789012
  seednum = %int(%subst(%char(%timestamp()): 21: 6));

  randnum_gen(seednum: randnum: *omit);

  number = %inth(randnum * factor);

  return number;
end-proc;

//==============================================================================
// truncate_customers
//   Truncate the CUSTOMER_DETAILS table
//==============================================================================

dcl-proc truncate_customers;
  dcl-pi *n end-pi;

  exec sql
    TRUNCATE TABLE CUSDET RESTART IDENTITY;

  return;
end-proc;
