**free

//==============================================================================
// RMAPP03.test - Unit tests for RMAPP03 (Application Helper - Logger Module)
//
// Object name is TRMAPP03 (strip .test, prefix T).
//
// APP_log sends its message to a call stack entry chosen by %target(*caller:
// stack_offset). *caller is the caller of APP_log, and the offset moves back
// from there:
//
//   test proc -> APP_escape -> APP_log (offset 1)  => message goes to test proc
//   test proc -> APP_log (offset 1)                => message goes to the caller
//                                                     of the test proc, i.e.
//                                                     RPGUnit itself
//   test proc -> APP_log (offset 0)                => message goes to test proc
//
// So tests that need to catch an escape message either go through APP_escape or
// pass an explicit offset of 0. Passing the default offset to APP_log directly
// with APP_LOG_ESCAPE would send the escape to RPGUnit and end the run, so
// no test does that.
//
// The trapped message is read with RPGUnit's getMonitoredMessage() inside the
// on-error block, which returns its id (msgInfo_t.id) and text (msgInfo_t.txt).
//
// 30/10/2026 - RM - created
//==============================================================================

ctl-opt nomain;
ctl-opt bnddir('RMAPP');

/include 'QCPYSRC/RMAPP_D.rpgleinc'
/include 'QCPYSRC/RMTOOLS_D.rpgleinc'
/include QINCLUDE,TESTCASE

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

//==============================================================================
// APP_escape
//==============================================================================

dcl-proc test_APP_escape_raises_escape_message export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s raised like(BOOLEAN_t);
  dcl-ds msg likeds(msgInfo_t) inz(*likeds);

  raised = false;
  monitor;
    APP_escape('Boom');
  on-error;
    raised = true;
    msg = getMonitoredMessage();
  endmon;

  // fail() sits outside the monitor, otherwise its own CPF9897 would be caught
  assert(raised: 'APP_escape did not raise an escape message to its caller');
  assert_text('APP2901': msg.id: 'message id');
end-proc;

dcl-proc test_APP_escape_message_text export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s raised like(BOOLEAN_t);
  dcl-ds msg likeds(msgInfo_t) inz(*likeds);

  raised = false;
  monitor;
    APP_escape('Customer 42 not found');
  on-error;
    raised = true;
    msg = getMonitoredMessage();
  endmon;

  assert(raised: 'APP_escape did not raise an escape message to its caller');
  assert_text('Customer 42 not found': msg.txt: 'message text');
end-proc;

// Code after APP_escape must not run
dcl-proc test_APP_escape_ends_the_caller_flow export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s reached like(BOOLEAN_t);

  reached = false;
  monitor;
    APP_escape('Boom');
    reached = true;
  on-error;
  endmon;

  assert(not reached: 'Code after APP_escape still ran');
end-proc;

//==============================================================================
// APP_log
//==============================================================================

dcl-proc test_APP_log_escape_with_offset_zero export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s raised like(BOOLEAN_t);
  dcl-ds msg likeds(msgInfo_t) inz(*likeds);

  raised = false;
  monitor;
    // Offset 0 targets the caller of APP_log, which is this procedure
    APP_log('Boom': APP_LOG_ESCAPE: 0);
  on-error;
    raised = true;
    msg = getMonitoredMessage();
  endmon;

  assert(raised: 'APP_log with APP_LOG_ESCAPE did not raise an escape message');
  assert_text('APP2901': msg.id: 'message id');
  assert_text('Boom': msg.txt: 'message text');
end-proc;

dcl-proc test_APP_log_info_does_not_raise export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s raised like(BOOLEAN_t);

  raised = false;
  monitor;
    // Explicit type, sent to this procedure's own message queue
    APP_log('Information only': APP_LOG_INFO: 0);
  on-error;
    raised = true;
  endmon;

  assert(not raised: 'An information message raised an exception');
end-proc;

// The default message type is information. With the default offset of 1 the
// message goes to RPGUnit's runner and shows up in the job log.
dcl-proc test_APP_log_default_type_does_not_raise export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s raised like(BOOLEAN_t);

  raised = false;
  monitor;
    APP_log('RMAPP03 test: default message type');
  on-error;
    raised = true;
  endmon;

  assert(not raised: 'A default (information) message raised an exception');
end-proc;

// An unrecognised message type matches neither branch, so nothing is sent
dcl-proc test_APP_log_unknown_type_does_nothing export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s raised like(BOOLEAN_t);

  raised = false;
  monitor;
    APP_log('Ignored': 99: 0);
  on-error;
    raised = true;
  endmon;

  assert(not raised: 'An unrecognised message type raised an exception');
end-proc;

// *omit is the way to skip message_type while still passing stack_offset, and
// APP_log must treat it as "use the default" (information). The assertion
// below only proves the call completes without an exception. That the message
// is then logged as information was confirmed from the job log on the host
// (QSYS2.JOBLOG_INFO shows 'Omitted message type' as INFORMATIONAL), because
// an offset 0 info message is not observable from within the test.
dcl-proc test_APP_log_omit_message_type export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s failed like(BOOLEAN_t);
  dcl-ds msg likeds(msgInfo_t) inz(*likeds);

  failed = false;
  monitor;
    // Offset 0 keeps the (information) message on this procedure's own queue
    APP_log('Omitted message type': *omit: 0);
  on-error;
    failed = true;
    msg = getMonitoredMessage();
  endmon;

  // Only the char(7) id goes in the message: a varying-length txt from a
  // failed call is not safe to concatenate here
  assert(not failed: 'APP_log failed when message_type was *omit: ' + msg.id);
end-proc;
