**free

//==============================================================================
// DELCUS     - Delete Customer Details
//
// 16/04/2021 - RM - created
//==============================================================================

/include 'QCPYSRC/APP_H.rpgleinc'
ctl-opt main(DELCUS);

//==============================================================================
// Define global files
//==============================================================================

dcl-f DELCUSD workstn infds(g_infds) indds(g_indds) sfile(MSGSFL:msrrn) usropn;

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
  i_error             ind pos(90);
end-ds;

//==============================================================================
// DELCUS
//   Program entry point
//==============================================================================

dcl-proc DELCUS;
  dcl-pi *n;
    id like(INTEGER_t) const;
  end-pi;

  dcl-ds cusdet likeds(CUSDET_t) inz(*likeds);
  dcl-s exit like(BOOLEAN_t);

  open DELCUSD;

  exsr init;

  dow not exit;
    flash();
    set_footer();
    write FOOTER;
    write MSGCTL;
    exfmt DELCUSA;

    exsr process;
  enddo;

  close DELCUSD;

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
    datitle = 'Delete Customer';

    DACODE = cusdet.CODE;
    DAID   = '(Id=' + %char(cusdet.ID) + ')';
    DANAME = cusdet.NAME;
    DAADD1 = cusdet.ADDRESS_LINE1;
    DAADD2 = cusdet.ADDRESS_LINE2;
    DAADD3 = cusdet.ADDRESS_LINE3;
    DAADD4 = cusdet.ADDRESS_LINE4;
    DAPCOD = cusdet.POSTCODE;
    DACONT = cusdet.CONTACT_NAME + ' - ' + cusdet.CONTACT_TELP;
    DAEMAIL = cusdet.CONTACT_EMAIL;
    DAVATC = cusdet.VAT_CODE;
    DACURC = cusdet.CURRENCY;
    DACRED = cusdet.CREDIT_LIMIT;
    DACOMM = cusdet.COMMENTS;

    addmsg('CONFIRM DELETION OF CUSTOMER ' + %trimr(DACODE));

    i_error = false;
    dafky1 = 'F3=Exit  F15=Delete';
  endsr;

  begsr process;

    select;

    // Accept (Enter)
    // when g_fkey = Enter;
    //   exit = true;

    // Return (F3)
    when g_fkey = F3;
      exit = true;

    // Delete (F15)
    when g_fkey = F15;
      if delete_customer(id);
        addmsg_info('Customer ' + %trimr(DACODE) + ' deleted');
        exit = true;
      endif;

    other;
      addmsg('INVALID OPTION');

    endsl;

  endsr;

end-proc;

//==============================================================================
// delete_customer
//   Delete a CUSTOMER_DETAILS row
//==============================================================================

dcl-proc delete_customer;
  dcl-pi *n like(BOOLEAN_t);
    id like(INTEGER_t) const;
  end-pi;

  dcl-ds cusdet likeds(CUSDET_t) inz(*likeds);

  // Retrieve customer details
  reset cusdet;
  cusdet.ID = id;
  CUSDET_delete(cusdet);

  return (not CUSDET_error());
end-proc;

//==============================================================================
// set_field_error
//   Set error indicators for the field referenced in the given msg
//   - Executed from the flash procedure
//==============================================================================

dcl-proc set_field_error;
  dcl-pi *n;
    msg likeds(apmsal_T) const;
  end-pi;

//  select;
//  when msg.FIELD_NAME = c_HPNSELR_DAPICK;
//    i_dapick = true;
//  endsl;

  return;
end-proc;

//==============================================================================
// set_footer
//   Set panel footer fields
//==============================================================================

dcl-proc set_footer;
  dcl-pi *n end-pi;

  ftpanel = 'DELCUSA';
  ftuser = APP_user();
  ftdate = %char(APP_date());
  fttime = %char(APP_time());

  return;
end-proc;

//==============================================================================
// Copybook procedures
//==============================================================================

/include 'QCPYSRC/FLASH_P.rpgleinc'
