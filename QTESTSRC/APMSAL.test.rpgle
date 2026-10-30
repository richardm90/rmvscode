**free

//==============================================================================
// APMSAL.test - Integration tests for APMSAL (Application Messages SAL)
//
// Object name is TAPMSAL (strip .test, prefix T).
//
// These are INTEGRATION tests: APMSAL is a thin service layer over APMDAL, which
// runs embedded SQL against the APPMSG table, with no seam to substitute it.
// They run against the real APPMSG table in the library list.
//
// Module state. APMSAL keeps message counters, and APMDAL keeps a "first
// message" gate that closes list/open until a message has been added.
// setUp calls APMSAL_inz, which zeroes the counters and closes the gate, so
// each test sees only the messages it adds itself.
//
// Isolation:
// - Every message the suite adds has a TEXT and FIELD_NAME unique to this run,
//   and is registered for deletion as soon as it is added. tearDown deletes
//   them and closes the cursors, after every test including failed ones.
// - APMSAL_open and APMSAL_open_desc can select on JOB_NAME and TYPE only (the
//   FIELD_NAME on the APMDAL selections is not exposed by this layer).
//
// 30/10/2026 - RM - created
//==============================================================================

ctl-opt nomain;
ctl-opt bnddir('RMAPP');

/include 'QCPYSRC/PSDS_D.rpgleinc'
/include 'QCPYSRC/APMDAL_D.rpgleinc'
/include 'QCPYSRC/APMSAL_D.rpgleinc'
/include 'QCPYSRC/RMAPP_D.rpgleinc'
/include 'QCPYSRC/RMTOOLS_D.rpgleinc'
/include QINCLUDE,TESTCASE

//==============================================================================
// Suite state
//==============================================================================

// Unique to this run: 'T' + hhmmss + hundredths = 9 chars, the 10th is the
// fixture sequence number (FIELD_NAME is char(10)).
dcl-s g_run_id char(9);
// Message ids created by the current test, deleted by tearDown
dcl-c MAX_FIXTURES 10;
dcl-s g_created_ids like(INTEGER_t) dim(MAX_FIXTURES);
dcl-s g_created_count like(INTEGER_t) inz(0);
// Large, so held in static storage rather than on the stack of each test
dcl-ds g_list likeds(APMSAL_list_t) dim(APP_MAXIMUM_PAGE_ROWS) inz(*likeds);

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
// The FIELD_NAME for fixture number seq.
///

dcl-proc field_name_for;
  dcl-pi *n like(FIELD_NAME_t);
    seq like(INTEGER_t) const;
  end-pi;

  return g_run_id + %char(seq);
end-proc;

///
// The TEXT for fixture number seq.
///

dcl-proc text_for;
  dcl-pi *n like(APMSAL_text_t);
    seq like(INTEGER_t) const;
  end-pi;

  return 'RMTEST ' + g_run_id + ' message ' + %char(seq);
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
// Add fixture number seq of the given type through APMSAL_log, and register
// it for tearDown. Returns the message id.
//
// Registration happens immediately after the add, before any assertion, so
// a failing test still cleans up.
///

dcl-proc add_message;
  dcl-pi *n like(INTEGER_t);
    seq  like(INTEGER_t) const;
    type like(APMSAL_type_t) const;
  end-pi;

  dcl-s id like(INTEGER_t);
  dcl-s add_error like(BOOLEAN_t);

  add_error = APMSAL_log(text_for(seq): type: field_name_for(seq): '': id);
  register_id(id);

  assert(not add_error: 'APMSAL_log reported an error for message '
                      + %char(seq));
  assert((id > 0): 'APMSAL_log did not return an identity value');

  return id;
end-proc;

///
// Get a message back by id.
///

dcl-proc get_message;
  dcl-pi *n likeds(APMSAL_t);
    id like(INTEGER_t) const;
  end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);

  service.ID = id;
  assert(not APMSAL_get(service): 'APMSAL_get reported an error');
  assert(APMDAL_found(): 'Message ' + %char(id) + ' was not found');

  return service;
end-proc;

///
// The newest message of the given type (blank for any type) for this job.
///

dcl-proc newest;
  dcl-pi *n likeds(APMSAL_t);
    type like(APMSAL_type_t) const;
  end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);

  service.TYPE = type;
  assert(APMSAL_fetch_last(service): 'APMSAL_fetch_last found no message');

  return service;
end-proc;

///
// Check all five message flags in one go: any, diagnostic, information,
// warning, error.
///

dcl-proc assert_flags;
  dcl-pi *n;
    any_msg like(BOOLEAN_t) const;
    diag    like(BOOLEAN_t) const;
    info    like(BOOLEAN_t) const;
    warn    like(BOOLEAN_t) const;
    err     like(BOOLEAN_t) const;
  end-pi;

  assert(APMSAL_msg() = any_msg: 'APMSAL_msg should be ' + %char(any_msg));
  assert(APMSAL_diagnostic() = diag:
         'APMSAL_diagnostic should be ' + %char(diag));
  assert(APMSAL_information() = info:
         'APMSAL_information should be ' + %char(info));
  assert(APMSAL_warning() = warn: 'APMSAL_warning should be ' + %char(warn));
  assert(APMSAL_error() = err: 'APMSAL_error should be ' + %char(err));
end-proc;

///
// A list selection for this job and the given type (blank for any type).
///

dcl-proc job_list_selection;
  dcl-pi *n likeds(APMSAL_list_selections_t);
    type like(APMSAL_type_t) const;
  end-pi;

  dcl-ds sel likeds(APMSAL_list_selections_t) inz(*likeds);

  sel.JOB_NAME = APP_job_full_name();
  sel.TYPE = type;

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

// Zero the counters and close the gate so a test only sees what it adds itself
dcl-proc setUp export;
  dcl-pi *n extproc(*dclcase) end-pi;

  g_created_count = 0;
  APMSAL_inz();
end-proc;

// Runs after every test, including failed ones, so nothing is leaked
dcl-proc tearDown export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds data likeds(APMDAL_t) inz(*likeds);
  dcl-s i like(INTEGER_t);

  // A test that failed part way through a fetch loop would otherwise leave a
  // cursor open and break every later open. Closing one that is not open is
  // harmless here.
  APMSAL_close();
  APMSAL_close_desc();

  for i = 1 to g_created_count;
    clear data;
    data.ID = g_created_ids(i);
    APMDAL_delete(data);
  endfor;

  g_created_count = 0;
  APMSAL_inz();
end-proc;

//==============================================================================
// APMSAL_inz
//==============================================================================

dcl-proc test_APMSAL_inz_zeroes_the_message_flags export;
  dcl-pi *n extproc(*dclcase) end-pi;

  add_message(1: 'D');
  add_message(2: 'I');
  add_message(3: 'W');
  add_message(4: 'E');
  assert_flags(true: true: true: true: true);

  APMSAL_inz();

  assert_flags(false: false: false: false: false);
end-proc;

// The messages stay in the table, but are no longer part of the process
dcl-proc test_APMSAL_inz_closes_the_gate export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);

  add_message(1: 'I');
  assert(not APMSAL_open(): 'APMSAL_open reported an error');
  assert(APMSAL_fetch(service): 'The added message was not fetched');
  APMSAL_close();

  APMSAL_inz();

  assert(not APMSAL_open(): 'APMSAL_open reported an error after APMSAL_inz');
  assert(not APMSAL_fetch(service): 'A message was fetched after APMSAL_inz');
  APMSAL_close();
end-proc;

dcl-proc test_APMSAL_inz_sets_the_default_process export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);

  APMSAL_inz('MYPROCESS');
  add_message(1: 'I');

  service = newest('');
  assert_text('MYPROCESS': %trim(service.CREATED_BY_PROCESS):
              'CREATED_BY_PROCESS');
end-proc;

// A blank process is the same as none, and re-initialising forgets the old one
dcl-proc test_APMSAL_inz_blank_process_is_unknown export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);

  APMSAL_inz('MYPROCESS');
  APMSAL_inz('');
  add_message(1: 'I');

  service = newest('');
  assert_text('*UNKNOWN': %trim(service.CREATED_BY_PROCESS):
              'CREATED_BY_PROCESS after a blank process');

  APMSAL_inz('MYPROCESS');
  APMSAL_inz();
  add_message(2: 'I');

  service = newest('');
  assert_text('*UNKNOWN': %trim(service.CREATED_BY_PROCESS):
              'CREATED_BY_PROCESS after no process');
end-proc;

//==============================================================================
// APMSAL_msg / _diagnostic / _information / _warning / _error
//==============================================================================

dcl-proc test_APMSAL_flags_start_off export;
  dcl-pi *n extproc(*dclcase) end-pi;

  assert_flags(false: false: false: false: false);
end-proc;

dcl-proc test_APMSAL_flags_diagnostic export;
  dcl-pi *n extproc(*dclcase) end-pi;

  add_message(1: APMSAL_TYPE_DIAGNOSTIC);
  assert_flags(true: true: false: false: false);
end-proc;

dcl-proc test_APMSAL_flags_information export;
  dcl-pi *n extproc(*dclcase) end-pi;

  add_message(1: APMSAL_TYPE_INFORMATION);
  assert_flags(true: false: true: false: false);
end-proc;

dcl-proc test_APMSAL_flags_warning export;
  dcl-pi *n extproc(*dclcase) end-pi;

  add_message(1: APMSAL_TYPE_WARNING);
  assert_flags(true: false: false: true: false);
end-proc;

dcl-proc test_APMSAL_flags_error export;
  dcl-pi *n extproc(*dclcase) end-pi;

  add_message(1: APMSAL_TYPE_ERROR);
  assert_flags(true: false: false: false: true);
end-proc;

dcl-proc test_APMSAL_flags_accumulate export;
  dcl-pi *n extproc(*dclcase) end-pi;

  add_message(1: APMSAL_TYPE_INFORMATION);
  assert_flags(true: false: true: false: false);

  add_message(2: APMSAL_TYPE_ERROR);
  assert_flags(true: false: true: false: true);

  // Adding a second message of a type already seen changes nothing
  add_message(3: APMSAL_TYPE_ERROR);
  assert_flags(true: false: true: false: true);
end-proc;

//==============================================================================
// APMSAL_add
//==============================================================================

dcl-proc test_APMSAL_add_stores_the_message export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);
  dcl-ds got     likeds(APMSAL_t) inz(*likeds);
  dcl-s before timestamp;
  dcl-s after  timestamp;

  service.TEXT = text_for(1);
  service.TYPE = 'W';
  service.FIELD_NAME = field_name_for(1);

  before = %timestamp();
  assert(not APMSAL_add(service): 'APMSAL_add reported an error');
  after = %timestamp();
  register_id(service.ID);

  // The structure comes back with the identity and the audit fields
  assert((service.ID > 0): 'APMSAL_add did not return an identity value');
  assert_text(APP_job_full_name(): service.JOB_NAME: 'returned JOB_NAME');
  assert_text(%trimr(APP_user()): %trimr(service.CREATED_BY_USER):
              'returned CREATED_BY_USER');
  assert((service.CREATED_TIMESTAMP >= before
          and service.CREATED_TIMESTAMP <= after):
         'CREATED_TIMESTAMP ' + %char(service.CREATED_TIMESTAMP)
         + ' is outside the add call: ' + %char(before) + ' to '
         + %char(after));

  // And what was stored matches
  got = get_message(service.ID);
  assert_text(APP_job_full_name(): got.JOB_NAME: 'JOB_NAME');
  assert_text(field_name_for(1): got.FIELD_NAME: 'FIELD_NAME');
  assert_text('W': got.TYPE: 'TYPE');
  assert_text(text_for(1): got.TEXT: 'TEXT');
  assert_text(%trimr(APP_user()): %trimr(got.CREATED_BY_USER):
              'CREATED_BY_USER');
end-proc;

// Left alone, the structure holds an information message with no field name
// and no process
dcl-proc test_APMSAL_add_structure_defaults export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);
  dcl-ds got     likeds(APMSAL_t) inz(*likeds);

  service.TEXT = text_for(1);
  assert(not APMSAL_add(service): 'APMSAL_add reported an error');
  register_id(service.ID);

  got = get_message(service.ID);
  assert_text(APMSAL_TYPE_INFORMATION: got.TYPE: 'TYPE');
  assert_text(APMSAL_FIELD_NAME_NONE: %trim(got.FIELD_NAME): 'FIELD_NAME');
  assert_text('*UNKNOWN': %trim(got.CREATED_BY_PROCESS): 'CREATED_BY_PROCESS');
  assert(APMSAL_information(): 'APMSAL_information is off');
end-proc;

// The job name is always the current job, whatever the caller passes
dcl-proc test_APMSAL_add_ignores_passed_job_name export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);
  dcl-ds got     likeds(APMSAL_t) inz(*likeds);

  service.JOB_NAME = '000000/NOBODY/NOJOB';
  service.TEXT = text_for(1);
  assert(not APMSAL_add(service): 'APMSAL_add reported an error');
  register_id(service.ID);

  got = get_message(service.ID);
  assert_text(APP_job_full_name(): got.JOB_NAME: 'JOB_NAME');
end-proc;

dcl-proc test_APMSAL_add_keeps_created_by_process export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);
  dcl-ds got     likeds(APMSAL_t) inz(*likeds);

  APMSAL_inz('INZPROCESS');
  service.TEXT = text_for(1);
  service.CREATED_BY_PROCESS = 'MYPROCESS';
  assert(not APMSAL_add(service): 'APMSAL_add reported an error');
  register_id(service.ID);

  got = get_message(service.ID);
  assert_text('MYPROCESS': %trim(got.CREATED_BY_PROCESS): 'CREATED_BY_PROCESS');
end-proc;

// A blank process falls back to the one given to APMSAL_inz
dcl-proc test_APMSAL_add_blank_process_uses_inz_process export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);
  dcl-ds got     likeds(APMSAL_t) inz(*likeds);

  APMSAL_inz('INZPROCESS');
  service.TEXT = text_for(1);
  assert(not APMSAL_add(service): 'APMSAL_add reported an error');
  register_id(service.ID);

  got = get_message(service.ID);
  assert_text('INZPROCESS': %trim(got.CREATED_BY_PROCESS): 'CREATED_BY_PROCESS');
end-proc;

// Regression companion to test_APMDAL_add_records_the_caller: the message must
// name this test as its origin, not the message layers underneath it.
// APMSAL_add is called directly from this procedure so the expected caller is
// exact.
dcl-proc test_APMSAL_add_records_the_caller export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);
  dcl-ds got     likeds(APMSAL_t) inz(*likeds);

  service.TEXT = text_for(1);
  assert(not APMSAL_add(service): 'APMSAL_add reported an error');
  register_id(service.ID);

  got = get_message(service.ID);
  assert_text(%trim(psds.proc_pgm): %trim(got.CREATED_BY_PGM): 'CREATED_BY_PGM');
  assert_text('TEST_APMSAL_ADD_RECORDS_THE_CALLER': %upper(got.CREATED_BY_PRC):
              'CREATED_BY_PRC');
end-proc;

//==============================================================================
// APMSAL_log
//==============================================================================

dcl-proc test_APMSAL_log_stores_the_message export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds got likeds(APMSAL_t) inz(*likeds);
  dcl-s id like(INTEGER_t);
  dcl-s log_error like(BOOLEAN_t);
  dcl-s before timestamp;
  dcl-s after  timestamp;

  before = %timestamp();
  log_error = APMSAL_log(text_for(1): 'W': field_name_for(1): 'MYPROCESS': id);
  after = %timestamp();
  register_id(id);

  assert(not log_error: 'APMSAL_log reported an error');
  assert((id > 0): 'APMSAL_log did not return an identity value');

  got = get_message(id);
  iEqual(id: got.ID: 'ID');
  assert_text(APP_job_full_name(): got.JOB_NAME: 'JOB_NAME');
  assert_text(field_name_for(1): got.FIELD_NAME: 'FIELD_NAME');
  assert_text('W': got.TYPE: 'TYPE');
  assert_text(text_for(1): got.TEXT: 'TEXT');
  assert_text('MYPROCESS': %trim(got.CREATED_BY_PROCESS): 'CREATED_BY_PROCESS');
  assert((got.CREATED_TIMESTAMP >= before and got.CREATED_TIMESTAMP <= after):
         'CREATED_TIMESTAMP ' + %char(got.CREATED_TIMESTAMP)
         + ' is outside the call: ' + %char(before) + ' to ' + %char(after));
  assert(APMSAL_warning(): 'APMSAL_warning is off');
end-proc;

// Only the text is required
dcl-proc test_APMSAL_log_text_only_is_information export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds got likeds(APMSAL_t) inz(*likeds);

  assert(not APMSAL_log(text_for(1)): 'APMSAL_log reported an error');

  // No id comes back from this call, so find the message as the newest one
  got = newest('');
  register_id(got.ID);
  assert_text(text_for(1): got.TEXT: 'TEXT');
  assert_text(APMSAL_TYPE_INFORMATION: got.TYPE: 'TYPE');
  assert_text(APMSAL_FIELD_NAME_NONE: %trim(got.FIELD_NAME): 'FIELD_NAME');
  assert(APMSAL_information(): 'APMSAL_information is off for the default type');
end-proc;

dcl-proc test_APMSAL_log_blank_field_name_is_none export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds got likeds(APMSAL_t) inz(*likeds);

  assert(not APMSAL_log(text_for(1): 'I': ''): 'APMSAL_log reported an error');

  got = newest('');
  register_id(got.ID);
  assert_text(APMSAL_FIELD_NAME_NONE: %trim(got.FIELD_NAME): 'FIELD_NAME');
end-proc;

// A blank process falls back to the one given to APMSAL_inz
dcl-proc test_APMSAL_log_blank_process_uses_inz_process export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds got likeds(APMSAL_t) inz(*likeds);

  APMSAL_inz('INZPROCESS');
  assert(not APMSAL_log(text_for(1): 'I': field_name_for(1): ''):
         'APMSAL_log reported an error');

  got = newest('');
  register_id(got.ID);
  assert_text('INZPROCESS': %trim(got.CREATED_BY_PROCESS): 'CREATED_BY_PROCESS');
end-proc;

// The id is optional: *omit is accepted and the message is still logged
dcl-proc test_APMSAL_log_id_can_be_omitted export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds got likeds(APMSAL_t) inz(*likeds);

  assert(not APMSAL_log(text_for(1): 'I': field_name_for(1): '': *omit):
         'APMSAL_log reported an error');

  got = newest('');
  register_id(got.ID);
  assert_text(text_for(1): got.TEXT: 'TEXT');
end-proc;

// Each call returns the id of its own message
dcl-proc test_APMSAL_log_ids_differ export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s first  like(INTEGER_t);
  dcl-s second like(INTEGER_t);

  first = add_message(1: 'I');
  second = add_message(2: 'I');

  assert((second > first): 'Second ID ' + %char(second)
                         + ' is not greater than the first ' + %char(first));
end-proc;

// Regression companion to test_APMSAL_add_records_the_caller: the extra layer
// between this procedure and APMDAL must not show as the origin.
dcl-proc test_APMSAL_log_records_the_caller export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds got likeds(APMSAL_t) inz(*likeds);
  dcl-s id like(INTEGER_t);

  assert(not APMSAL_log(text_for(1): 'I': field_name_for(1): '': id):
         'APMSAL_log reported an error');
  register_id(id);

  got = get_message(id);
  assert_text(%trim(psds.proc_pgm): %trim(got.CREATED_BY_PGM): 'CREATED_BY_PGM');
  assert_text('TEST_APMSAL_LOG_RECORDS_THE_CALLER': %upper(got.CREATED_BY_PRC):
              'CREATED_BY_PRC');
end-proc;

//==============================================================================
// APMSAL_get
//==============================================================================

dcl-proc test_APMSAL_get export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds added likeds(APMSAL_t) inz(*likeds);
  dcl-ds got   likeds(APMSAL_t) inz(*likeds);

  add_message(1: 'E');
  added = newest('');

  got.ID = added.ID;
  assert(not APMSAL_get(got): 'APMSAL_get reported an error');
  assert(APMDAL_found(): 'APMDAL_found is off after getting an added message');
  assert_text(text_for(1): got.TEXT: 'TEXT');
  assert_text('E': got.TYPE: 'TYPE');
  assert_text(field_name_for(1): got.FIELD_NAME: 'FIELD_NAME');
end-proc;

dcl-proc test_APMSAL_get_not_found export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds got likeds(APMSAL_t) inz(*likeds);

  // Identity values start at 1, so -1 can never exist
  got.ID = -1;

  assert(not APMSAL_get(got): 'APMSAL_get reported an error for a missing row');
  assert(not APMDAL_found(): 'APMDAL_found is on for a missing row');
end-proc;

//==============================================================================
// APMSAL_update
//==============================================================================

dcl-proc test_APMSAL_update export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);
  dcl-ds got     likeds(APMSAL_t) inz(*likeds);

  add_message(1: 'I');
  service = newest('');

  service.TEXT = text_for(2);
  service.TYPE = 'W';
  service.FIELD_NAME = field_name_for(2);
  assert(not APMSAL_update(service): 'APMSAL_update reported an error');

  got.ID = service.ID;
  assert(not APMSAL_get(got): 'APMSAL_get reported an error');
  assert_text(text_for(2): got.TEXT: 'TEXT');
  assert_text('W': got.TYPE: 'TYPE');
  assert_text(field_name_for(2): got.FIELD_NAME: 'FIELD_NAME');
end-proc;

// The job name is always the current job, whatever the caller passes
dcl-proc test_APMSAL_update_uses_the_current_job export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);
  dcl-ds got     likeds(APMSAL_t) inz(*likeds);

  add_message(1: 'I');
  service = newest('');

  service.JOB_NAME = '000000/NOBODY/NOJOB';
  service.TEXT = text_for(2);
  assert(not APMSAL_update(service): 'APMSAL_update reported an error');
  assert_text(APP_job_full_name(): service.JOB_NAME: 'returned JOB_NAME');

  got.ID = service.ID;
  assert(not APMSAL_get(got): 'APMSAL_get reported an error');
  assert_text(APP_job_full_name(): got.JOB_NAME: 'stored JOB_NAME');
  assert_text(text_for(2): got.TEXT: 'TEXT');
end-proc;

//==============================================================================
// APMSAL_delete
//==============================================================================

dcl-proc test_APMSAL_delete export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);
  dcl-ds got     likeds(APMSAL_t) inz(*likeds);

  add_message(1: 'I');
  service = newest('');

  assert(not APMSAL_delete(service): 'APMSAL_delete reported an error');
  assert(APMDAL_found(): 'APMDAL_found is off after deleting a row');

  got.ID = service.ID;
  assert(not APMSAL_get(got): 'APMSAL_get reported an error');
  assert(not APMDAL_found(): 'The message is still there after the delete');
end-proc;

dcl-proc test_APMSAL_delete_only_removes_target_row export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds first  likeds(APMSAL_t) inz(*likeds);
  dcl-ds second likeds(APMSAL_t) inz(*likeds);
  dcl-ds got    likeds(APMSAL_t) inz(*likeds);

  add_message(1: 'I');
  first = newest('');
  add_message(2: 'I');
  second = newest('');

  assert(not APMSAL_delete(first): 'APMSAL_delete reported an error');

  got.ID = second.ID;
  assert(not APMSAL_get(got): 'APMSAL_get reported an error');
  assert(APMDAL_found(): 'The other message was deleted too');
  assert_text(text_for(2): got.TEXT: 'TEXT');
end-proc;

//==============================================================================
// APMSAL_list
//==============================================================================

// Newest first, and only this job's messages
dcl-proc test_APMSAL_list_newest_first export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(APMSAL_list_selections_t) inz(*likeds);

  add_message(1: 'I');
  add_message(2: 'I');
  add_message(3: 'I');

  sel = job_list_selection('I');
  calc.req_page = 1;
  calc.req_page_rows = APP_DEFAULT_PAGE_ROWS;

  iEqual(3: APMSAL_list(calc: sel: g_list): 'got_rows');
  iEqual(3: calc.total_rows: 'total_rows');
  assert_text(text_for(3): g_list(1).TEXT: 'row 1 TEXT');
  assert_text(text_for(2): g_list(2).TEXT: 'row 2 TEXT');
  assert_text(text_for(1): g_list(3).TEXT: 'row 3 TEXT');
  assert_text(field_name_for(3): g_list(1).FIELD_NAME: 'row 1 FIELD_NAME');
  assert_text(APP_job_full_name(): g_list(1).JOB_NAME: 'row 1 JOB_NAME');
end-proc;

dcl-proc test_APMSAL_list_filter_by_type export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(APMSAL_list_selections_t) inz(*likeds);

  add_message(1: 'I');
  add_message(2: 'E');
  add_message(3: 'I');

  sel = job_list_selection('E');
  calc.req_page = 1;
  calc.req_page_rows = APP_DEFAULT_PAGE_ROWS;

  iEqual(1: APMSAL_list(calc: sel: g_list): 'got_rows');
  assert_text(text_for(2): g_list(1).TEXT: 'row 1 TEXT');
  assert_text('E': g_list(1).TYPE: 'row 1 TYPE');
end-proc;

// A blank type selects every type
dcl-proc test_APMSAL_list_blank_type_lists_all export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(APMSAL_list_selections_t) inz(*likeds);

  add_message(1: 'D');
  add_message(2: 'I');
  add_message(3: 'W');
  add_message(4: 'E');

  sel = job_list_selection('');
  calc.req_page = 1;
  calc.req_page_rows = APP_DEFAULT_PAGE_ROWS;

  iEqual(4: APMSAL_list(calc: sel: g_list): 'got_rows');
  assert_text('E': g_list(1).TYPE: 'row 1 TYPE');
  assert_text('D': g_list(4).TYPE: 'row 4 TYPE');
end-proc;

dcl-proc test_APMSAL_list_other_job_gets_nothing export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(APMSAL_list_selections_t) inz(*likeds);

  add_message(1: 'I');

  sel.JOB_NAME = '000000/NOBODY/NOJOB';
  sel.TYPE = '';
  calc.req_page = 1;
  calc.req_page_rows = APP_DEFAULT_PAGE_ROWS;

  iEqual(0: APMSAL_list(calc: sel: g_list): 'got_rows');
  iEqual(0: calc.total_rows: 'total_rows');
end-proc;

dcl-proc test_APMSAL_list_paging export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(APMSAL_list_selections_t) inz(*likeds);

  add_message(1: 'I');
  add_message(2: 'I');
  add_message(3: 'I');
  sel = job_list_selection('I');

  // Page 1 of 2: the two newest
  calc.req_page = 1;
  calc.req_page_rows = 2;
  iEqual(2: APMSAL_list(calc: sel: g_list): 'page 1 got_rows');
  iEqual(3: calc.total_rows: 'page 1 total_rows');
  iEqual(2: calc.total_pages: 'page 1 total_pages');
  assert_text(text_for(3): g_list(1).TEXT: 'page 1 row 1 TEXT');
  assert_text(text_for(2): g_list(2).TEXT: 'page 1 row 2 TEXT');

  // Page 2 of 2: the oldest
  clear calc;
  calc.req_page = 2;
  calc.req_page_rows = 2;
  iEqual(1: APMSAL_list(calc: sel: g_list): 'page 2 got_rows');
  assert_text(text_for(1): g_list(1).TEXT: 'page 2 row 1 TEXT');
end-proc;

//==============================================================================
// APMSAL_open / APMSAL_fetch / APMSAL_close (oldest first)
//==============================================================================

// With no selection, the current job's messages of every type
dcl-proc test_APMSAL_open_fetch_close export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);

  add_message(1: 'I');
  add_message(2: 'E');
  add_message(3: 'D');

  assert(not APMSAL_open(): 'APMSAL_open reported an error');

  assert(APMSAL_fetch(service): 'First fetch found nothing');
  assert_text(text_for(1): service.TEXT: 'fetch 1 TEXT');
  assert(APMSAL_fetch(service): 'Second fetch found nothing');
  assert_text(text_for(2): service.TEXT: 'fetch 2 TEXT');
  assert(APMSAL_fetch(service): 'Third fetch found nothing');
  assert_text(text_for(3): service.TEXT: 'fetch 3 TEXT');

  assert(not APMSAL_fetch(service): 'Fetch past the last row still found a row');
  assert(not APMSAL_close(): 'APMSAL_close reported an error');
end-proc;

dcl-proc test_APMSAL_open_filter_by_type export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds sel     likeds(APMSAL_open_selections_t) inz(*likeds);
  dcl-ds service likeds(APMSAL_t) inz(*likeds);

  add_message(1: 'I');
  add_message(2: 'E');
  add_message(3: 'I');

  sel.TYPE = 'I';
  assert(not APMSAL_open(sel): 'APMSAL_open reported an error');

  assert(APMSAL_fetch(service): 'First fetch found nothing');
  assert_text(text_for(1): service.TEXT: 'fetch 1 TEXT');
  assert(APMSAL_fetch(service): 'Second fetch found nothing');
  assert_text(text_for(3): service.TEXT: 'fetch 2 TEXT');
  assert(not APMSAL_fetch(service): 'The E message was not filtered out');

  APMSAL_close();
end-proc;

// The job defaults to the current job when the selection leaves it blank, and
// is otherwise used as given
dcl-proc test_APMSAL_open_other_job_gets_nothing export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds sel     likeds(APMSAL_open_selections_t) inz(*likeds);
  dcl-ds service likeds(APMSAL_t) inz(*likeds);

  add_message(1: 'I');

  sel.JOB_NAME = '000000/NOBODY/NOJOB';
  assert(not APMSAL_open(sel): 'APMSAL_open reported an error');
  assert(not APMSAL_fetch(service): 'A message was fetched for another job');

  APMSAL_close();
end-proc;

//==============================================================================
// APMSAL_open_desc / APMSAL_fetch_desc / APMSAL_close_desc (newest first)
//==============================================================================

dcl-proc test_APMSAL_open_desc_fetch_desc_close_desc export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);

  add_message(1: 'I');
  add_message(2: 'E');
  add_message(3: 'D');

  assert(not APMSAL_open_desc(): 'APMSAL_open_desc reported an error');

  assert(APMSAL_fetch_desc(service): 'First fetch found nothing');
  assert_text(text_for(3): service.TEXT: 'fetch 1 TEXT');
  assert(APMSAL_fetch_desc(service): 'Second fetch found nothing');
  assert_text(text_for(2): service.TEXT: 'fetch 2 TEXT');
  assert(APMSAL_fetch_desc(service): 'Third fetch found nothing');
  assert_text(text_for(1): service.TEXT: 'fetch 3 TEXT');

  assert(not APMSAL_fetch_desc(service): 'Fetch past the last row found one');
  assert(not APMSAL_close_desc(): 'APMSAL_close_desc reported an error');
end-proc;

dcl-proc test_APMSAL_open_desc_filter_by_type export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds sel     likeds(APMSAL_open_selections_t) inz(*likeds);
  dcl-ds service likeds(APMSAL_t) inz(*likeds);

  add_message(1: 'I');
  add_message(2: 'E');

  sel.TYPE = 'E';
  assert(not APMSAL_open_desc(sel): 'APMSAL_open_desc reported an error');

  assert(APMSAL_fetch_desc(service): 'Fetch found nothing');
  assert_text(text_for(2): service.TEXT: 'fetch 1 TEXT');
  assert(not APMSAL_fetch_desc(service): 'The I message was not filtered out');

  APMSAL_close_desc();
end-proc;

//==============================================================================
// APMSAL_fetch_first / APMSAL_fetch_last
//==============================================================================

// Selects on the TYPE already in the structure, which defaults to information
dcl-proc test_APMSAL_fetch_first_by_type export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);

  add_message(1: 'E');
  add_message(2: 'I');
  add_message(3: 'I');

  assert(APMSAL_fetch_first(service): 'APMSAL_fetch_first found nothing');
  assert_text(text_for(2): service.TEXT: 'TEXT');
  assert_text('I': service.TYPE: 'TYPE');
end-proc;

dcl-proc test_APMSAL_fetch_last_by_type export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);

  add_message(1: 'I');
  add_message(2: 'I');
  add_message(3: 'E');

  assert(APMSAL_fetch_last(service): 'APMSAL_fetch_last found nothing');
  assert_text(text_for(2): service.TEXT: 'TEXT');
  assert_text('I': service.TYPE: 'TYPE');
end-proc;

// A blank type selects every type
dcl-proc test_APMSAL_fetch_first_and_last_blank_type export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds first likeds(APMSAL_t) inz(*likeds);
  dcl-ds last  likeds(APMSAL_t) inz(*likeds);

  add_message(1: 'E');
  add_message(2: 'I');
  add_message(3: 'W');

  first.TYPE = '';
  assert(APMSAL_fetch_first(first): 'APMSAL_fetch_first found nothing');
  assert_text(text_for(1): first.TEXT: 'first TEXT');

  last.TYPE = '';
  assert(APMSAL_fetch_last(last): 'APMSAL_fetch_last found nothing');
  assert_text(text_for(3): last.TEXT: 'last TEXT');
end-proc;

dcl-proc test_APMSAL_fetch_first_and_last_not_found export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds first likeds(APMSAL_t) inz(*likeds);
  dcl-ds last  likeds(APMSAL_t) inz(*likeds);

  add_message(1: 'I');

  first.TYPE = 'E';
  assert(not APMSAL_fetch_first(first): 'Found an E message that was never added');
  last.TYPE = 'E';
  assert(not APMSAL_fetch_last(last): 'Found an E message that was never added');
end-proc;

// They close the cursor they open, so they can be called again straight away
dcl-proc test_APMSAL_fetch_first_and_last_can_repeat export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);

  add_message(1: 'I');

  assert(APMSAL_fetch_first(service): 'First fetch_first found nothing');
  assert(APMSAL_fetch_first(service): 'Second fetch_first found nothing');
  assert(APMSAL_fetch_last(service): 'First fetch_last found nothing');
  assert(APMSAL_fetch_last(service): 'Second fetch_last found nothing');
end-proc;
