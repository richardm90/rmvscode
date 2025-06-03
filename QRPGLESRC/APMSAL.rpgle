**free

//==============================================================================
// APMSAL     - Application Messages SAL Module
//
// 07/04/2021 - RM - created
//==============================================================================

/define APP_SERVICE_PROGRAM
/include 'QCPYSRC/APP_H.rpgleinc'

//==============================================================================
// Define global fields
//==============================================================================

dcl-s g_created_by_process like(PGM_NAME_t) inz('*UNKNOWN');
dcl-s g_msg_count like(INTEGER_t);
dcl-s g_msg_count_diagnostic like(INTEGER_t);
dcl-s g_msg_count_information like(INTEGER_t);
dcl-s g_msg_count_warning like(INTEGER_t);
dcl-s g_msg_count_error like(INTEGER_t);

//==============================================================================
// Copybook definitions
//==============================================================================

/include 'QCPYSRC/APP_D.rpgleinc'
/include 'QCPYSRC/APMDAL_D.rpgleinc'
/include 'QCPYSRC/APMSAL_D.rpgleinc'
/include 'QCPYSRC/PSDS_D.rpgleinc'

//==============================================================================
// APMSAL_inz
//   Initialise Application Messages ready for a new process
//==============================================================================

dcl-proc APMSAL_inz export;
  dcl-pi *n;
    process like(PGM_NAME_t) const options(*nopass);
  end-pi;

  dcl-ds data likeds(APMDAL_t) inz(*likeds);

  reset g_created_by_process;
  if %parms() >= %parmnum(process) and process <> '';
    g_created_by_process = process;
  endif;

  reset data;
  data.JOB_NAME = APP_job_full_name();
  APMDAL_first_message(true);

  reset g_msg_count;
  reset g_msg_count_diagnostic;
  reset g_msg_count_information;
  reset g_msg_count_warning;
  reset g_msg_count_error;

  return;
end-proc;

//==============================================================================
// APMSAL_msg
//   Determine whether one of more messages have been added, regardless of type
//==============================================================================

dcl-proc APMSAL_msg export;
  dcl-pi *n like(BOOLEAN_t) end-pi;

  return (g_msg_count>0);
end-proc;

//==============================================================================
// APMSAL_diagnostic
//   Determine whether one of more messages of type diagnostic have been added
//==============================================================================

dcl-proc APMSAL_diagnostic export;
  dcl-pi *n like(BOOLEAN_t) end-pi;

  return (g_msg_count_diagnostic>0);
end-proc;

//==============================================================================
// APMSAL_information
//   Determine whether one of more messages of type information have been added
//==============================================================================

dcl-proc APMSAL_information export;
  dcl-pi *n like(BOOLEAN_t) end-pi;

  return (g_msg_count_information>0);
end-proc;

//==============================================================================
// APMSAL_warning
//   Determine whether one of more messages of type warning have been added
//==============================================================================

dcl-proc APMSAL_warning export;
  dcl-pi *n like(BOOLEAN_t) end-pi;

  return (g_msg_count_warning>0);
end-proc;

//==============================================================================
// APMSAL_error
//   Determine whether one of more messages of type error have been added
//==============================================================================

dcl-proc APMSAL_error export;
  dcl-pi *n like(BOOLEAN_t) end-pi;

  return (g_msg_count_error>0);
end-proc;

//==============================================================================
// APMSAL_add
//   Service layer add procedure for view APP_MESSAGES_DL
//==============================================================================

dcl-proc APMSAL_add export;
  dcl-pi *n like(BOOLEAN_t);
    TEXT like(APMSAL_text_t) const;
    TYPE like(APMSAL_type_t) const options(*nopass);
    FIELD_NAME like(FIELD_NAME_t) const options(*nopass);
    CREATED_BY_PROCESS like(PGM_NAME_t) const options(*nopass);
  end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);
  dcl-ds data likeds(APMDAL_t) inz(*likeds);
  dcl-s error like(BOOLEAN_t);

  reset data;
  data.JOB_NAME = APP_job_full_name();
  data.TEXT = TEXT;
  if %parms() >= %parmnum(TYPE);
    data.TYPE = TYPE;
  endif;
  if %parms() >= %parmnum(FIELD_NAME);
    data.FIELD_NAME = FIELD_NAME;
  endif;
  if data.FIELD_NAME = '';
    data.FIELD_NAME = APMSAL_FIELD_NAME_NONE;
  endif;
  if %parms() >= %parmnum(CREATED_BY_PROCESS);
    data.CREATED_BY_PROCESS = CREATED_BY_PROCESS;
  endif;
  if data.CREATED_BY_PROCESS = '';
    data.CREATED_BY_PROCESS = g_created_by_process;
  endif;

  error = APMDAL_add(data);

  if not error;
    eval-corr service = data;
    update_msg_count(service);
  endif;

  return error;
end-proc;

//==============================================================================
// update_msg_count
//   Update the appropriate count for the message type
//==============================================================================

dcl-proc update_msg_count;
  dcl-pi *n;
    service likeds(APMSAL_t);
  end-pi;

  select;
    when service.TYPE = APMSAL_TYPE_DIAGNOSTIC;
      g_msg_count_diagnostic += 1;
    when service.TYPE = APMSAL_TYPE_INFORMATION;
      g_msg_count_information += 1;
    when service.TYPE = APMSAL_TYPE_WARNING;
      g_msg_count_warning += 1;
    when service.TYPE = APMSAL_TYPE_ERROR;
      g_msg_count_error += 1;
  endsl;

  g_msg_count += 1;

  return;
end-proc;

//==============================================================================
// APMSAL_get
//   Service layer add procedure for view APP_MESSAGES_DL
//==============================================================================

dcl-proc APMSAL_get export;
  dcl-pi *n like(BOOLEAN_t);
    service likeds(APMSAL_t);
  end-pi;

  dcl-ds data likeds(APMDAL_t) inz(*likeds);
  dcl-s error like(BOOLEAN_t);

  eval-corr data = service;
  error = APMDAL_get(data);
  eval-corr service = data;

  return error;
end-proc;

//==============================================================================
// APMSAL_update
//   Service layer add procedure for view APP_MESSAGES_DL
//==============================================================================

dcl-proc APMSAL_update export;
  dcl-pi *n like(BOOLEAN_t);
    service likeds(APMSAL_t);
  end-pi;

  dcl-ds data likeds(APMDAL_t) inz(*likeds);
  dcl-s error like(BOOLEAN_t);

  eval-corr data = service;
  data.JOB_NAME = APP_job_full_name();
  error = APMDAL_update(data);
  eval-corr service = data;

  return error;
end-proc;

//==============================================================================
// APMSAL_delete
//   Service layer add procedure for view APP_MESSAGES_DL
//==============================================================================

dcl-proc APMSAL_delete export;
  dcl-pi *n like(BOOLEAN_t);
    service likeds(APMSAL_t);
  end-pi;

  dcl-ds data likeds(APMDAL_t) inz(*likeds);
  dcl-s error like(BOOLEAN_t);

  eval-corr data = service;
  data.JOB_NAME = APP_job_full_name();
  error = APMDAL_delete(data);
  eval-corr service = data;

  return error;
end-proc;

//==============================================================================
// APMSAL_list
//   Service layer list procedure for view APP_MESSAGES_DL_LIST
//==============================================================================

dcl-proc APMSAL_list export;
  dcl-pi *n like(UNSIGNED_INTEGER_t);
    calc likeds(APP_paging_t);
    sel  likeds(APMSAL_list_selections_t) const;
    data likeds(APMSAL_list_t) dim(APP_MAXIMUM_PAGE_ROWS);
  end-pi;

  dcl-ds dl_sel likeds(APMDAL_list_selections_t) inz(*likeds);
  dcl-ds dl_data likeds(APMDAL_list_t) dim(APP_MAXIMUM_PAGE_ROWS) inz(*likeds);
  dcl-s got_rows like(UNSIGNED_INTEGER_t);

  eval-corr dl_sel = sel;
  got_rows = APMDAL_list(calc: dl_sel: dl_data);
  eval-corr data(*) = dl_data(*);

  return got_rows;
end-proc;

//==============================================================================
// APMSAL_open
//   Service layer open cursor procedure for view APP_MESSAGES_DL
//   - The return boolean indicates whether an error occurred during the open
//==============================================================================

dcl-proc APMSAL_open export;
  dcl-pi *n like(BOOLEAN_t);
    sel likeds(APMSAL_open_selections_t) const options(*nopass);
  end-pi;

  dcl-ds l_sel likeds(APMSAL_open_selections_t) inz(*likeds);
  dcl-ds data_sel likeds(APMDAL_open_selections_t) inz(*likeds);
  dcl-s error like(BOOLEAN_t);

  if %parms >= %parmnum(sel);
    l_sel = sel;
  endif;

  if l_sel.JOB_NAME = '';
    l_sel.JOB_NAME = APP_job_full_name();
  endif;

  eval-corr data_sel = l_sel;
  error = APMDAL_open(data_sel);

  return error;
end-proc;

//==============================================================================
// APMSAL_fetch
//   Service layer fetch cursor procedure for view APP_MESSAGES_DL
//   - The return boolean specifies whether the fetch was successful
//==============================================================================

dcl-proc APMSAL_fetch export;
  dcl-pi *n like(BOOLEAN_t);
    service likeds(APMSAL_t);
  end-pi;

  dcl-ds data likeds(APMDAL_t) inz(*likeds);
  dcl-s found like(BOOLEAN_t);

  eval-corr data = service;
  found = APMDAL_fetch(data);
  eval-corr service = data;

  return found;
end-proc;

//==============================================================================
// APMSAL_close
//   Service layer close cursor procedure for view APP_MESSAGES_DL
//   - The return boolean indicates whether an error occurred during the close
//==============================================================================

dcl-proc APMSAL_close export;
  dcl-pi *n like(BOOLEAN_t) end-pi;

  dcl-s error like(BOOLEAN_t);

  error = APMDAL_close();

  return error;
end-proc;

//==============================================================================
// APMSAL_open_desc
//   Service layer open_desc cursor procedure for view APP_MESSAGES_DL
//   - The return boolean indicates whether an error occurred during the open
//   - Valid selections; JOB_NAME, FIELD_NAME and TYPE
//==============================================================================

dcl-proc APMSAL_open_desc export;
  dcl-pi *n like(BOOLEAN_t);
    sel likeds(APMSAL_open_selections_t) const options(*nopass);
  end-pi;

  dcl-ds l_sel likeds(APMSAL_open_selections_t) inz(*likeds);
  dcl-ds data_sel likeds(APMDAL_open_selections_t) inz(*likeds);
  dcl-s error like(BOOLEAN_t);

  if %parms >= %parmnum(sel);
    l_sel = sel;
  endif;

  if l_sel.JOB_NAME = '';
    l_sel.JOB_NAME = APP_job_full_name();
  endif;

  eval-corr data_sel = l_sel;
  error = APMDAL_open_desc(data_sel);

  return error;
end-proc;

//==============================================================================
// APMSAL_fetch_desc
//   Service layer fetch_desc cursor procedure for view APP_MESSAGES_DL
//   - The return boolean specifies whether the fetch was successful
//==============================================================================

dcl-proc APMSAL_fetch_desc export;
  dcl-pi *n like(BOOLEAN_t);
    service likeds(APMSAL_t);
  end-pi;

  dcl-ds data likeds(APMDAL_t) inz(*likeds);
  dcl-s found like(BOOLEAN_t);

  eval-corr data = service;
  found = APMDAL_fetch_desc(data);
  eval-corr service = data;

  return found;
end-proc;

//==============================================================================
// APMSAL_close_desc
//   Service layer close_desc cursor procedure for view APP_MESSAGES_DL
//   - The return boolean indicates whether an error occurred during the close
//==============================================================================

dcl-proc APMSAL_close_desc export;
  dcl-pi *n like(BOOLEAN_t) end-pi;

  dcl-s error like(BOOLEAN_t);

  error = APMDAL_close_desc();

  return error;
end-proc;

//==============================================================================
// APMSAL_fetch_first
//   Service layer fetch first message for view APP_MESSAGES_DL
//   - The return boolean specifies whether the fetch was successful
//==============================================================================

dcl-proc APMSAL_fetch_first export;
  dcl-pi *n like(BOOLEAN_t);
    service likeds(APMSAL_t);
  end-pi;

  dcl-ds sel likeds(APMSAL_open_selections_t) inz(*likeds);
  dcl-s error like(BOOLEAN_t);
  dcl-s found like(BOOLEAN_t);

  reset sel;
  sel.TYPE = service.TYPE;

  error = APMSAL_open(sel);
  if not error;
    found = APMSAL_fetch(service);
    APMSAL_close();
  endif;

  return found;
end-proc;

//==============================================================================
// APMSAL_fetch_last
//   Service layer fetch last message for view APP_MESSAGES_DL
//   - The return boolean specifies whether the fetch was successful
//==============================================================================

dcl-proc APMSAL_fetch_last export;
  dcl-pi *n like(BOOLEAN_t);
    service likeds(APMSAL_t);
  end-pi;

  dcl-ds sel likeds(APMSAL_open_selections_t) inz(*likeds);
  dcl-s error like(BOOLEAN_t);
  dcl-s found like(BOOLEAN_t);

  reset sel;
  sel.TYPE = service.TYPE;

  error = APMSAL_open_desc(sel);
  if not error;
    found = APMSAL_fetch_desc(service);
    APMSAL_close_desc();
  endif;

  return found;
end-proc;

//==============================================================================

dcl-proc APP_job_full_name;
  dcl-pi *n like(JOB_FULL_NAME_t) end-pi;

  dcl-s job like(JOB_FULL_NAME_t);

  job = %editc(psds.job_number:'X') + '/'
      + %trimr(psds.job_user) + '/'
      + %trimr(psds.job_name);

  return job;
end-proc;
