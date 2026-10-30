**free

//==============================================================================
// RMAPP01.test - Unit tests for RMAPP01 (Application Helper - IBM i Job Module)
//
// Object name is TRMAPP01 (strip .test, prefix T).
//
// RMAPP01 reports facts about the running job and the clock. Nothing is
// created or changed, so no setUp/tearDown is needed. The expected values come
// from the test's own PSDS (same job, so same job name, user and number) and
// from the clock read either side of the call.
//
// 30/10/2026 - RM - created
//==============================================================================

ctl-opt nomain;
ctl-opt bnddir('RMAPP');

/include 'QCPYSRC/PSDS_D.rpgleinc'
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
// APP_job_full_name
//==============================================================================

// Format is number/user/name, e.g. 123456/RICHARD/QZDASOINIT. The three parts
// are checked separately so a wrong separator or a reordering is reported.
dcl-proc test_APP_job_full_name export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s job like(JOB_FULL_NAME_t);
  dcl-s first_slash  like(INTEGER_t);
  dcl-s second_slash like(INTEGER_t);

  job = APP_job_full_name();

  first_slash = %scan('/': job);
  iEqual(7: first_slash: 'position of first slash (6 digit number)');

  second_slash = %scan('/': job: first_slash + 1);
  assert((second_slash > first_slash + 1): 'user part is empty in [' + job + ']');
  iEqual(0: %scan('/': job: second_slash + 1): 'position of a third slash');

  assert_text(%editc(psds.job_number: 'X'): %subst(job: 1: 6): 'job number');
  assert_text(%trimr(psds.job_user)
             : %subst(job: first_slash + 1: second_slash - first_slash - 1)
             : 'job user');
  assert_text(%trimr(psds.job_name): %subst(job: second_slash + 1):
              'job name');
end-proc;

dcl-proc test_APP_job_full_name_number_is_numeric export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s job like(JOB_FULL_NAME_t);

  job = APP_job_full_name();

  assert((%check('0123456789': %subst(job: 1: 6)) = 0):
         'job number is not all digits in [' + job + ']');
end-proc;

//==============================================================================
// APP_user
//==============================================================================

dcl-proc test_APP_user export;
  dcl-pi *n extproc(*dclcase) end-pi;

  assert_text(%trimr(psds.current_user): %trimr(APP_user()): 'user');
end-proc;

dcl-proc test_APP_user_not_blank export;
  dcl-pi *n extproc(*dclcase) end-pi;

  assert((%trim(APP_user()) <> ''): 'APP_user returned a blank user');
end-proc;

//==============================================================================
// APP_date / APP_time / APP_timestamp
//
// Each is taken between a clock read before and after the call. For the time
// the read is repeated if midnight passed in between, which would otherwise
// make "before <= result <= after" meaningless.
//==============================================================================

dcl-proc test_APP_date export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s before date;
  dcl-s result date;
  dcl-s after  date;

  before = %date();
  result = APP_date();
  after = %date();

  assert((result >= before and result <= after):
         'APP_date ' + %char(result) + ' is outside ' + %char(before)
         + ' to ' + %char(after));
end-proc;

dcl-proc test_APP_time export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s before time;
  dcl-s result time;
  dcl-s after  time;

  before = %time();
  result = APP_time();
  after = %time();

  // Midnight passed during the call, so try once more
  if after < before;
    before = %time();
    result = APP_time();
    after = %time();
  endif;

  assert((result >= before and result <= after):
         'APP_time ' + %char(result) + ' is outside ' + %char(before)
         + ' to ' + %char(after));
end-proc;

dcl-proc test_APP_timestamp export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s before timestamp;
  dcl-s result timestamp;
  dcl-s after  timestamp;

  before = %timestamp();
  result = APP_timestamp();
  after = %timestamp();

  assert((result >= before and result <= after):
         'APP_timestamp ' + %char(result) + ' is outside ' + %char(before)
         + ' to ' + %char(after));
end-proc;

// The timestamp must be read afresh on every call, not captured once
dcl-proc test_APP_timestamp_advances export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s first  timestamp;
  dcl-s second timestamp;

  first = APP_timestamp();
  second = APP_timestamp();
  assert((second >= first): 'Second timestamp ' + %char(second)
                          + ' is before the first ' + %char(first));

  // A real pause, so a stale value cannot pass by luck
  waitSeconds(1);
  second = APP_timestamp();
  assert((second > first): 'Timestamp did not advance across a 1 second wait: '
                         + %char(first) + ' then ' + %char(second));
end-proc;

// APP_date and APP_timestamp are read separately but must agree on the day
dcl-proc test_APP_date_agrees_with_timestamp export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s stamp timestamp;
  dcl-s day   date;

  stamp = APP_timestamp();
  day = APP_date();

  // Allow for midnight passing between the two calls
  assert((day = %date(stamp) or day = %date(stamp) + %days(1)):
         'APP_date ' + %char(day) + ' does not match the date of '
         + %char(stamp));
end-proc;
