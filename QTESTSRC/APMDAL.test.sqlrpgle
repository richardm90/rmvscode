**free

//==============================================================================
// APMDAL.test - Integration tests for APMDAL (Application Messages DAL)
//
// Object name is TAPMDAL (strip .test, prefix T).
//
// These are INTEGRATION tests: APMDAL runs embedded SQL against the APPMSGVP
// and APPMSGVL views, with no seam to substitute them. They run against the
// real APPMSG table in the library list.
//
// Module state. APMDAL keeps globals, and list/open return nothing unless the
// "first message" gate is open:
//   g_first_message = true   (initial)  => list/open return no rows
//   g_first_message = false             => rows with ID >= first_message_id
// APMDAL_add opens the gate (sets first_message_id to the first added ID).
// setUp resets the gate before every test.
//
// Isolation:
// - Every message the suite adds has a FIELD_NAME unique to this run, and is
//   registered for deletion as soon as it is added. tearDown deletes them and
//   closes the cursors, after every test including failed ones.
// - APMDAL_add always stamps the CURRENT JOB as JOB_NAME, so the messages are
//   scoped to this job. The delete_by_session_id test deletes every APPMSG row
//   for this job, which is only the suite's own rows unless something else in
//   the same job writes application messages.
//
// 30/10/2026 - RM - created
//==============================================================================

ctl-opt nomain;
ctl-opt bnddir('RMAPP');

/include 'QCPYSRC/PSDS_D.rpgleinc'
/include 'QCPYSRC/APMDAL_D.rpgleinc'
/include 'QCPYSRC/RMAPP_D.rpgleinc'
/include 'QCPYSRC/RMTOOLS_D.rpgleinc'
/include QINCLUDE,TESTCASE

//==============================================================================
// Suite state
//==============================================================================

dcl-c MAX_FIXTURES 10;

// Unique to this run: 'T' + hhmmss + hundredths = 9 chars, the 10th is the
// fixture sequence number (FIELD_NAME is char(10)).
dcl-s g_run_id char(9);
// Message ids created by the current test, deleted by tearDown
dcl-s g_created_ids like(INTEGER_t) dim(MAX_FIXTURES);
dcl-s g_created_count like(INTEGER_t) inz(0);
// Large, so held in static storage rather than on the stack of each test
dcl-ds g_list likeds(APMDAL_list_t) dim(APP_MAXIMUM_PAGE_ROWS) inz(*likeds);

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

///
// Register a message id for deletion in tearDown.
///

dcl-proc register_id;
  dcl-pi *n;
    id like(INTEGER_t) const;
  end-pi;

  if id <= 0;
    return;
  endif;
  if g_created_count >= MAX_FIXTURES;
    fail('Suite fixture limit of ' + %char(MAX_FIXTURES) + ' exceeded');
  endif;
  g_created_count += 1;
  g_created_ids(g_created_count) = id;
end-proc;

///
// The FIELD_NAME for fixture number seq.
///

dcl-proc field_name_for;
  dcl-pi *n like(FIELD_NAME_t);
    seq like(INTEGER_t) const;
  end-pi;

  return g_run_id + %char(seq);
end-proc;

///
// Add a message through APMDAL_add and register it for tearDown.
//
// Registration happens immediately after the add, before any assertion, so
// a failing test still cleans up.
///

dcl-proc add_message;
  dcl-pi *n likeds(APMDAL_t);
    seq  like(INTEGER_t) const;
    type like(APMDAL_type_t) const;
  end-pi;

  dcl-ds data likeds(APMDAL_t) inz(*likeds);
  dcl-s add_error like(BOOLEAN_t);

  data.FIELD_NAME = field_name_for(seq);
  data.TYPE = type;
  data.TEXT = 'RMTEST ' + g_run_id + ' message ' + %char(seq);

  add_error = APMDAL_add(data);
  register_id(data.ID);

  assert(not add_error: 'APMDAL_add reported an error for message '
                      + %char(seq));
  assert((data.ID > 0): 'APMDAL_add did not return an identity value');

  return data;
end-proc;

///
// Get a message back by id.
///

dcl-proc get_message;
  dcl-pi *n likeds(APMDAL_t);
    id like(INTEGER_t) const;
  end-pi;

  dcl-ds data likeds(APMDAL_t) inz(*likeds);

  data.ID = id;
  APMDAL_get(data);

  return data;
end-proc;

///
// Count the rows with the given FIELD_NAME straight from the table, not
// through APMDAL, so a fault in APMDAL cannot hide itself.
///

dcl-proc count_rows;
  dcl-pi *n like(INTEGER_t);
    field_name like(FIELD_NAME_t) const;
  end-pi;

  dcl-s h_field char(10);
  dcl-s h_count int(10);

  h_field = field_name;
  exec sql SELECT COUNT(*) INTO :h_count FROM APPMSGVP
           WHERE FIELD_NAME = :h_field;

  return h_count;
end-proc;

///
// A list selection for this job.
///

dcl-proc job_list_selection;
  dcl-pi *n likeds(APMDAL_list_selections_t) end-pi;

  dcl-ds sel likeds(APMDAL_list_selections_t) inz(*likeds);

  sel.JOB_NAME = APP_job_full_name();

  return sel;
end-proc;

///
// An open selection for this job and the given fixture's FIELD_NAME.
///

dcl-proc fixture_open_selection;
  dcl-pi *n likeds(APMDAL_open_selections_t);
    seq like(INTEGER_t) const;
  end-pi;

  dcl-ds sel likeds(APMDAL_open_selections_t) inz(*likeds);

  sel.JOB_NAME = APP_job_full_name();
  sel.FIELD_NAME = field_name_for(seq);

  return sel;
end-proc;

//==============================================================================
// Lifecycle
//==============================================================================

dcl-proc setUpSuite export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s now timestamp;

  now = %timestamp();
  g_run_id = 'T'
    + %editc(%dec(%subdt(now: *hours): 2: 0): 'X')
    + %editc(%dec(%subdt(now: *minutes): 2: 0): 'X')
    + %editc(%dec(%subdt(now: *seconds): 2: 0): 'X')
    + %editc(%dec(%subdt(now: *mseconds) / 10000: 2: 0): 'X');
end-proc;

// Close the gate so a test only sees what it adds itself
dcl-proc setUp export;
  dcl-pi *n extproc(*dclcase) end-pi;

  g_created_count = 0;
  APMDAL_first_message(true);
end-proc;

// Runs after every test, including failed ones, so nothing is leaked
dcl-proc tearDown export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds data likeds(APMDAL_t) inz(*likeds);
  dcl-s i like(INTEGER_t);

  // A test that failed part way through a fetch loop would otherwise leave a
  // cursor open and break every later open. Closing one that is not open is
  // harmless here.
  APMDAL_close();
  APMDAL_close_desc();

  for i = 1 to g_created_count;
    clear data;
    data.ID = g_created_ids(i);
    APMDAL_delete(data);
  endfor;

  g_created_count = 0;
  APMDAL_first_message(true);
end-proc;

//==============================================================================
// APMDAL_first_message / APMDAL_first_message_id
//==============================================================================

dcl-proc test_APMDAL_first_message_getter_and_setter export;
  dcl-pi *n extproc(*dclcase) end-pi;

  assert(APMDAL_first_message(): 'first_message is off after the reset in setUp');

  assert(not APMDAL_first_message(false): 'Setter did not return the new value');
  assert(not APMDAL_first_message(): 'first_message is not off after setting it');

  assert(APMDAL_first_message(true): 'Setter did not return the new value');
end-proc;

// Setting the first message id also opens the gate
dcl-proc test_APMDAL_first_message_id_setter_opens_gate export;
  dcl-pi *n extproc(*dclcase) end-pi;

  iEqual(42: APMDAL_first_message_id(42): 'setter return');
  iEqual(42: APMDAL_first_message_id(): 'getter');
  assert(not APMDAL_first_message(): 'Setting the id did not clear first_message');
end-proc;

//==============================================================================
// APMDAL_add
//==============================================================================

dcl-proc test_APMDAL_add_stores_the_message export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds added likeds(APMDAL_t) inz(*likeds);
  dcl-ds got   likeds(APMDAL_t) inz(*likeds);
  dcl-s before timestamp;
  dcl-s after  timestamp;

  before = %timestamp();
  added = add_message(1: 'I');
  after = %timestamp();

  got = get_message(added.ID);
  assert(APMDAL_found(): 'APMDAL_found is off after getting an added message');

  iEqual(added.ID: got.ID: 'ID');
  assert_text(APP_job_full_name(): got.JOB_NAME: 'JOB_NAME');
  assert_text(field_name_for(1): got.FIELD_NAME: 'FIELD_NAME');
  assert_text('I': got.TYPE: 'TYPE');
  assert_text('RMTEST ' + g_run_id + ' message 1': got.TEXT: 'TEXT');
  assert_text(%trimr(APP_user()): %trimr(got.CREATED_BY_USER):
              'CREATED_BY_USER');
  assert((got.CREATED_TIMESTAMP >= before and got.CREATED_TIMESTAMP <= after):
         'CREATED_TIMESTAMP ' + %char(got.CREATED_TIMESTAMP)
         + ' is outside the add call: ' + %char(before) + ' to '
         + %char(after));

  // Straight from the table: exactly one row was inserted
  iEqual(1: count_rows(field_name_for(1)): 'rows in APPMSG');
end-proc;

dcl-proc test_APMDAL_add_defaults_created_by_process export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds added likeds(APMDAL_t) inz(*likeds);
  dcl-ds got   likeds(APMDAL_t) inz(*likeds);

  added = add_message(1: 'I');
  got = get_message(added.ID);

  assert_text('*UNKNOWN': %trim(got.CREATED_BY_PROCESS): 'CREATED_BY_PROCESS');
end-proc;

dcl-proc test_APMDAL_add_keeps_created_by_process export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds data likeds(APMDAL_t) inz(*likeds);
  dcl-ds got  likeds(APMDAL_t) inz(*likeds);

  data.FIELD_NAME = field_name_for(1);
  data.TYPE = 'I';
  data.TEXT = 'RMTEST process';
  data.CREATED_BY_PROCESS = 'MYPROCESS';
  assert(not APMDAL_add(data): 'APMDAL_add reported an error');
  register_id(data.ID);

  got = get_message(data.ID);
  assert_text('MYPROCESS': %trim(got.CREATED_BY_PROCESS): 'CREATED_BY_PROCESS');
end-proc;

// The job name is always the current job, whatever the caller passes
dcl-proc test_APMDAL_add_ignores_passed_job_name export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds data likeds(APMDAL_t) inz(*likeds);
  dcl-ds got  likeds(APMDAL_t) inz(*likeds);

  data.JOB_NAME = '000000/NOBODY/NOJOB';
  data.FIELD_NAME = field_name_for(1);
  data.TYPE = 'I';
  data.TEXT = 'RMTEST job name';
  assert(not APMDAL_add(data): 'APMDAL_add reported an error');
  register_id(data.ID);

  got = get_message(data.ID);
  assert_text(APP_job_full_name(): got.JOB_NAME: 'JOB_NAME');
end-proc;

// The first add opens the gate at its own id; later adds leave the id alone
dcl-proc test_APMDAL_add_sets_first_message_id_once export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds first  likeds(APMDAL_t) inz(*likeds);
  dcl-ds second likeds(APMDAL_t) inz(*likeds);

  assert(APMDAL_first_message(): 'Gate is not closed before the first add');

  first = add_message(1: 'I');
  assert(not APMDAL_first_message(): 'First add did not open the gate');
  iEqual(first.ID: APMDAL_first_message_id(): 'first_message_id after first add');

  second = add_message(2: 'I');
  assert((second.ID > first.ID): 'Second ID is not greater than the first');
  iEqual(first.ID: APMDAL_first_message_id():
         'first_message_id after second add');
end-proc;

// Regression: CREATED_BY_PGM and CREATED_BY_PRC must name the caller of the
// message layer, so a message can be traced back to the code that raised it.
// They used to record RMAPP / RETRIEVE_CALLER for every row, because
// retrieve_caller (CALLER_P) skipped call stack entries from the old program
// names RMAPPMSG and RMEMBSQL, which are now modules of RMAPP, and so returned
// itself. It now skips the entries of the RMAPP service program.
//
// APMDAL_add is called directly from this procedure (not through a helper) so
// the expected caller is exactly this program and procedure.
dcl-proc test_APMDAL_add_records_the_caller export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds data likeds(APMDAL_t) inz(*likeds);
  dcl-ds got  likeds(APMDAL_t) inz(*likeds);

  data.FIELD_NAME = field_name_for(1);
  data.TYPE = 'I';
  data.TEXT = 'RMTEST caller';
  assert(not APMDAL_add(data): 'APMDAL_add reported an error');
  register_id(data.ID);

  got = get_message(data.ID);
  assert_text(%trim(psds.proc_pgm): %trim(got.CREATED_BY_PGM): 'CREATED_BY_PGM');
  assert_text('TEST_APMDAL_ADD_RECORDS_THE_CALLER': %upper(got.CREATED_BY_PRC):
              'CREATED_BY_PRC');
end-proc;

//==============================================================================
// APMDAL_get
//==============================================================================

// APMDAL_get returns the ERROR flag (unlike CUSDETDL_get, which returns found);
// whether a row was found is read with APMDAL_found.
dcl-proc test_APMDAL_get_not_found export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds data likeds(APMDAL_t) inz(*likeds);

  // Identity values start at 1, so -1 can never exist
  data.ID = -1;

  assert(not APMDAL_get(data): 'APMDAL_get reported an error for a missing row');
  assert(not APMDAL_found(): 'APMDAL_found is on for a missing row');
  assert(not APMDAL_error(): 'A get that finds nothing should not be an error');
end-proc;

//==============================================================================
// APMDAL_update
//==============================================================================

dcl-proc test_APMDAL_update export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds added likeds(APMDAL_t) inz(*likeds);
  dcl-ds before likeds(APMDAL_t) inz(*likeds);
  dcl-ds got   likeds(APMDAL_t) inz(*likeds);

  added = add_message(1: 'I');
  before = get_message(added.ID);

  added.TYPE = 'E';
  added.TEXT = 'RMTEST updated text';
  added.FIELD_NAME = field_name_for(2);

  assert(not APMDAL_update(added): 'APMDAL_update reported an error');

  got = get_message(added.ID);
  assert_text('E': got.TYPE: 'TYPE');
  assert_text('RMTEST updated text': got.TEXT: 'TEXT');
  assert_text(field_name_for(2): got.FIELD_NAME: 'FIELD_NAME');

  // The audit columns are not part of an update
  assert_text(before.CREATED_BY_USER: got.CREATED_BY_USER: 'CREATED_BY_USER');
  assert_text(%char(before.CREATED_TIMESTAMP): %char(got.CREATED_TIMESTAMP):
              'CREATED_TIMESTAMP');
  assert_text(before.CREATED_BY_PGM: got.CREATED_BY_PGM: 'CREATED_BY_PGM');
end-proc;

dcl-proc test_APMDAL_update_only_changes_target_row export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds first  likeds(APMDAL_t) inz(*likeds);
  dcl-ds second likeds(APMDAL_t) inz(*likeds);
  dcl-ds got    likeds(APMDAL_t) inz(*likeds);

  first = add_message(1: 'I');
  second = add_message(2: 'I');

  first.TEXT = 'RMTEST changed';
  assert(not APMDAL_update(first): 'APMDAL_update reported an error');

  got = get_message(second.ID);
  assert_text('RMTEST ' + g_run_id + ' message 2': got.TEXT: 'untouched TEXT');
end-proc;

//==============================================================================
// APMDAL_delete / APMDAL_delete_by_session_id
//==============================================================================

dcl-proc test_APMDAL_delete export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds added likeds(APMDAL_t) inz(*likeds);

  added = add_message(1: 'I');

  assert(not APMDAL_delete(added): 'APMDAL_delete reported an error');
  assert(APMDAL_found(): 'APMDAL_found is off after deleting a row');
  iEqual(0: count_rows(field_name_for(1)): 'rows in APPMSG after delete');

  // Deleting it again finds nothing, and that is not an error
  assert(not APMDAL_delete(added): 'Second delete reported an error');
  assert(not APMDAL_found(): 'APMDAL_found is on when nothing was deleted');
end-proc;

dcl-proc test_APMDAL_delete_only_removes_target_row export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds first  likeds(APMDAL_t) inz(*likeds);
  dcl-ds second likeds(APMDAL_t) inz(*likeds);

  first = add_message(1: 'I');
  second = add_message(2: 'I');

  assert(not APMDAL_delete(first): 'APMDAL_delete reported an error');

  iEqual(0: count_rows(field_name_for(1)): 'deleted row');
  iEqual(1: count_rows(field_name_for(2)): 'other row');
end-proc;

dcl-proc test_APMDAL_delete_by_session_id export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds criteria likeds(APMDAL_t) inz(*likeds);

  add_message(1: 'I');
  add_message(2: 'E');

  criteria.JOB_NAME = APP_job_full_name();
  assert(not APMDAL_delete_by_session_id(criteria):
         'APMDAL_delete_by_session_id reported an error');
  assert(APMDAL_found(): 'APMDAL_found is off after deleting rows');

  iEqual(0: count_rows(field_name_for(1)): 'first row');
  iEqual(0: count_rows(field_name_for(2)): 'second row');

  // Nothing left for this job
  assert(not APMDAL_delete_by_session_id(criteria):
         'Second delete reported an error');
  assert(not APMDAL_found(): 'APMDAL_found is on when nothing was deleted');
end-proc;

dcl-proc test_APMDAL_delete_by_session_id_other_job export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds criteria likeds(APMDAL_t) inz(*likeds);

  add_message(1: 'I');

  criteria.JOB_NAME = '000000/NOBODY/NOJOB';
  assert(not APMDAL_delete_by_session_id(criteria):
         'APMDAL_delete_by_session_id reported an error');
  assert(not APMDAL_found(): 'APMDAL_found is on when no row matched');

  iEqual(1: count_rows(field_name_for(1)): 'row for this job');
end-proc;

//==============================================================================
// APMDAL_list
//==============================================================================

// Newest first, and only this job's messages
dcl-proc test_APMDAL_list_newest_first export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(APMDAL_list_selections_t) inz(*likeds);
  dcl-ds m1   likeds(APMDAL_t) inz(*likeds);
  dcl-ds m2   likeds(APMDAL_t) inz(*likeds);
  dcl-ds m3   likeds(APMDAL_t) inz(*likeds);

  m1 = add_message(1: 'I');
  m2 = add_message(2: 'I');
  m3 = add_message(3: 'I');

  sel = job_list_selection();
  calc.req_page = 1;
  calc.req_page_rows = APP_DEFAULT_PAGE_ROWS;

  iEqual(3: APMDAL_list(calc: sel: g_list): 'got_rows');
  iEqual(3: calc.total_rows: 'total_rows');
  iEqual(1: calc.total_pages: 'total_pages');
  iEqual(m3.ID: g_list(1).ID: 'row 1 ID');
  iEqual(m2.ID: g_list(2).ID: 'row 2 ID');
  iEqual(m1.ID: g_list(3).ID: 'row 3 ID');
  assert_text(field_name_for(3): g_list(1).FIELD_NAME: 'row 1 FIELD_NAME');
  assert_text('RMTEST ' + g_run_id + ' message 3': g_list(1).TEXT: 'row 1 TEXT');
end-proc;

dcl-proc test_APMDAL_list_filter_by_type export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(APMDAL_list_selections_t) inz(*likeds);
  dcl-ds m2   likeds(APMDAL_t) inz(*likeds);

  add_message(1: 'I');
  m2 = add_message(2: 'E');
  add_message(3: 'I');

  sel = job_list_selection();
  sel.TYPE = 'E';
  calc.req_page = 1;
  calc.req_page_rows = APP_DEFAULT_PAGE_ROWS;

  iEqual(1: APMDAL_list(calc: sel: g_list): 'got_rows');
  iEqual(m2.ID: g_list(1).ID: 'row 1 ID');
  assert_text('E': g_list(1).TYPE: 'row 1 TYPE');
end-proc;

dcl-proc test_APMDAL_list_other_job_gets_nothing export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(APMDAL_list_selections_t) inz(*likeds);

  add_message(1: 'I');

  sel.JOB_NAME = '000000/NOBODY/NOJOB';
  calc.req_page = 1;
  calc.req_page_rows = APP_DEFAULT_PAGE_ROWS;

  iEqual(0: APMDAL_list(calc: sel: g_list): 'got_rows');
  iEqual(0: calc.total_rows: 'total_rows');
end-proc;

// While the gate is closed nothing is listed, even though rows exist
dcl-proc test_APMDAL_list_closed_gate_returns_nothing export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(APMDAL_list_selections_t) inz(*likeds);

  add_message(1: 'I');
  iEqual(1: count_rows(field_name_for(1)): 'row exists in APPMSG');

  APMDAL_first_message(true);

  sel = job_list_selection();
  calc.req_page = 1;
  calc.req_page_rows = APP_DEFAULT_PAGE_ROWS;

  iEqual(0: APMDAL_list(calc: sel: g_list): 'got_rows');
end-proc;

// Only messages from first_message_id onwards are listed
dcl-proc test_APMDAL_list_starts_at_first_message_id export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(APMDAL_list_selections_t) inz(*likeds);
  dcl-ds m2   likeds(APMDAL_t) inz(*likeds);
  dcl-ds m3   likeds(APMDAL_t) inz(*likeds);

  add_message(1: 'I');
  m2 = add_message(2: 'I');
  m3 = add_message(3: 'I');

  APMDAL_first_message_id(m2.ID);

  sel = job_list_selection();
  calc.req_page = 1;
  calc.req_page_rows = APP_DEFAULT_PAGE_ROWS;

  iEqual(2: APMDAL_list(calc: sel: g_list): 'got_rows');
  iEqual(m3.ID: g_list(1).ID: 'row 1 ID');
  iEqual(m2.ID: g_list(2).ID: 'row 2 ID');
end-proc;

dcl-proc test_APMDAL_list_paging export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(APMDAL_list_selections_t) inz(*likeds);
  dcl-ds m1   likeds(APMDAL_t) inz(*likeds);
  dcl-ds m2   likeds(APMDAL_t) inz(*likeds);
  dcl-ds m3   likeds(APMDAL_t) inz(*likeds);

  m1 = add_message(1: 'I');
  m2 = add_message(2: 'I');
  m3 = add_message(3: 'I');
  sel = job_list_selection();

  // Page 1 of 2: the two newest
  calc.req_page = 1;
  calc.req_page_rows = 2;
  iEqual(2: APMDAL_list(calc: sel: g_list): 'page 1 got_rows');
  iEqual(3: calc.total_rows: 'page 1 total_rows');
  iEqual(2: calc.total_pages: 'page 1 total_pages');
  iEqual(m3.ID: g_list(1).ID: 'page 1 row 1 ID');
  iEqual(m2.ID: g_list(2).ID: 'page 1 row 2 ID');

  // Page 2 of 2: the oldest
  clear calc;
  calc.req_page = 2;
  calc.req_page_rows = 2;
  iEqual(1: APMDAL_list(calc: sel: g_list): 'page 2 got_rows');
  iEqual(m1.ID: g_list(1).ID: 'page 2 row 1 ID');
end-proc;

//==============================================================================
// APMDAL_open / APMDAL_fetch / APMDAL_close (oldest first)
//==============================================================================

dcl-proc test_APMDAL_open_fetch_close export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds sel  likeds(APMDAL_open_selections_t) inz(*likeds);
  dcl-ds m1   likeds(APMDAL_t) inz(*likeds);
  dcl-ds m2   likeds(APMDAL_t) inz(*likeds);
  dcl-ds m3   likeds(APMDAL_t) inz(*likeds);
  dcl-ds row  likeds(APMDAL_t) inz(*likeds);

  m1 = add_message(1: 'I');
  m2 = add_message(2: 'E');
  m3 = add_message(3: 'D');

  sel.JOB_NAME = APP_job_full_name();
  assert(not APMDAL_open(sel): 'APMDAL_open reported an error');

  assert(APMDAL_fetch(row): 'First fetch found nothing');
  iEqual(m1.ID: row.ID: 'fetch 1 ID');
  assert(APMDAL_fetch(row): 'Second fetch found nothing');
  iEqual(m2.ID: row.ID: 'fetch 2 ID');
  assert(APMDAL_fetch(row): 'Third fetch found nothing');
  iEqual(m3.ID: row.ID: 'fetch 3 ID');

  assert(not APMDAL_fetch(row): 'Fetch past the last row still found a row');
  assert(not APMDAL_error(): 'Fetching past the end should not be an error');

  assert(not APMDAL_close(): 'APMDAL_close reported an error');
end-proc;

dcl-proc test_APMDAL_open_filter_by_field_name export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds sel  likeds(APMDAL_open_selections_t) inz(*likeds);
  dcl-ds m2   likeds(APMDAL_t) inz(*likeds);
  dcl-ds row  likeds(APMDAL_t) inz(*likeds);

  add_message(1: 'I');
  m2 = add_message(2: 'I');
  add_message(3: 'I');

  sel = fixture_open_selection(2);
  assert(not APMDAL_open(sel): 'APMDAL_open reported an error');

  assert(APMDAL_fetch(row): 'Fetch found nothing');
  iEqual(m2.ID: row.ID: 'fetch 1 ID');
  assert(not APMDAL_fetch(row): 'More than one row matched the FIELD_NAME');

  APMDAL_close();
end-proc;

dcl-proc test_APMDAL_open_filter_by_type export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds sel  likeds(APMDAL_open_selections_t) inz(*likeds);
  dcl-ds m1   likeds(APMDAL_t) inz(*likeds);
  dcl-ds m3   likeds(APMDAL_t) inz(*likeds);
  dcl-ds row  likeds(APMDAL_t) inz(*likeds);

  m1 = add_message(1: 'I');
  add_message(2: 'E');
  m3 = add_message(3: 'I');

  sel.JOB_NAME = APP_job_full_name();
  sel.TYPE = 'I';
  assert(not APMDAL_open(sel): 'APMDAL_open reported an error');

  assert(APMDAL_fetch(row): 'First fetch found nothing');
  iEqual(m1.ID: row.ID: 'fetch 1 ID');
  assert(APMDAL_fetch(row): 'Second fetch found nothing');
  iEqual(m3.ID: row.ID: 'fetch 2 ID');
  assert(not APMDAL_fetch(row): 'The E message was not filtered out');

  APMDAL_close();
end-proc;

dcl-proc test_APMDAL_open_closed_gate_returns_nothing export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds sel  likeds(APMDAL_open_selections_t) inz(*likeds);
  dcl-ds row  likeds(APMDAL_t) inz(*likeds);

  add_message(1: 'I');
  APMDAL_first_message(true);

  sel.JOB_NAME = APP_job_full_name();
  assert(not APMDAL_open(sel): 'APMDAL_open reported an error');
  assert(not APMDAL_fetch(row): 'A row was fetched with the gate closed');

  APMDAL_close();
end-proc;

//==============================================================================
// APMDAL_open_desc / APMDAL_fetch_desc / APMDAL_close_desc (newest first)
//==============================================================================

dcl-proc test_APMDAL_open_desc_fetch_desc_close_desc export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds sel  likeds(APMDAL_open_selections_t) inz(*likeds);
  dcl-ds m1   likeds(APMDAL_t) inz(*likeds);
  dcl-ds m2   likeds(APMDAL_t) inz(*likeds);
  dcl-ds m3   likeds(APMDAL_t) inz(*likeds);
  dcl-ds row  likeds(APMDAL_t) inz(*likeds);

  m1 = add_message(1: 'I');
  m2 = add_message(2: 'E');
  m3 = add_message(3: 'D');

  sel.JOB_NAME = APP_job_full_name();
  assert(not APMDAL_open_desc(sel): 'APMDAL_open_desc reported an error');

  assert(APMDAL_fetch_desc(row): 'First fetch found nothing');
  iEqual(m3.ID: row.ID: 'fetch 1 ID');
  assert(APMDAL_fetch_desc(row): 'Second fetch found nothing');
  iEqual(m2.ID: row.ID: 'fetch 2 ID');
  assert(APMDAL_fetch_desc(row): 'Third fetch found nothing');
  iEqual(m1.ID: row.ID: 'fetch 3 ID');

  assert(not APMDAL_fetch_desc(row): 'Fetch past the last row still found one');
  assert(not APMDAL_error(): 'Fetching past the end should not be an error');

  assert(not APMDAL_close_desc(): 'APMDAL_close_desc reported an error');
end-proc;

dcl-proc test_APMDAL_open_desc_filter_by_type export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds sel  likeds(APMDAL_open_selections_t) inz(*likeds);
  dcl-ds m2   likeds(APMDAL_t) inz(*likeds);
  dcl-ds row  likeds(APMDAL_t) inz(*likeds);

  add_message(1: 'I');
  m2 = add_message(2: 'E');

  sel.JOB_NAME = APP_job_full_name();
  sel.TYPE = 'E';
  assert(not APMDAL_open_desc(sel): 'APMDAL_open_desc reported an error');

  assert(APMDAL_fetch_desc(row): 'Fetch found nothing');
  iEqual(m2.ID: row.ID: 'fetch 1 ID');
  assert(not APMDAL_fetch_desc(row): 'The I message was not filtered out');

  APMDAL_close_desc();
end-proc;
