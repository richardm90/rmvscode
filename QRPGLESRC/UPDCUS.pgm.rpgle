**free

//==============================================================================
// UPDCUS     - Update Customer Details
//
// 16/04/2021 - RM - created
//==============================================================================

ctl-opt text('Update Customer Details');
/include 'QCPYSRC/APP_H.rpgleinc'
ctl-opt main(UPDCUS);

//==============================================================================
// Define global files
//==============================================================================

dcl-f UPDCUSD workstn infds(g_infds) indds(g_indds) sfile(MSGSFL:msrrn) usropn;

//==============================================================================
// Copybook definitions
//==============================================================================

/include 'QCPYSRC/APP_D.rpgleinc'
/include 'QCPYSRC/APMSAL_D.rpgleinc'
/include 'QCPYSRC/FLASH_D.rpgleinc'
/include 'QCPYSRC/INFDS_D.rpgleinc'
/include 'QCPYSRC/CUSDET_D.rpgleinc'
/include 'QCPYSRC/RMAPP_D.rpgleinc'

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
// UPDCUS
//   Program entry point
//==============================================================================

dcl-proc UPDCUS;
  dcl-pi *n;
    id like(INTEGER_t) const;
  end-pi;

  dcl-ds cusdet likeds(CUSDET_t) inz(*likeds);
  dcl-s exit like(BOOLEAN_t);

  open UPDCUSD;

  exsr init;

  dow not exit;
    flash();
    set_footer();
    write FOOTER;
    write MSGCTL;
    exfmt UPDCUSA;

    exsr process;
  enddo;

  close UPDCUSD;

  return;

  begsr init;
    // Retrieve customer details
    reset cusdet;
    cusdet.ID = id;
    CUSDET_get(cusdet);
    if CUSDET_error();
      addmsg('ERROR RETRIEVING CUSTOMER DETAILS');
      exit = true;
    endif;
    if not CUSDET_found();
      addmsg('CUSTOMER DETAILS NOT FOUND - ' + %char(id));
      exit = true;
    endif;

    exsr init_scra;
  endsr;

  begsr init_scra;
    datitle = 'Update Customer';

    DACODE = cusdet.CODE;
    DAID   = '(Id=' + %char(cusdet.ID) + ')';
    DANAME = cusdet.NAME;
    DAADD1 = cusdet.ADDRESS_LINE1;
    DAADD2 = cusdet.ADDRESS_LINE2;
    DAADD3 = cusdet.ADDRESS_LINE3;
    DAADD4 = cusdet.ADDRESS_LINE4;
    DAPCOD = cusdet.POSTCODE;
    DACNAM = cusdet.CONTACT_NAME;
    DACTEL = cusdet.CONTACT_TELP;
    DACEML = cusdet.CONTACT_EMAIL;
    DAVATC = cusdet.VAT_CODE;
    DACURC = cusdet.CURRENCY;
    DACRED = cusdet.CREDIT_LIMIT;
    DACOMM = cusdet.COMMENTS;

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
      if valid(id) and update_customer(id);
        addmsg_info('Customer ' + %trimr(DACODE) + ' updated');
        exit = true;
      endif;

    // Return (F3)
    when g_fkey = F3;
      addmsg_info('Customer Update cancelled');
      exit = true;

    other;
      addmsg('INVALID OPTION');

    endsl;

  endsr;

end-proc;

//==============================================================================
// update_customer
//   Update a CUSDET row
//==============================================================================

dcl-proc update_customer;
  dcl-pi *n like(BOOLEAN_t);
    id like(INTEGER_t) const;
  end-pi;

  dcl-ds cusdet likeds(CUSDET_t) inz(*likeds);

  // Retrieve customer details
  reset cusdet;
  cusdet.ID = id;
  CUSDET_get(cusdet);

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
  CUSDET_update(cusdet);

  return (not CUSDET_error());
end-proc;

//==============================================================================
// valid
//   Validate screen fields
//==============================================================================

dcl-proc valid;
  dcl-pi *n like(BOOLEAN_t);
    id like(INTEGER_t) const;
  end-pi;

  i_dacode = false;
  i_daname = false;
  i_daadd1 = false;
  i_dapcod = false;

  dacode_valid(id);
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
  dcl-pi *n like(BOOLEAN_t);
    id like(INTEGER_t) const;
  end-pi;

  dcl-s l_valid like(BOOLEAN_t);

  select;

  // Customer Code must be entered
  when dacode = '';
    addmsg('CUSTOMER CODE EMPTY': 'DACODE');
    l_valid = false;

  // Customer Code must not exist
  when CUSDET_exists(dacode: id);
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
  dcl-pi *n like(BOOLEAN_t) end-pi;

  dcl-s l_valid like(BOOLEAN_t);

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
  dcl-pi *n like(BOOLEAN_t) end-pi;

  dcl-s l_valid like(BOOLEAN_t);

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
  dcl-pi *n like(BOOLEAN_t) end-pi;

  dcl-s l_valid like(BOOLEAN_t);

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
    msg likeds(APMSAL_t) const;
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

  ftpanel = 'UPDCUSA';
  ftuser = APP_user();
  ftdate = %char(APP_date());
  fttime = %char(APP_time());

  return;
end-proc;

//==============================================================================
// Copybook procedures
//==============================================================================

/include 'QCPYSRC/FLASH_P.rpgleinc'
