**free

//==============================================================================
// RMAPP01    - Application Helper - IBM i Job Module
//
// 31/05/2025 - RM - created
//==============================================================================

ctl-opt text('RMTOOLS: Application Helper - IBM i Job Module');
ctl-opt option(*nodebugio:*noexpdds:*noext:*nounref:*noshowcpy:*noshowskp:*srcstmt);
ctl-opt nomain;

///
// Copybook definitions
///

/include 'QCPYSRC/PSDS_D.rpgleinc'
/include 'QCPYSRC/RMAPP_D.rpgleinc'
/include 'QCPYSRC/RMTOOLS_D.rpgleinc'

//==============================================================================

dcl-proc APP_job_full_name export;
  dcl-pi *n like(JOB_FULL_NAME_t) end-pi;

  dcl-s job like(JOB_FULL_NAME_t);

  job = %editc(psds.job_number:'X') + '/'
      + %trimr(psds.job_user) + '/'
      + %trimr(psds.job_name);

  return job;
end-proc;

///
// Return the current application user
//
// @return the current application user
///

dcl-proc APP_user export;
  dcl-pi *n like(APP_USER_t) end-pi;

  return psds.current_user;
end-proc;

///
// Return the current application date
//
// @return the current application date
///

dcl-proc APP_date export;
  dcl-pi *n like(APP_DATE_t) end-pi;

  dcl-s l_date like(APP_DATE_t);

  l_date = %date();

  return l_date;
end-proc;

///
// Return the current application time
//
// @return the current application time
///

dcl-proc APP_time export;
  dcl-pi *n like(APP_TIME_t) end-pi;

  dcl-s l_time like(APP_TIME_t);

  l_time = %time();

  return l_time;
end-proc;

///
// Return the current application timestamp
//
// @return the current application timestamp
///

dcl-proc APP_timestamp export;
  dcl-pi *n like(APP_TIMESTAMP_t) end-pi;

  dcl-s l_timestamp like(APP_TIMESTAMP_t);

  l_timestamp = %timestamp();

  return l_timestamp;
end-proc;
