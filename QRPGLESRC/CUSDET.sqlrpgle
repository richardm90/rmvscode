**free

//==============================================================================
// CUSDET     - Customer Details SL Module
//
// 07/04/2021 - RM - created
//==============================================================================

ctl-opt text('Customer Details SL');
/define APP_SERVICE_PROGRAM
/include 'QCPYSRC/APP_H.rpgleinc'

//==============================================================================
// Copybook definitions
//==============================================================================

/include 'QCPYSRC/APP_D.rpgleinc'
/include 'QCPYSRC/APMSAL_D.rpgleinc'
/include 'QCPYSRC/CUSDETDL_D.rpgleinc'
/include 'QCPYSRC/CUSDET_D.rpgleinc'
/include 'QCPYSRC/RMAPP_D.rpgleinc'

// Global definitions
dcl-s initialized like(BOOLEAN_t);

//==============================================================================
// CUSDET_new
//   Service layer new procedure
//==============================================================================

dcl-proc CUSDET_new export;
  dcl-pi *n likeds(CUSDET_t) end-pi;

  dcl-ds service likeds(CUSDET_t) inz(*likeds);

  // Apply default values
  service.STATUS     = CUSDET_STATUS_NEW;

  return service;
end-proc;

//==============================================================================
// CUSDET_add
//   Service layer add procedure
//==============================================================================

dcl-proc CUSDET_add export;
  dcl-pi *n like(BOOLEAN_t);
    service likeds(CUSDET_t);
  end-pi;

  dcl-ds data likeds(CUSDET_t) inz(*likeds);
  dcl-s error like(BOOLEAN_t);

  eval-corr data = service;
  error = CUSDETDL_add(data);
  eval-corr service = data;

  return error;
end-proc;

//==============================================================================
// CUSDET_get
//   Service layer get procedure
//==============================================================================

dcl-proc CUSDET_get export;
  dcl-pi *n like(BOOLEAN_t);
    service likeds(CUSDET_t);
  end-pi;

  dcl-ds data likeds(CUSDET_t) inz(*likeds);
  dcl-s found like(BOOLEAN_t);

  eval-corr data = service;
  found = CUSDETDL_get(data);
  eval-corr service = data;

  return found;
end-proc;

//==============================================================================
// CUSDET_update
//   Service layer update procedure
//==============================================================================

dcl-proc CUSDET_update export;
  dcl-pi *n like(BOOLEAN_t);
    service likeds(CUSDET_t);
  end-pi;

  dcl-ds data likeds(CUSDET_t) inz(*likeds);
  dcl-s error like(BOOLEAN_t);

  eval-corr data = service;
  error = CUSDETDL_update(data);
  eval-corr service = data;

  return error;
end-proc;

//==============================================================================
// CUSDET_delete
//   Service layer delete procedure
//==============================================================================

dcl-proc CUSDET_delete export;
  dcl-pi *n like(BOOLEAN_t);
    service likeds(CUSDET_t);
  end-pi;

  dcl-ds data likeds(CUSDET_t) inz(*likeds);
  dcl-s error like(BOOLEAN_t);

  eval-corr data = service;
  error = CUSDETDL_delete(data);
  eval-corr service = data;

  return error;
end-proc;

//==============================================================================
// CUSDET_list
//   Service layer list procedure
//==============================================================================

dcl-proc CUSDET_list export;
  dcl-pi *n like(UNSIGNED_INTEGER_t);
    calc likeds(APP_paging_t);
    sel  likeds(CUSDET_list_selections_t) const;
    data likeds(CUSDET_list_t) dim(APP_MAXIMUM_PAGE_ROWS);
  end-pi;

  dcl-ds dl_sel  likeds(CUSDET_list_selections_t) inz(*likeds);
  dcl-ds dl_data likeds(CUSDET_list_t) dim(APP_MAXIMUM_PAGE_ROWS) inz(*likeds);
  dcl-s got_rows like(UNSIGNED_INTEGER_t);

  eval-corr dl_sel = sel;
  got_rows = CUSDETDL_list(calc: dl_sel: dl_data);
  eval-corr data(*) = dl_data(*);

  return got_rows;
end-proc;

//==============================================================================
// CUSDET_fetch
//   Service layer fetch procedure
//==============================================================================

dcl-proc CUSDET_fetch export;
  dcl-pi *n like(BOOLEAN_t);
    sel  likeds(CUSDET_fetch_selections_t) const;
    data likeds(CUSDET_list_t);
  end-pi;

  return CUSDETDL_fetch(sel: data);
end-proc;

//==============================================================================
// CUSDET_error
//   Returns the error state from the last SQL command
//==============================================================================

dcl-proc CUSDET_error export;
  dcl-pi *n like(BOOLEAN_t) end-pi;

  return CUSDETDL_error();
end-proc;

//==============================================================================
// CUSDET_found
//   Returns the found state from the last _get procedure
//==============================================================================

dcl-proc CUSDET_found export;
  dcl-pi *n like(BOOLEAN_t) end-pi;

  return CUSDETDL_found();
end-proc;

//==============================================================================
// CUSDET_exists
//   Determines whether the given customer code exists
//
//   If the ID parameter is passed then the check is performed on records
//   other than the passed ID.
//==============================================================================

dcl-proc CUSDET_exists export;
  dcl-pi *n like(BOOLEAN_t);
    CODE like(CUSDET_CODE_t) const;
    ID   like(INTEGER_t) const options(*nopass);
  end-pi;

  dcl-ds sel  likeds(CUSDET_fetch_selections_t) inz(*likeds);
  dcl-ds data likeds(CUSDET_list_t) inz(*likeds);

  reset sel;
  sel.CODE = CODE;
  if %parms() >= %parmnum(ID);
    sel.ID = ID;
    sel.NOT_ID = 'Y';
  endif;
  CUSDET_fetch(sel: data);

  return CUSDET_found();
end-proc;
