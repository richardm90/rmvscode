**free

//==============================================================================
// ADDMSG.test - Integration tests for the ADDMSG procedures copybook
//
// Object name is TADDMSG (strip .test, prefix T).
//
// addmsg, addmsg_diag and addmsg_info are not module procedures: ADDMSG_P is a
// copybook of procedures that each program compiles in. This member includes
// it the same way, then calls them. They sit on APMSAL_log, so these are
// INTEGRATION tests that run against the real APPMSG table.
//
// FLASH_P is not tested: it writes display file subfiles.
//
// Isolation:
// - setUp calls APMSAL_inz, which closes the APMDAL gate, so a test sees only
//   the message it adds itself. The add procedures do not return the message
//   id, so the message is found as the newest one for this job, and registered
//   for deletion straight away. tearDown deletes it after every test,
//   including failed ones.
// - Every message has a TEXT and FIELD_NAME unique to this run.
//
// 02/11/2026 - RM - created
//==============================================================================

ctl-opt nomain;
ctl-opt bnddir('RMAPP');

/include 'QCPYSRC/PSDS_D.rpgleinc'
/include 'QCPYSRC/ADDMSG_D.rpgleinc'
/include 'QCPYSRC/APMDAL_D.rpgleinc'
/include 'QCPYSRC/RMAPP_D.rpgleinc'
/include 'QCPYSRC/RMTOOLS_D.rpgleinc'
/include QINCLUDE,TESTCASE

//==============================================================================
// Suite state
//==============================================================================

// Unique to this run: 'T' + hhmmss + hundredths = 9 chars, the 10th is the
// fixture sequence number (FIELD_NAME is char(10)).
dcl-s g_run_id char(9);
// Id of the message added by the current test, deleted by tearDown
dcl-s g_created_id like(INTEGER_t) inz(0);

//==============================================================================
// Procedures under test
//
// ADDMSG_P holds procedures, so it has to come after all global declarations
//==============================================================================

/include 'QCPYSRC/ADDMSG_P.rpgleinc'

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
// Find the message the test just added, which is the only one since setUp, and
// register it for deletion before anything is asserted.
///

dcl-proc added_message;
  dcl-pi *n likeds(APMSAL_t) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);

  // A blank type selects every type
  service.TYPE = '';
  if not APMSAL_fetch_last(service);
    fail('No message was added');
  endif;
  g_created_id = service.ID;

  return service;
end-proc;

///
// Check the type, field name and text of the message the test just added.
///

dcl-proc assert_added;
  dcl-pi *n;
    type       like(APMSAL_type_t) const;
    field_name like(FIELD_NAME_t) const;
    text       like(APMSAL_text_t) const;
  end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);

  service = added_message();

  assert_text(type: service.TYPE: 'TYPE');
  assert_text(field_name: %trim(service.FIELD_NAME): 'FIELD_NAME');
  assert_text(text: service.TEXT: 'TEXT');
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

  g_created_id = 0;
  APMSAL_inz();
end-proc;

// Runs after every test, including failed ones, so nothing is leaked
dcl-proc tearDown export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds data likeds(APMDAL_t) inz(*likeds);

  if g_created_id > 0;
    data.ID = g_created_id;
    APMDAL_delete(data);
  endif;

  g_created_id = 0;
  APMSAL_inz();
end-proc;

//==============================================================================
// addmsg
//==============================================================================

// With only the text, the message is an error with no field name
dcl-proc test_addmsg_text_only_is_an_error export;
  dcl-pi *n extproc(*dclcase) end-pi;

  addmsg(text_for(1));

  assert_added(APMSAL_TYPE_ERROR: ADDMSG_FIELD_NAME_NONE: text_for(1));
  assert(APMSAL_error(): 'APMSAL_error is off');
end-proc;

dcl-proc test_addmsg_with_field_name_is_an_error export;
  dcl-pi *n extproc(*dclcase) end-pi;

  addmsg(text_for(1): field_name_for(1));

  assert_added(APMSAL_TYPE_ERROR: field_name_for(1): text_for(1));
  assert(APMSAL_error(): 'APMSAL_error is off');
end-proc;

dcl-proc test_addmsg_with_type export;
  dcl-pi *n extproc(*dclcase) end-pi;

  addmsg(text_for(1): field_name_for(1): APMSAL_TYPE_WARNING);

  assert_added(APMSAL_TYPE_WARNING: field_name_for(1): text_for(1));
  assert(APMSAL_warning(): 'APMSAL_warning is off');
  assert(not APMSAL_error(): 'APMSAL_error is on for a warning');
end-proc;

//==============================================================================
// addmsg_diag
//==============================================================================

dcl-proc test_addmsg_diag_text_only export;
  dcl-pi *n extproc(*dclcase) end-pi;

  addmsg_diag(text_for(1));

  assert_added(APMSAL_TYPE_DIAGNOSTIC: ADDMSG_FIELD_NAME_NONE: text_for(1));
  assert(APMSAL_diagnostic(): 'APMSAL_diagnostic is off');
end-proc;

dcl-proc test_addmsg_diag_with_field_name export;
  dcl-pi *n extproc(*dclcase) end-pi;

  addmsg_diag(text_for(1): field_name_for(1));

  assert_added(APMSAL_TYPE_DIAGNOSTIC: field_name_for(1): text_for(1));
  assert(APMSAL_diagnostic(): 'APMSAL_diagnostic is off');
end-proc;

//==============================================================================
// addmsg_info
//==============================================================================

dcl-proc test_addmsg_info_text_only export;
  dcl-pi *n extproc(*dclcase) end-pi;

  addmsg_info(text_for(1));

  assert_added(APMSAL_TYPE_INFORMATION: ADDMSG_FIELD_NAME_NONE: text_for(1));
  assert(APMSAL_information(): 'APMSAL_information is off');
end-proc;

dcl-proc test_addmsg_info_with_field_name export;
  dcl-pi *n extproc(*dclcase) end-pi;

  addmsg_info(text_for(1): field_name_for(1));

  assert_added(APMSAL_TYPE_INFORMATION: field_name_for(1): text_for(1));
  assert(APMSAL_information(): 'APMSAL_information is off');
end-proc;

//==============================================================================
// Recorded caller
//==============================================================================

// The ADDMSG procedures are compiled into the calling program, so they are not
// part of the RMAPP service program and are not skipped when the message layer
// works out who raised the message. DEFECT (suspected): CREATED_BY_PRC records
// ADDMSG, ADDMSG_INFO and so on, not the procedure that called them. These
// tests expect the calling procedure, as test_APMSAL_log_records_the_caller
// does for APMSAL_log. Each wrapper is called directly from its test.

dcl-proc test_addmsg_records_the_caller export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);

  addmsg(text_for(1));

  service = added_message();
  assert_text(%trim(psds.proc_pgm): %trim(service.CREATED_BY_PGM):
              'CREATED_BY_PGM');
  assert_text('TEST_ADDMSG_RECORDS_THE_CALLER': %upper(service.CREATED_BY_PRC):
              'CREATED_BY_PRC');
end-proc;

// Calls addmsg, so the stack has two wrapper entries to skip
dcl-proc test_addmsg_info_records_the_caller export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);

  addmsg_info(text_for(1));

  service = added_message();
  assert_text('TEST_ADDMSG_INFO_RECORDS_THE_CALLER':
              %upper(service.CREATED_BY_PRC): 'CREATED_BY_PRC');
end-proc;

dcl-proc test_addmsg_diag_records_the_caller export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds service likeds(APMSAL_t) inz(*likeds);

  addmsg_diag(text_for(1));

  service = added_message();
  assert_text('TEST_ADDMSG_DIAG_RECORDS_THE_CALLER':
              %upper(service.CREATED_BY_PRC): 'CREATED_BY_PRC');
end-proc;
