**free

//==============================================================================
// WRKCUS     - Work with Customers
//
// 14/04/2021 - RM - created
//==============================================================================

ctl-opt text('Work With Customers');
/define APP_ACTGRP_NEW
/include 'QCPYSRC/APP_H.rpgleinc'
ctl-opt main(WRKCUS);

//==============================================================================
// Define global files
//==============================================================================

dcl-f WRKCUSD workstn infds(g_infds) indds(g_indds) sfile(MSGSFL:msrrn) usropn
                                                    sfile(WRKCUSAS:darrn);

//==============================================================================
// Copybook definitions
//==============================================================================

/include 'QCPYSRC/APP_D.rpgleinc'
/include 'QCPYSRC/ADDMSG_D.rpgleinc'
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
  i_dasfldsp          ind pos(36);
  i_dasfldspctl       ind pos(37);
  i_dasflend          ind pos(38);
  i_dasflclr          ind pos(39);
  i_error             ind pos(90);
end-ds;

//==============================================================================
// Define global prototypes
//==============================================================================

dcl-pr ADDCUS extpgm('ADDCUS');
end-pr;

dcl-pr SHWCUS extpgm('SHWCUS');
  id like(INTEGER_t) const;
end-pr;

dcl-pr UPDCUS extpgm('UPDCUS');
  id like(INTEGER_t) const;
end-pr;

dcl-pr DELCUS extpgm('DELCUS');
  id like(INTEGER_t) const;
end-pr;

//==============================================================================
// WRKCUS
//   Program entry point
//==============================================================================

dcl-proc WRKCUS;
  dcl-pi *n end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(CUSDET_list_selections_t) inz(*likeds);
  dcl-ds data likeds(CUSDET_list_t) dim(APP_MAXIMUM_PAGE_ROWS) inz(*likeds);
  dcl-s exit like(BOOLEAN_t);
  dcl-s index like(INTEGER_t);
  dcl-s last_DASEARCH like(DASEARCH);
  dcl-s last_DAPAGE   like(DAPAGE);

  open WRKCUSD;

  exsr init;

  addmsg_info('Hello World!');

  dow not exit;
    flash();
    set_footer();
    write FOOTER;
    write WRKCUSAF;
    write MSGCTL;
    exfmt WRKCUSAC;

    exsr process;
  enddo;

  close WRKCUSD;

  return;

  begsr init;
    // Retrieve customer details
    reset calc;
    calc.req_page = 1;
    calc.req_page_rows = 15;
    reset sel;
    CUSDET_list(calc: sel: data);
    if CUSDET_error();
      addmsg('ERROR RETRIEVING CUSTOMER DETAILS');
      exit = true;
    endif;

    exsr init_scra;
  endsr;

  begsr init_scra;
    datitle = 'Work with Customers';
    dasearch = '';

    exsr set_subfile;

    i_error = false;
    dafky1 = 'Roll  Enter  F3=Exit  F6=Add  F13=Show  F14=Update  F15=Delete';
  endsr;

  begsr process;

    select;

      // Accept (Enter)
      when g_fkey = Enter;
        // Enter pressed on subfile row, show_customer customer
        if DACRRN > 0;
          chain DACRRN WRKCUSAS;
          show_customer(DASID);
        endif;
        // Process search and page selections
        exsr search;

      // Return (F3)
      when g_fkey = F3;
        exit = true;

      // Add (F6)
      when g_fkey = F6;
        add_customer();
        exsr refresh_subfile;

      // Roll Down (F7)
      when g_fkey = F7 or g_fkey = Rollup;
        exsr roll_down;

      // Show (F13)
      when g_fkey = F13;
        if DACRRN = 0;
          addmsg('POSITION THE CURSOR ON THE CUSTOMER ROW');
        else;
          chain DACRRN WRKCUSAS;
          show_customer(DASID);
        endif;

      // Update (F14)
      when g_fkey = F14;
        if DACRRN = 0;
          addmsg('POSITION THE CURSOR ON THE CUSTOMER ROW');
        else;
          chain DACRRN WRKCUSAS;
          update_customer(DASID);
          exsr refresh_subfile;
        endif;

      // Delete (F15)
      when g_fkey = F15;
        if DACRRN = 0;
          addmsg('POSITION THE CURSOR ON THE CUSTOMER ROW');
        else;
          chain DACRRN WRKCUSAS;
          delete_customer(DASID);
          exsr refresh_subfile;
        endif;

      // Roll Up (F8)
      when g_fkey = F8 or g_fkey = Rolldown;
        exsr roll_up;

      other;
        addmsg('INVALID OPTION');

    endsl;

  endsr;

  begsr search;
    if DASEARCH <> last_DASEARCH;
      sel.SEARCH = DASEARCH;
      calc.req_page = 1;
      CUSDET_list(calc: sel: data);
      exsr set_subfile;

    elseif DAPAGE <> last_DAPAGE;
      if DAPAGE > calc.total_pages;
        addmsg_info('SELECTED PAGE OUT OF LIMITS');
        DAPAGE = calc.total_pages;
      endif;
      if DAPAGE < 1;
        addmsg_info('SELECTED PAGE OUT OF LIMITS');
        DAPAGE = 1;
      endif;
      calc.req_page = DAPAGE;
      CUSDET_list(calc: sel: data);
      exsr set_subfile;
    endif;

    last_DASEARCH = DASEARCH;
    last_DAPAGE   = DAPAGE;
  endsr;

  begsr roll_up;
    if calc.req_page <= 1;
      addmsg('NO MORE PAGES');
      leavesr;
    endif;

    calc.req_page -= 1;
    CUSDET_list(calc: sel: data);

    exsr set_subfile;
  endsr;

  begsr roll_down;
    if calc.req_page >= calc.total_pages;
      addmsg('NO MORE PAGES');
      leavesr;
    endif;

    calc.req_page += 1;
    CUSDET_list(calc: sel: data);

    exsr set_subfile;
  endsr;

  //==============================================================================
  // refresh_subfile
  //   Refresh the current subfile page
  //==============================================================================

  begsr refresh_subfile;
    CUSDET_list(calc: sel: data);
    exsr set_subfile;
  endsr;

  //==============================================================================
  // set_subfile
  //   Load subfile page
  //==============================================================================

  begsr set_subfile;
    i_dasfldsp = false;
    i_dasfldspctl = false;
    i_dasflend = false;
    i_dasflclr = true;
    write WRKCUSAC;

    darrn = 0;
    for index = 1 to calc.got_rows;
      DASID   = data(index).ID;
      DASSTAT = data(index).STATUS_DESCRIPTION;
      DASCODE = data(index).CODE;
      DASNAME = data(index).NAME;
      DASPCOD = data(index).POSTCODE;

      darrn += 1;
      write WRKCUSAS;
    endfor;

    i_dasfldsp = (darrn > 0);
    i_dasfldspctl = true;
    i_dasflend = true;
    i_dasflclr = false;

    exsr set_page_count;
    exsr set_more;
  endsr;

  begsr set_page_count;
    dapage = calc.req_page;
    datopg = 'of ' + %char(calc.total_pages);
  endsr;

  begsr set_more;
    if calc.req_page = calc.total_pages;
      damore = ' Bottom';
    else;
      damore = 'More...';
    endif;
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

  // select;
  //   when msg.FIELD_NAME = c_HPNSELR_DAPICK;
  //     i_dapick = true;
  // endsl;

  return;
end-proc;

//==============================================================================
// set_footer
//   Set panel footer fields
//==============================================================================

dcl-proc set_footer;
  dcl-pi *n end-pi;

  ftpanel = 'WRKCUSA';
  ftuser = APP_user();
  ftdate = %char(APP_date());
  fttime = %char(APP_time());

  return;
end-proc;

//==============================================================================
// add_customer
//   Add customer details
//==============================================================================

dcl-proc add_customer;
  dcl-pi *n end-pi;

  ADDCUS();

  return;
end-proc;

///
// Show customer details.
//
// Accesses global DACRRN field.
//
// @param The customer details id.
///

dcl-proc show_customer;
  dcl-pi *n;
    id like(INTEGER_t) const;
  end-pi;

  addmsg_diag('Subfile record = ' + %char(DACRRN));

  SHWCUS(id);

  return;
end-proc;

//==============================================================================
// update_customer
//   Update customer details
//==============================================================================

dcl-proc update_customer;
  dcl-pi *n;
    id like(INTEGER_t) const;
  end-pi;

  addmsg_diag('Subfile record = ' + %char(DACRRN));

  UPDCUS(id);

  return;
end-proc;

//==============================================================================
// delete_customer
//   Delete customer details
//==============================================================================

dcl-proc delete_customer;
  dcl-pi *n;
    id like(INTEGER_t) const;
  end-pi;

  addmsg_diag('Subfile record = ' + %char(DACRRN));

  DELCUS(id);

  return;
end-proc;

//==============================================================================
// Copybook procedures
//==============================================================================

/include 'QCPYSRC/ADDMSG_P.rpgleinc'
/include 'QCPYSRC/FLASH_P.rpgleinc'
