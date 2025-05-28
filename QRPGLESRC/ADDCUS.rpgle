**FREE

//==============================================================================
// ADDCUS.rpgle
//   Show Customer Details
//
// 15/04/2021 - RM - created
//==============================================================================

/include APP_H
ctl-opt main(ADDCUS);

//==============================================================================
// Define global files
//==============================================================================

dcl-f ADDCUSD workstn infds(g_infds) indds(g_indds) sfile(MSGSFL:msrrn) usropn;

//==============================================================================
// Define global data structures
//==============================================================================

// Screen indicator DS
dcl-ds g_indds;
  i_sfldsp            ind pos(31);
  i_sfldspctl         ind pos(32);
  i_sflend            ind pos(33);
  i_sflclr            ind pos(34);
  i_sflerr            ind pos(35);
  i_dacode            ind pos(51);
  i_daname            ind pos(52);
  i_daadd1            ind pos(53);
  i_dapcod            ind pos(54);
  i_error             ind pos(90);
end-ds;

//==============================================================================
// Define global fields
//==============================================================================

//==============================================================================
// Copybook definitions
//==============================================================================

/include APP_D
/include APMSAL_D
/include APPJOB_D
// /include APTSAL_D
/include FLASH_D
/include INFDS_D
/include CUSDET_D
/include RMAPPENV_D

//==============================================================================
// ADDCUS
//   Program entry point
//==============================================================================

dcl-proc ADDCUS;
  dcl-pi *n end-pi;

  dcl-ds cusdet likeds(t_CUSDET) inz(*likeds);
  dcl-s exit like(t_BOOLEAN);

  open ADDCUSD;

  exsr init;

  dow not exit;
    flash();
    set_footer();
    write FOOTER;
    write MSGCTL;
    exfmt ADDCUSA;

    exsr process;
  enddo;

  close ADDCUSD;

  return;

  begsr init;

    exsr init_scra;
  endsr;

  begsr init_scra;
    datitle = 'Add Customer';

    DACODE = '';
    DANAME = '';
    DAADD1 = '';
    DAADD2 = '';
    DAADD3 = '';
    DAADD4 = '';
    DAPCOD = '';
    DACNAM = '';
    DACTEL = '';
    DACEML = '';
    DAVATC = '';
    DACURC = '';
    DACOMM = '';

    i_dacode = false;
    i_daname = false;
    i_daadd1 = false;
    i_dapcod = false;
    i_error = false;
    dafky1 = 'Enter  F3=Exit';
  endsr;

  begsr process;

    select;

    // Accept (Enter)
    when g_fkey = Enter;
      if valid() and add_customer();
        addmsg_info('Customer ' + %trimr(DACODE) + ' added');
        exit = true;
      endif;

    // Return (F3)
    when g_fkey = F3;
      addmsg_info('Customer Add cancelled');
      exit = true;

    other;
      addmsg('INVALID OPTION');

    endsl;

  endsr;

end-proc;

//==============================================================================
// add_customer
//   Create a CUSTOMER_DETAILS row
//==============================================================================

dcl-proc add_customer;
  dcl-pi *n like(t_BOOLEAN) end-pi;

  dcl-ds cusdet likeds(t_CUSDET) inz(*likeds);

  cusdet = CUSDET_new();
  cusdet.CODE          = DACODE;
  cusdet.NAME          = %trimr(DANAME);
  cusdet.ADDRESS_LINE1 = %trimr(DAADD1);
  cusdet.ADDRESS_LINE2 = %trimr(DAADD2);
  cusdet.ADDRESS_LINE3 = %trimr(DAADD3);
  cusdet.ADDRESS_LINE4 = %trimr(DAADD4);
  cusdet.POSTCODE      = %trimr(DAPCOD);
  cusdet.CONTACT_NAME  = %trimr(DACNAM);
  cusdet.CONTACT_TELP  = %trimr(DACTEL);
  cusdet.CONTACT_EMAIL = %trimr(DACEML);
  cusdet.VAT_CODE      = DAVATC;
  cusdet.CURRENCY      = DACURC;
  cusdet.CREDIT_LIMIT  = DACRED;
  cusdet.COMMENTS      = %trimr(DACOMM);
  CUSDET_add(cusdet);

  return (not CUSDET_error());
end-proc;

//==============================================================================
// valid
//   Validate screen fields
//==============================================================================

dcl-proc valid;
  dcl-pi *n like(t_BOOLEAN) end-pi;

  i_dacode = false;
  i_daname = false;
  i_daadd1 = false;
  i_dapcod = false;

  dacode_valid();
  daname_valid();
  daadd1_valid();
  dapcod_valid();

  return (APMSAL_error()=false);
end-proc;

//==============================================================================
// dacode_valid
//   Validate Customer Code screen field
//==============================================================================

dcl-proc dacode_valid;
  dcl-pi *n like(t_BOOLEAN) end-pi;

  dcl-s l_valid like(t_BOOLEAN);

  select;

  // Customer Code must be entered
  when dacode = '';
    addmsg('CUSTOMER CODE EMPTY': 'DACODE');
    l_valid = false;

  // Customer Code must not exist
  when CUSDET_exists(dacode);
    addmsg('CUSTOMER CODE ALREADY USED': 'DACODE');
    l_valid = false;

  other;
    l_valid = true;

  endsl;

  return l_valid;
end-proc;

//==============================================================================
// daname_valid
//   Validate Customer Name screen field
//==============================================================================

dcl-proc daname_valid;
  dcl-pi *n like(t_BOOLEAN) end-pi;

  dcl-s l_valid like(t_BOOLEAN);

  select;

  // Customer Name must be entered
  when daname = '';
    addmsg('CUSTOMER NAME EMPTY': 'DANAME');
    l_valid = false;

  other;
    l_valid = true;

  endsl;

  return l_valid;
end-proc;

//==============================================================================
// daadd1_valid
//   Validate Customer Address Line 1 screen field
//==============================================================================

dcl-proc daadd1_valid;
  dcl-pi *n like(t_BOOLEAN) end-pi;

  dcl-s l_valid like(t_BOOLEAN);

  select;

  // Customer Address Line 1 must be entered
  when daadd1 = '';
    addmsg('CUSTOMER ADDRESS LINE 1 EMPTY': 'DAADD1');
    l_valid = false;

  other;
    l_valid = true;

  endsl;

  return l_valid;
end-proc;

//==============================================================================
// dapcod_valid
//   Validate Customer Postcode screen field
//==============================================================================

dcl-proc dapcod_valid;
  dcl-pi *n like(t_BOOLEAN) end-pi;

  dcl-s l_valid like(t_BOOLEAN);

  select;

  // Customer Postcode must be entered
  when dapcod = '';
    addmsg('CUSTOMER POSTCODE EMPTY': 'DAPCOD');
    l_valid = false;

  other;
    l_valid = true;

  endsl;

  return l_valid;
end-proc;

//==============================================================================
// set_field_error
//   Set error indicators for the field referenced in the given msg
//   - Executed from the flash procedure
//==============================================================================

dcl-proc set_field_error;
  dcl-pi *n;
    msg likeds(t_APMSAL) const;
  end-pi;

  select;
  when msg.FIELD_NAME = 'DACODE';
    i_dacode = true;
  when msg.FIELD_NAME = 'DANAME';
    i_daname = true;
  when msg.FIELD_NAME = 'DAADD1';
    i_daadd1 = true;
  when msg.FIELD_NAME = 'DAPCOD';
    i_dapcod = true;
  endsl;

  return;
end-proc;

//==============================================================================
// set_footer
//   Set panel footer fields
//==============================================================================

dcl-proc set_footer;
  dcl-pi *n end-pi;

  ftpanel = 'ADDCUSA';
  ftuser = APPENV_user();
  ftdate = %char(APPENV_date());
  fttime = %char(APPENV_time());

  return;
end-proc;

//==============================================================================
// Copybook procedures
//==============================================================================

/include FLASH_P
// /include STACK_P
