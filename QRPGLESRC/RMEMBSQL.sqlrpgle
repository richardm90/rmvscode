**free

//==============================================================================
// RMEMBSQL   - Embedded SQL RPG Helper Module
//
// 30/10/2021 - RM - created
//==============================================================================

ctl-opt text('RMTOOLS: Embedded SQL RPG Helper Module');
ctl-opt option(*nodebugio:*noexpdds:*noext:*nounref:*noshowcpy:*noshowskp:*srcstmt);
ctl-opt nomain;

///
// Include copybooks
///

/include 'QCPYSRC/RMAPP_D.rpgleinc'
/include 'QCPYSRC/RMEMBSQL_D.rpgleinc'
/include 'QCPYSRC/RMTOOLS_D.rpgleinc'

///
// Declare global fields
///

// Global SQL state data structure
dcl-ds state likeds(EMBSQL_state_t) inz(*likeds);

///
// Initialise the EMBSQL state
///

dcl-proc EMBSQL_inz export;
  dcl-pi *n end-pi;

  reset state;

  return;
end-proc;

///
// Sets and returns the global SQL state
//
// If previously set, since the last EMBSQL_inz() procedure call, then the
// previously set global SQL state is simply returned
//
// Diagnostic and error messages are written to the job log, see log_message
//
// @return the global SQL state
///

dcl-proc set_state;
  dcl-pi *n likeds(EMBSQL_state_t) end-pi;

  if not state.set;
    state = EMBSQL_state();
  endif;

  return state;
end-proc;

///
// Returns the current SQL state, as a data structure
//
// @return the global SQL state
///

dcl-proc EMBSQL_state export;
  dcl-pi *n likeds(EMBSQL_state_t) end-pi;

  dcl-ds state likeds(EMBSQL_state_t) inz(*likeds);

  reset state;
  state.set = true;

  // Set state.sqlstate, state.sqlcode and state.msg
  exec sql GET DIAGNOSTICS CONDITION 1
    :state.sqlstate = RETURNED_SQLSTATE,
    :state.sqlcode = DB2_RETURNED_SQLCODE,
    :state.msg = MESSAGE_TEXT;

  // Set state.diag and state.error
  select;
    when %subst(state.sqlstate:1:2) = '00'  // Class Code 00: Unqualified Successful Completion
      or (state.sqlstate = '02000' and state.sqlcode = 100);
      // Nothing to do!
    when %subst(state.sqlstate:1:2) = '01'; // Class Code 01: Warning
      state.diag = true;
    when %subst(state.sqlstate:1:2) = '02'; // Class Code 02: No Data
      state.diag = true;
    other;
      state.error = true;
  endsl;

  // Set state.found
  if not state.error
    and ( state.sqlstate <> '02000' or state.sqlcode <> 100);
    state.found = true;
  endif;

  log_message(state);

  return state;
end-proc;

///
// Check for an SQL error
//
// EMBSQL_error can affect SQLSTATE and SQLCODE so if you need to call
// EMBSQL_found then call EMBSQL_found first
//
// @param optional SQL state, defaults to current global SQL state
// @return the SQL state error condition
///

dcl-proc EMBSQL_error export;
  dcl-pi *n like(BOOLEAN_t);
    in_state likeds(EMBSQL_state_t) const options(*nopass);
  end-pi;

  dcl-ds state likeds(EMBSQL_state_t) inz(*likeds);

  if %parms() >= %parmnum(in_state);
    state = in_state;
  else;
    state = set_state();
  endif;

  return state.error;
end-proc;

///
// Check whether the last SQL command found a record
//
// @param optional SQL state, defaults to current global SQL state
// @return the SQL state found condition
///

dcl-proc EMBSQL_found export;
  dcl-pi *n like(BOOLEAN_t);
    in_state likeds(EMBSQL_state_t) options(*nopass);
  end-pi;

  dcl-ds state likeds(EMBSQL_state_t) inz(*likeds);

  if %parms() >= %parmnum(in_state);
    state = in_state;
  else;
    state = set_state();
  endif;

  return state.found;
end-proc;

///
// Returns the SQL error message text
//
// @param optional SQL state, defaults to current global SQL state
// @return the SQL state message
///

dcl-proc EMBSQL_msg export;
  dcl-pi EMBSQL_msg like(EMBSQL_msg_t);
    in_state likeds(EMBSQL_state_t) options(*nopass);
  end-pi;

  dcl-ds state likeds(EMBSQL_state_t) inz(*likeds);

  if %parms() >= %parmnum(in_state);
    state = in_state;
  else;
    state = set_state();
  endif;

  return state.msg;
end-proc;

///
// Returns the SQL state
//
// @param optional SQL state, defaults to current global SQL state
// @return the SQL state
///

dcl-proc EMBSQL_sqlstate export;
  dcl-pi EMBSQL_sqlstate like(EMBSQL_sqlstate_t);
    in_state likeds(EMBSQL_state_t) options(*nopass);
  end-pi;

  dcl-ds state likeds(EMBSQL_state_t) inz(*likeds);

  if %parms() >= %parmnum(in_state);
    state = in_state;
  else;
    state = set_state();
  endif;

  return state.sqlstate;
end-proc;

///
// Returns the SQL code
//
// @param optional SQL state, defaults to current global SQL state
// @return the SQL code
///

dcl-proc EMBSQL_sqlcode export;
  dcl-pi EMBSQL_sqlcode like(EMBSQL_sqlcode_t);
    in_state likeds(EMBSQL_state_t) options(*nopass);
  end-pi;

  dcl-ds state likeds(EMBSQL_state_t) inz(*likeds);

  if %parms() >= %parmnum(in_state);
    state = in_state;
  else;
    state = set_state();
  endif;

  return state.sqlcode;
end-proc;

///
// Throw an escape message when an error occurs
//
// This procedure is the same as EMBSQL_state other than the fact that an
// an error is thrown
//
// @return the SQL state
///

//==============================================================================
// EMBSQL_check
//   Throw an escape message when an error occurs
//   -
//==============================================================================

dcl-proc EMBSQL_check export;
  dcl-pi *n likeds(EMBSQL_state_t) end-pi;

  dcl-ds state likeds(EMBSQL_state_t) inz(*likeds);

  reset state;
  state.set = true;

  // Set state.sqlstate, state.sqlcode and state.msg
  exec sql GET DIAGNOSTICS CONDITION 1
    :state.sqlstate = RETURNED_SQLSTATE,
    :state.sqlcode = DB2_RETURNED_SQLCODE,
    :state.msg = MESSAGE_TEXT;

  // Set state.diag and state.error
  select;
    when %subst(state.sqlstate:1:2) = '00'  // Class Code 00: Unqualified Successful Completion
      or (state.sqlstate = '02000' and state.sqlcode = 100);
      // Nothing to do!
    when %subst(state.sqlstate:1:2) = '01'; // Class Code 01: Warning
      state.diag = true;
    when %subst(state.sqlstate:1:2) = '02'; // Class Code 02: No Data
      state.diag = true;
    other;
      state.error = true;
  endsl;

  // Set state.found
  if not state.error
    and ( state.sqlstate <> '02000' or state.sqlcode <> 100);
    state.found = true;
  endif;

  log_message(state: true);

  return state;
end-proc;

//==============================================================================
// log_message
//   Writes diagnostic and error messages to the job log
//   - a diagnostic (warning or no data) is always logged as an information
//     message
//   - an error is logged as an information message, or when throw_error is
//     passed as true, thrown as an escape message (this procedure ends and
//     the escape propagates to the caller of the procedure that called it)
//   - the state is expected to have either diag or error set, not both
//   Not exported, it is only used within this module
//==============================================================================

dcl-proc log_message;
  dcl-pi *n;
    state likeds(EMBSQL_state_t) const;
    throw_error like(BOOLEAN_t) const options(*nopass);
  end-pi;

  dcl-s msg like(EMBSQL_msg_t);
  dcl-s throw_error_l like(BOOLEAN_t);

  if %parms() >= %parmnum(throw_error);
    throw_error_l = throw_error;
  endif;

  if state.diag or state.error;
    msg = state.msg
        + ' (SQLSTATE = ' + state.sqlstate
        + ', SQLCODE = ' + %char(state.sqlcode) + ')';

    if state.diag;
      APP_log(msg);
    endif;

    if state.error;
      if throw_error_l;
        APP_escape(msg);
      else;
        APP_log(msg);
      endif;
    endif;
  endif;

  return;
end-proc;
