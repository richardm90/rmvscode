**free

//==============================================================================
// SHWCUS     - Show Customer Details
//
// 14/04/2021 - RM - created
//==============================================================================

/include 'QCPYSRC/APP_H.rpgleinc'
ctl-opt main(SHWCUS);

//==============================================================================
// Define global files
//==============================================================================

dcl-f SHWCUSD workstn infds(g_infds) indds(g_indds) sfile(MSGSFL:msrrn) usropn;

//==============================================================================
// Copybook definitions
//==============================================================================

/include 'QCPYSRC/APP_D.rpgleinc'
/include 'QCPYSRC/APMSAL_D.rpgleinc'
/include 'QCPYSRC/FLASH_D.rpgleinc'
/include 'QCPYSRC/INFDS_D.rpgleinc'
/include 'QCPYSRC/CUSDET_D.rpgleinc'

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
// SHWCUS
//   Program entry point
//==============================================================================

dcl-proc SHWCUS;
  dcl-pi *n;
    id like(INTEGER_t) const;
  end-pi;

  dcl-ds cusdet likeds(CUSDET_t) inz(*likeds);
  dcl-s exit like(BOOLEAN_t);

  open SHWCUSD;

  exsr init;

  dow not exit;
    flash();
    set_footer();
    write FOOTER;
    write MSGCTL;
    exfmt SHWCUSA;

    exsr process;
  enddo;

  close SHWCUSD;

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
    datitle = 'Show Customer';

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

    i_error = false;
    dafky1 = 'Enter  F3=Exit';
  endsr;

  begsr process;

    select;

    // Accept (Enter)
    when g_fkey = Enter;
      exit = true;

    // Return (F3)
    when g_fkey = F3;
      exit = true;

    other;
      addmsg('INVALID OPTION');

    endsl;

  endsr;

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

  ftpanel = 'SHWCUSA';
  ftuser = APP_user();
  ftdate = %char(APP_date());
  fttime = %char(APP_time());

  return;
end-proc;

//==============================================================================
// Copybook procedures
//==============================================================================

/include 'QCPYSRC/FLASH_P.rpgleinc'
