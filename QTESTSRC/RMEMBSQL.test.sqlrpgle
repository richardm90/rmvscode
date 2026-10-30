**free

//==============================================================================
// RMEMBSQL.test - Tests for RMEMBSQL (Embedded SQL RPG Helper Module)
//
// Object name is TRMEMBSQL (strip .test, prefix T).
//
// EMBSQL_state and EMBSQL_check report on the last SQL statement run in the
// job (GET DIAGNOSTICS), so this suite runs a few small embedded SQL statements
// of its own to put the job into a known state:
//
//   success    VALUES 1 INTO ...                       SQLSTATE 00000
//   not found  SELECT ... WHERE A = 0                  SQLSTATE 02000, code 100
//   warning    SELECT 'ABCDEFGH' INTO a char(3)       SQLSTATE 01xxx
//   error      SELECT from a table that is not there   SQLSTATE 42704, code -204
//
// None of them touch a real table or change any data, so there is nothing to
// clean up. The accessors (EMBSQL_error, _found, _msg, _sqlstate, _sqlcode) are
// also tested as pure functions by passing them hand-built states.
//
// Documented contract (module comments):
// - EMBSQL_state  returns the state and does NOT throw, so callers can inspect
//                 .error themselves (CUSDETDL does exactly that)
// - EMBSQL_check  is "the same as EMBSQL_state other than the fact that an
//                 error is thrown"
//
// log_message is private to the module, so it is covered through
// EMBSQL_state and EMBSQL_check.
//
// 30/10/2026 - RM - created
//==============================================================================

ctl-opt nomain;
ctl-opt bnddir('RMAPP');

/include 'QCPYSRC/RMAPP_D.rpgleinc'
/include 'QCPYSRC/RMEMBSQL_D.rpgleinc'
/include 'QCPYSRC/RMTOOLS_D.rpgleinc'
/include QINCLUDE,TESTCASE

// Host variables for the statements below. Declared here, in the main source,
// so the SQL precompiler sees them.
dcl-s g_one   int(10);
dcl-s g_short char(3);

//==============================================================================
// Helpers (not exported, and not named test*, so RPGUnit does not run them)
//==============================================================================

///
// Compare two text values, reporting both on failure.
///

dcl-proc assert_text;
  dcl-pi *n;
    expected  varchar(1024) const;
    actual    varchar(1024) const;
    name      varchar(64) const;
  end-pi;

  if expected <> actual;
    fail(name + ': expected [' + expected + '] got [' + actual + ']');
  endif;
end-proc;

// Each helper leaves the job's SQL diagnostics describing that one statement.
// They return straight away, so nothing else runs SQL before the state is read.

dcl-proc run_success;
  dcl-pi *n end-pi;

  exec sql VALUES 1 INTO :g_one;
end-proc;

dcl-proc run_not_found;
  dcl-pi *n end-pi;

  exec sql SELECT A INTO :g_one FROM (VALUES 1) AS T(A) WHERE A = 0;
end-proc;

dcl-proc run_warning;
  dcl-pi *n end-pi;

  // Truncating into a shorter host variable is a warning, not an error
  exec sql SELECT 'ABCDEFGH' INTO :g_short FROM (VALUES 1) AS T(A);
end-proc;

dcl-proc run_error;
  dcl-pi *n end-pi;

  exec sql SELECT 1 INTO :g_one FROM RMEMBSQL_NOSUCHTBL;
end-proc;

///
// A hand-built state, for testing the accessors without running SQL.
///

dcl-proc build_state;
  dcl-pi *n likeds(EMBSQL_state_t);
    sqlstate like(EMBSQL_sqlstate_t) const;
    sqlcode  like(EMBSQL_sqlcode_t) const;
    msg      like(EMBSQL_msg_t) const;
    error    like(BOOLEAN_t) const;
    found    like(BOOLEAN_t) const;
  end-pi;

  dcl-ds st likeds(EMBSQL_state_t) inz(*likeds);

  st.set = true;
  st.sqlstate = sqlstate;
  st.sqlcode = sqlcode;
  st.msg = msg;
  st.error = error;
  st.found = found;

  return st;
end-proc;

//==============================================================================
// Lifecycle
//==============================================================================

// The global state is cached until EMBSQL_inz, so reset it before every test
dcl-proc setUp export;
  dcl-pi *n extproc(*dclcase) end-pi;

  EMBSQL_inz();
end-proc;

//==============================================================================
// Accessors, given a state (pure functions, no SQL)
//==============================================================================

dcl-proc test_EMBSQL_error_given_state export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds failed likeds(EMBSQL_state_t) inz(*likeds);
  dcl-ds fine   likeds(EMBSQL_state_t) inz(*likeds);

  failed = build_state('42704': -204: 'not found': true: false);
  fine = build_state('00000': 0: '': false: true);

  assert(EMBSQL_error(failed): 'EMBSQL_error is off for a state with an error');
  assert(not EMBSQL_error(fine): 'EMBSQL_error is on for a state with no error');
end-proc;

dcl-proc test_EMBSQL_found_given_state export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds found    likeds(EMBSQL_state_t) inz(*likeds);
  dcl-ds notfound likeds(EMBSQL_state_t) inz(*likeds);

  found = build_state('00000': 0: '': false: true);
  notfound = build_state('02000': 100: '': false: false);

  assert(EMBSQL_found(found): 'EMBSQL_found is off for a found state');
  assert(not EMBSQL_found(notfound): 'EMBSQL_found is on for a not found state');
end-proc;

dcl-proc test_EMBSQL_msg_given_state export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds st likeds(EMBSQL_state_t) inz(*likeds);

  st = build_state('42704': -204: 'Table X not found': true: false);

  assert_text('Table X not found': EMBSQL_msg(st): 'msg');
end-proc;

dcl-proc test_EMBSQL_sqlstate_given_state export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds st likeds(EMBSQL_state_t) inz(*likeds);

  st = build_state('42704': -204: '': true: false);

  assert_text('42704': EMBSQL_sqlstate(st): 'sqlstate');
end-proc;

dcl-proc test_EMBSQL_sqlcode_given_state export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds st likeds(EMBSQL_state_t) inz(*likeds);

  st = build_state('42704': -204: '': true: false);

  iEqual(-204: EMBSQL_sqlcode(st): 'sqlcode');
end-proc;

// The explicit state is used as given, not combined with the global one
dcl-proc test_EMBSQL_accessors_ignore_global_when_given_state export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds st likeds(EMBSQL_state_t) inz(*likeds);

  run_success();
  st = build_state('42704': -204: '': true: false);

  assert(EMBSQL_error(st): 'Passed state error was ignored');
  assert_text('42704': EMBSQL_sqlstate(st): 'sqlstate');
end-proc;

//==============================================================================
// EMBSQL_state
//==============================================================================

dcl-proc test_EMBSQL_state_success export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds st likeds(EMBSQL_state_t) inz(*likeds);

  run_success();
  st = EMBSQL_state();

  assert(st.set: 'state.set is off');
  assert_text('00000': st.sqlstate: 'sqlstate');
  iEqual(0: st.sqlcode: 'sqlcode');
  assert(not st.error: 'state.error is on after a successful statement');
  assert(not st.diag: 'state.diag is on after a successful statement');
  assert(st.found: 'state.found is off after a successful statement');
end-proc;

dcl-proc test_EMBSQL_state_not_found export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds st likeds(EMBSQL_state_t) inz(*likeds);

  run_not_found();
  st = EMBSQL_state();

  assert_text('02000': st.sqlstate: 'sqlstate');
  iEqual(100: st.sqlcode: 'sqlcode');
  assert(not st.error: 'No rows found is not an error');
  assert(not st.diag: 'No rows found (02000/100) is not a diagnostic');
  assert(not st.found: 'state.found is on when no row was found');
end-proc;

// SQLSTATE class 01 is a warning: diagnostic, not an error, and still found
dcl-proc test_EMBSQL_state_warning export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds st likeds(EMBSQL_state_t) inz(*likeds);

  run_warning();
  st = EMBSQL_state();

  assert_text('01': %subst(st.sqlstate: 1: 2): 'sqlstate class');
  assert(st.diag: 'state.diag is off for a warning');
  assert(not st.error: 'A warning must not be reported as an error');
  assert(st.found: 'state.found is off for a warning');
end-proc;

// EMBSQL_state is documented as returning the state, not throwing: callers
// such as CUSDETDL read .error from it themselves.
dcl-proc test_EMBSQL_state_error_returns_state export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds st  likeds(EMBSQL_state_t) inz(*likeds);
  dcl-ds msg likeds(msgInfo_t) inz(*likeds);
  dcl-s raised like(BOOLEAN_t);

  run_error();

  raised = false;
  monitor;
    st = EMBSQL_state();
  on-error;
    raised = true;
    msg = getMonitoredMessage();
  endmon;

  assert(not raised: 'EMBSQL_state threw an escape message on an SQL error: '
                   + msg.id);

  assert(st.error: 'state.error is off for a failed statement');
  assert(not st.found: 'state.found is on for a failed statement');
  assert_text('42704': st.sqlstate: 'sqlstate');
  iEqual(-204: st.sqlcode: 'sqlcode');
  assert((%scan('RMEMBSQL_NOSUCHTBL': st.msg) > 0):
         'state.msg does not name the missing table');
end-proc;

//==============================================================================
// EMBSQL_check
//==============================================================================

dcl-proc test_EMBSQL_check_success export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds st likeds(EMBSQL_state_t) inz(*likeds);

  run_success();
  st = EMBSQL_check();

  assert_text('00000': st.sqlstate: 'sqlstate');
  assert(not st.error: 'state.error is on after a successful statement');
  assert(st.found: 'state.found is off after a successful statement');
end-proc;

dcl-proc test_EMBSQL_check_not_found_does_not_raise export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds st  likeds(EMBSQL_state_t) inz(*likeds);
  dcl-ds msg likeds(msgInfo_t) inz(*likeds);
  dcl-s raised like(BOOLEAN_t);

  run_not_found();

  raised = false;
  monitor;
    st = EMBSQL_check();
  on-error;
    raised = true;
    msg = getMonitoredMessage();
  endmon;

  assert(not raised: 'EMBSQL_check threw for "no rows found": ' + msg.id);
  assert(not st.found: 'state.found is on when no row was found');
end-proc;

// EMBSQL_check is documented as throwing an escape message on an error
dcl-proc test_EMBSQL_check_error_raises_escape export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds st  likeds(EMBSQL_state_t) inz(*likeds);
  dcl-ds msg likeds(msgInfo_t) inz(*likeds);
  dcl-s raised like(BOOLEAN_t);

  run_error();

  raised = false;
  monitor;
    st = EMBSQL_check();
  on-error;
    raised = true;
    msg = getMonitoredMessage();
  endmon;

  assert(raised: 'EMBSQL_check did not throw on an SQL error');
  assert_text('APP2901': msg.id: 'message id');
  assert((%scan('RMEMBSQL_NOSUCHTBL': msg.txt) > 0):
         'escape message does not name the missing table');
end-proc;

//==============================================================================
// Global state (no state passed)
//==============================================================================

dcl-proc test_EMBSQL_global_state_after_success export;
  dcl-pi *n extproc(*dclcase) end-pi;

  run_success();

  assert(not EMBSQL_error(): 'EMBSQL_error is on after a successful statement');
  assert(EMBSQL_found(): 'EMBSQL_found is off after a successful statement');
  assert_text('00000': EMBSQL_sqlstate(): 'sqlstate');
  iEqual(0: EMBSQL_sqlcode(): 'sqlcode');
end-proc;

dcl-proc test_EMBSQL_global_state_after_not_found export;
  dcl-pi *n extproc(*dclcase) end-pi;

  run_not_found();

  assert(not EMBSQL_error(): 'EMBSQL_error is on when no row was found');
  assert(not EMBSQL_found(): 'EMBSQL_found is on when no row was found');
  assert_text('02000': EMBSQL_sqlstate(): 'sqlstate');
  iEqual(100: EMBSQL_sqlcode(): 'sqlcode');
end-proc;

// "If previously set, since the last EMBSQL_inz() procedure call, then the
// previously set global SQL state is simply returned."
dcl-proc test_EMBSQL_global_state_is_cached_until_inz export;
  dcl-pi *n extproc(*dclcase) end-pi;

  run_success();
  assert(EMBSQL_found(): 'EMBSQL_found is off after a successful statement');

  // A later statement does not change the cached state ...
  run_not_found();
  assert(EMBSQL_found(): 'Cached state changed without EMBSQL_inz');
  assert_text('00000': EMBSQL_sqlstate(): 'cached sqlstate');

  // ... until it is reset, when the new statement is picked up
  EMBSQL_inz();
  assert(not EMBSQL_found(): 'EMBSQL_found is on after EMBSQL_inz and a miss');
  assert_text('02000': EMBSQL_sqlstate(): 'sqlstate after inz');
end-proc;
