**free

//==============================================================================
// CUSDET.TEST - Integration tests for CUSDET (Customer Details SL) and, through
//               it, CUSDETDL (Customer Details DAL)
//
// Object name is TCUSDET (strip .TEST, prefix T).
//
// These are INTEGRATION tests, not unit tests. CUSDET delegates straight to
// CUSDETDL, which runs embedded SQL against the CUSDETVP/CUSDETVL views, and
// there is no seam to substitute them. The tests therefore run against the real
// CUSDET table in the library list.
//
// Isolation:
// - Every customer the suite creates has a code and name unique to this run
//   (built from the time of day), so reruns never collide and list searches
//   can be scoped to this run's rows.
// - Each customer is registered for deletion the moment it is added, and
//   tearDown deletes them after every test, including failed ones.
// - No pre-existing CUSDET row is read, changed or deleted.
//
// Run with a library list that contains the application library (CUSDET,
// CUSDETVP, CUSDETVL and the RMAPP service program/binding directory).
//
// 29/10/2026 - RM - created
//==============================================================================

ctl-opt nomain;
ctl-opt bnddir('RMAPP');

/include 'QCPYSRC/CUSDET_D.rpgleinc'
/include 'QCPYSRC/RMAPP_D.rpgleinc'
/include 'QCPYSRC/RMTOOLS_D.rpgleinc'
/include QINCLUDE,TESTCASE

//==============================================================================
// Suite state
//==============================================================================

dcl-c MAX_FIXTURES 10;

// Unique to this run: 'T' + hhmmss + hundredths = 9 chars, the 10th is the
// fixture sequence number.
dcl-s g_run_id char(9);
// Customer ids created by the current test, deleted by tearDown
dcl-s g_created_ids like(INTEGER_t) dim(MAX_FIXTURES);
dcl-s g_created_count like(INTEGER_t) inz(0);
// Large, so held in static storage rather than on the stack of each test
dcl-ds g_list likeds(CUSDET_list_t) dim(APP_MAXIMUM_PAGE_ROWS) inz(*likeds);

//==============================================================================
// Helpers (not exported, and not named test*, so RPGUnit does not run them)
//==============================================================================

///
// Compare two text values, reporting both on failure.
//
// Used instead of aEqual because aEqual (operational descriptors) reads the
// wrong length for varying-length elements of a DS array.
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
// Build a populated (but not yet added) customer.
//
// @param Fixture sequence number, 1 to 9. Forms the last character of the code
//        and the end of the name.
///

dcl-proc build_customer;
  dcl-pi *n likeds(CUSDET_t);
    seq like(INTEGER_t) const;
  end-pi;

  dcl-ds cust likeds(CUSDET_t) inz(*likeds);

  cust = CUSDET_new();
  // Deliberately lower case: the DAL upper-cases CODE on the way in
  cust.CODE = %lower(g_run_id) + %char(seq);
  cust.NAME = 'RMTEST ' + g_run_id + ' ' + %char(seq);
  cust.ADDRESS_LINE1 = '1 Test Street';
  cust.ADDRESS_LINE2 = 'Testville';
  cust.ADDRESS_LINE3 = 'Testshire';
  cust.ADDRESS_LINE4 = 'England';
  cust.POSTCODE = 'TE5 7AB';
  cust.CONTACT_NAME = 'Tess Ting';
  cust.CONTACT_TELP = '01234 567890';
  cust.CONTACT_EMAIL = 'tess@example.com';
  cust.VAT_CODE = 'S1';
  cust.CURRENCY = 'gbp';
  cust.CREDIT_LIMIT = 1234.56;
  cust.CURRENT_BALANCE = 78.90;
  cust.COMMENTS = 'Created by the CUSDET test suite';

  return cust;
end-proc;

///
// Add a customer through CUSDET_add and register it for tearDown.
//
// Registration happens immediately after the add, before any assertion, so
// a failing test still cleans up.
///

dcl-proc add_customer;
  dcl-pi *n;
    cust likeds(CUSDET_t);
  end-pi;

  dcl-s add_error like(BOOLEAN_t);

  add_error = CUSDET_add(cust);

  if not add_error and cust.ID > 0;
    if g_created_count >= MAX_FIXTURES;
      fail('Suite fixture limit of ' + %char(MAX_FIXTURES) + ' exceeded');
    endif;
    g_created_count += 1;
    g_created_ids(g_created_count) = cust.ID;
  endif;

  assert(not add_error: 'CUSDET_add reported an error for ' + cust.CODE);
  assert((cust.ID > 0): 'CUSDET_add did not return an identity value');
end-proc;

///
// Fetch a customer back by id.
///

dcl-proc get_customer;
  dcl-pi *n likeds(CUSDET_t);
    id like(INTEGER_t) const;
  end-pi;

  dcl-ds cust likeds(CUSDET_t) inz(*likeds);

  cust.ID = id;
  CUSDET_get(cust);

  return cust;
end-proc;

///
// A list selection scoped to this run's rows (matches the NAME prefix).
///

dcl-proc run_selection;
  dcl-pi *n likeds(CUSDET_list_selections_t) end-pi;

  dcl-ds sel likeds(CUSDET_list_selections_t) inz(*likeds);

  sel.SEARCH = g_run_id;

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

dcl-proc setUp export;
  dcl-pi *n extproc(*dclcase) end-pi;

  g_created_count = 0;
end-proc;

// Runs after every test, including failed ones, so nothing is leaked
dcl-proc tearDown export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds cust likeds(CUSDET_t) inz(*likeds);
  dcl-s i like(INTEGER_t);

  for i = 1 to g_created_count;
    clear cust;
    cust.ID = g_created_ids(i);
    CUSDET_delete(cust);
  endfor;

  g_created_count = 0;
end-proc;

//==============================================================================
// CUSDET_new
//==============================================================================

dcl-proc test_CUSDET_new export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds cust likeds(CUSDET_t) inz(*likeds);

  cust = CUSDET_new();

  assert_text(CUSDET_STATUS_NEW: cust.STATUS: 'STATUS');
  iEqual(0: cust.ID: 'ID');
  assert_text('': %trim(cust.CODE): 'CODE');
end-proc;

//==============================================================================
// CUSDET_add / CUSDET_get
//==============================================================================

dcl-proc test_CUSDET_add_get_round_trip export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds cust likeds(CUSDET_t) inz(*likeds);
  dcl-ds got  likeds(CUSDET_t) inz(*likeds);
  dcl-s before timestamp;
  dcl-s after  timestamp;

  cust = build_customer(1);

  before = %timestamp();
  add_customer(cust);
  after = %timestamp();

  got = get_customer(cust.ID);

  assert(CUSDET_found(): 'CUSDET_found is off after getting an added customer');
  assert(not CUSDET_error(): 'CUSDET_error is on after getting a customer');

  iEqual(cust.ID: got.ID: 'ID');
  // The DAL upper-cases code, status, VAT code and currency
  assert_text(%upper(g_run_id) + '1': %trim(got.CODE): 'CODE');
  assert_text(CUSDET_STATUS_NEW: got.STATUS: 'STATUS');
  assert_text('RMTEST ' + g_run_id + ' 1': got.NAME: 'NAME');
  assert_text('1 Test Street': got.ADDRESS_LINE1: 'ADDRESS_LINE1');
  assert_text('Testville': got.ADDRESS_LINE2: 'ADDRESS_LINE2');
  assert_text('Testshire': got.ADDRESS_LINE3: 'ADDRESS_LINE3');
  assert_text('England': got.ADDRESS_LINE4: 'ADDRESS_LINE4');
  assert_text('TE5 7AB': got.POSTCODE: 'POSTCODE');
  assert_text('Tess Ting': got.CONTACT_NAME: 'CONTACT_NAME');
  assert_text('01234 567890': got.CONTACT_TELP: 'CONTACT_TELP');
  assert_text('tess@example.com': got.CONTACT_EMAIL: 'CONTACT_EMAIL');
  assert_text('S1': got.VAT_CODE: 'VAT_CODE');
  assert_text('GBP': got.CURRENCY: 'CURRENCY');
  assert_text('1234.56': %char(got.CREDIT_LIMIT): 'CREDIT_LIMIT');
  assert_text('78.90': %char(got.CURRENT_BALANCE): 'CURRENT_BALANCE');
  assert_text('Created by the CUSDET test suite': got.COMMENTS: 'COMMENTS');

  // Audit columns are set by the DAL, not the caller
  assert_text(%trimr(APP_user()): %trimr(got.CREATED_BY_USER):
              'CREATED_BY_USER');
  assert((got.CREATED_TIMESTAMP >= before and got.CREATED_TIMESTAMP <= after):
         'CREATED_TIMESTAMP ' + %char(got.CREATED_TIMESTAMP)
         + ' is outside the add call: ' + %char(before) + ' to '
         + %char(after));
end-proc;

dcl-proc test_CUSDET_add_assigns_distinct_ids export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds first  likeds(CUSDET_t) inz(*likeds);
  dcl-ds second likeds(CUSDET_t) inz(*likeds);

  first = build_customer(1);
  second = build_customer(2);
  add_customer(first);
  add_customer(second);

  assert((first.ID <> second.ID): 'Two adds returned the same ID');
end-proc;

dcl-proc test_CUSDET_get_not_found export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds cust likeds(CUSDET_t) inz(*likeds);
  dcl-s found like(BOOLEAN_t);

  // Identity values start at 1, so -1 can never exist
  cust.ID = -1;
  found = CUSDET_get(cust);

  assert(not found: 'CUSDET_get returned found for ID -1');
  assert(not CUSDET_found(): 'CUSDET_found is on after a get that found nothing');
  assert(not CUSDET_error(): 'A get that finds nothing should not be an error');
end-proc;

//==============================================================================
// CUSDET_update
//==============================================================================

dcl-proc test_CUSDET_update export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds cust likeds(CUSDET_t) inz(*likeds);
  dcl-ds got  likeds(CUSDET_t) inz(*likeds);
  dcl-s created_by like(cust.CREATED_BY_USER);

  cust = build_customer(1);
  add_customer(cust);
  got = get_customer(cust.ID);
  created_by = got.CREATED_BY_USER;

  cust.STATUS = 'a';
  cust.NAME = 'RMTEST ' + g_run_id + ' updated';
  cust.POSTCODE = 'UP1 8DT';
  cust.CREDIT_LIMIT = 9999.99;
  cust.COMMENTS = 'Updated';

  assert(not CUSDET_update(cust): 'CUSDET_update reported an error');

  got = get_customer(cust.ID);
  assert_text('A': got.STATUS: 'STATUS');
  assert_text('RMTEST ' + g_run_id + ' updated': got.NAME: 'NAME');
  assert_text('UP1 8DT': got.POSTCODE: 'POSTCODE');
  assert_text('9999.99': %char(got.CREDIT_LIMIT): 'CREDIT_LIMIT');
  assert_text('Updated': got.COMMENTS: 'COMMENTS');

  // Fields not changed stay as they were, and the audit columns are untouched
  assert_text('1 Test Street': got.ADDRESS_LINE1: 'ADDRESS_LINE1');
  assert_text('78.90': %char(got.CURRENT_BALANCE): 'CURRENT_BALANCE');
  assert_text(created_by: got.CREATED_BY_USER: 'CREATED_BY_USER');
end-proc;

dcl-proc test_CUSDET_update_only_changes_target_row export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds first  likeds(CUSDET_t) inz(*likeds);
  dcl-ds second likeds(CUSDET_t) inz(*likeds);
  dcl-ds got    likeds(CUSDET_t) inz(*likeds);

  first = build_customer(1);
  second = build_customer(2);
  add_customer(first);
  add_customer(second);

  first.NAME = 'RMTEST ' + g_run_id + ' changed';
  assert(not CUSDET_update(first): 'CUSDET_update reported an error');

  got = get_customer(second.ID);
  assert_text('RMTEST ' + g_run_id + ' 2': got.NAME: 'untouched row NAME');
end-proc;

//==============================================================================
// CUSDET_delete
//==============================================================================

dcl-proc test_CUSDET_delete export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds cust likeds(CUSDET_t) inz(*likeds);
  dcl-ds got  likeds(CUSDET_t) inz(*likeds);

  cust = build_customer(1);
  add_customer(cust);

  assert(not CUSDET_delete(cust): 'CUSDET_delete reported an error');

  got.ID = cust.ID;
  assert(not CUSDET_get(got): 'Customer is still found after delete');
end-proc;

dcl-proc test_CUSDET_delete_only_removes_target_row export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds first  likeds(CUSDET_t) inz(*likeds);
  dcl-ds second likeds(CUSDET_t) inz(*likeds);
  dcl-ds got    likeds(CUSDET_t) inz(*likeds);

  first = build_customer(1);
  second = build_customer(2);
  add_customer(first);
  add_customer(second);

  assert(not CUSDET_delete(first): 'CUSDET_delete reported an error');

  got.ID = second.ID;
  assert(CUSDET_get(got): 'The other customer was deleted too');
end-proc;

//==============================================================================
// CUSDET_exists
//==============================================================================

dcl-proc test_CUSDET_exists export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds cust likeds(CUSDET_t) inz(*likeds);

  cust = build_customer(1);
  add_customer(cust);

  // Codes are stored upper case
  assert(CUSDET_exists(%upper(g_run_id) + '1'): 'Added code was not found');
  assert(not CUSDET_exists(%upper(g_run_id) + '9'): 'Unknown code was found');
end-proc;

// With an ID, the check is against rows OTHER than that ID. This is how an
// update screen asks "does another customer already use this code?".
dcl-proc test_CUSDET_exists_excluding_id export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds first  likeds(CUSDET_t) inz(*likeds);
  dcl-ds second likeds(CUSDET_t) inz(*likeds);

  first = build_customer(1);
  second = build_customer(2);
  add_customer(first);
  add_customer(second);

  // first.CODE is still lower case locally; the table holds it upper case
  assert(not CUSDET_exists(%upper(first.CODE): first.ID):
         'A code was reported as used by another row when only its own row has it');
  assert(CUSDET_exists(%upper(first.CODE): second.ID):
         'A code held by the first row was not found when excluding the second');
end-proc;

//==============================================================================
// CUSDET_fetch
//==============================================================================

dcl-proc test_CUSDET_fetch_by_code export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds cust likeds(CUSDET_t) inz(*likeds);
  dcl-ds sel  likeds(CUSDET_fetch_selections_t) inz(*likeds);
  dcl-ds row  likeds(CUSDET_list_t) inz(*likeds);

  cust = build_customer(1);
  add_customer(cust);

  sel.CODE = %upper(cust.CODE);
  assert(not CUSDET_fetch(sel: row): 'CUSDET_fetch reported an error');

  iEqual(cust.ID: row.ID: 'ID');
  assert_text('RMTEST ' + g_run_id + ' 1': row.NAME: 'NAME');
  assert_text('New': row.STATUS_DESCRIPTION: 'STATUS_DESCRIPTION');
end-proc;

dcl-proc test_CUSDET_fetch_by_id export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds first  likeds(CUSDET_t) inz(*likeds);
  dcl-ds second likeds(CUSDET_t) inz(*likeds);
  dcl-ds sel    likeds(CUSDET_fetch_selections_t) inz(*likeds);
  dcl-ds row    likeds(CUSDET_list_t) inz(*likeds);

  first = build_customer(1);
  second = build_customer(2);
  add_customer(first);
  add_customer(second);

  sel.ID = second.ID;
  assert(not CUSDET_fetch(sel: row): 'CUSDET_fetch reported an error');

  iEqual(second.ID: row.ID: 'ID');
  assert_text('RMTEST ' + g_run_id + ' 2': row.NAME: 'NAME');
end-proc;

dcl-proc test_CUSDET_fetch_status_descriptions export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds cust likeds(CUSDET_t) inz(*likeds);
  dcl-ds sel  likeds(CUSDET_fetch_selections_t) inz(*likeds);
  dcl-ds row  likeds(CUSDET_list_t) inz(*likeds);

  cust = build_customer(1);
  add_customer(cust);
  sel.ID = cust.ID;

  cust.STATUS = CUSDET_STATUS_ACTIVE;
  assert(not CUSDET_update(cust): 'Update to Active failed');
  CUSDET_fetch(sel: row);
  assert_text('Active': row.STATUS_DESCRIPTION: 'Active');

  cust.STATUS = CUSDET_STATUS_CLOSED;
  assert(not CUSDET_update(cust): 'Update to Closed failed');
  CUSDET_fetch(sel: row);
  assert_text('Closed': row.STATUS_DESCRIPTION: 'Closed');
end-proc;

//==============================================================================
// CUSDET_list
//==============================================================================

dcl-proc test_CUSDET_list export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(CUSDET_list_selections_t) inz(*likeds);
  dcl-ds c1   likeds(CUSDET_t) inz(*likeds);
  dcl-ds c2   likeds(CUSDET_t) inz(*likeds);
  dcl-ds c3   likeds(CUSDET_t) inz(*likeds);
  dcl-s got_rows like(UNSIGNED_INTEGER_t);

  c1 = build_customer(1);
  c2 = build_customer(2);
  c3 = build_customer(3);
  add_customer(c1);
  add_customer(c2);
  add_customer(c3);

  sel = run_selection();
  calc.req_page = 1;
  calc.req_page_rows = APP_DEFAULT_PAGE_ROWS;

  got_rows = CUSDET_list(calc: sel: g_list);

  iEqual(3: got_rows: 'got_rows');
  iEqual(3: calc.total_rows: 'total_rows');
  iEqual(1: calc.total_pages: 'total_pages');
  iEqual(3: calc.got_rows: 'calc.got_rows');

  // Ordered by ID, which is insertion order
  iEqual(c1.ID: g_list(1).ID: 'row 1 ID');
  iEqual(c2.ID: g_list(2).ID: 'row 2 ID');
  iEqual(c3.ID: g_list(3).ID: 'row 3 ID');
  assert_text(%upper(g_run_id) + '1': %trim(g_list(1).CODE): 'row 1 CODE');
  assert_text(%upper(g_run_id) + '3': %trim(g_list(3).CODE): 'row 3 CODE');
  assert_text('RMTEST ' + g_run_id + ' 2': g_list(2).NAME: 'row 2 NAME');
  assert_text('New': g_list(1).STATUS_DESCRIPTION: 'row 1 STATUS_DESCRIPTION');
end-proc;

dcl-proc test_CUSDET_list_paging export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(CUSDET_list_selections_t) inz(*likeds);
  dcl-ds c1   likeds(CUSDET_t) inz(*likeds);
  dcl-ds c2   likeds(CUSDET_t) inz(*likeds);
  dcl-ds c3   likeds(CUSDET_t) inz(*likeds);
  dcl-s got_rows like(UNSIGNED_INTEGER_t);

  c1 = build_customer(1);
  c2 = build_customer(2);
  c3 = build_customer(3);
  add_customer(c1);
  add_customer(c2);
  add_customer(c3);
  sel = run_selection();

  // Page 1 of 2: two rows
  calc.req_page = 1;
  calc.req_page_rows = 2;
  got_rows = CUSDET_list(calc: sel: g_list);

  iEqual(2: got_rows: 'page 1 got_rows');
  iEqual(3: calc.total_rows: 'page 1 total_rows');
  iEqual(2: calc.total_pages: 'page 1 total_pages');
  iEqual(c1.ID: g_list(1).ID: 'page 1 row 1 ID');
  iEqual(c2.ID: g_list(2).ID: 'page 1 row 2 ID');

  // Page 2 of 2: the remaining row
  clear calc;
  calc.req_page = 2;
  calc.req_page_rows = 2;
  got_rows = CUSDET_list(calc: sel: g_list);

  iEqual(1: got_rows: 'page 2 got_rows');
  iEqual(3: calc.total_rows: 'page 2 total_rows');
  iEqual(c3.ID: g_list(1).ID: 'page 2 row 1 ID');
end-proc;

dcl-proc test_CUSDET_list_search_is_case_insensitive export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(CUSDET_list_selections_t) inz(*likeds);
  dcl-ds cust likeds(CUSDET_t) inz(*likeds);

  cust = build_customer(1);
  add_customer(cust);

  sel.SEARCH = %lower(g_run_id);
  calc.req_page = 1;
  calc.req_page_rows = APP_DEFAULT_PAGE_ROWS;

  iEqual(1: CUSDET_list(calc: sel: g_list): 'got_rows');
  iEqual(cust.ID: g_list(1).ID: 'row 1 ID');
end-proc;

dcl-proc test_CUSDET_list_search_matches_code export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(CUSDET_list_selections_t) inz(*likeds);
  dcl-ds c1   likeds(CUSDET_t) inz(*likeds);
  dcl-ds c2   likeds(CUSDET_t) inz(*likeds);

  c1 = build_customer(1);
  c2 = build_customer(2);
  add_customer(c1);
  add_customer(c2);

  // The full code of customer 1 ends in '1', which no name or other code
  // from this run contains, so only that row can match
  sel.SEARCH = %upper(g_run_id) + '1';
  calc.req_page = 1;
  calc.req_page_rows = APP_DEFAULT_PAGE_ROWS;

  iEqual(1: CUSDET_list(calc: sel: g_list): 'got_rows');
  iEqual(c1.ID: g_list(1).ID: 'row 1 ID');
end-proc;

dcl-proc test_CUSDET_list_filter_by_status export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(CUSDET_list_selections_t) inz(*likeds);
  dcl-ds c1   likeds(CUSDET_t) inz(*likeds);
  dcl-ds c2   likeds(CUSDET_t) inz(*likeds);

  c1 = build_customer(1);
  c2 = build_customer(2);
  c2.STATUS = CUSDET_STATUS_ACTIVE;
  add_customer(c1);
  add_customer(c2);

  sel = run_selection();
  sel.STATUS = CUSDET_STATUS_ACTIVE;
  calc.req_page = 1;
  calc.req_page_rows = APP_DEFAULT_PAGE_ROWS;

  iEqual(1: CUSDET_list(calc: sel: g_list): 'got_rows');
  iEqual(c2.ID: g_list(1).ID: 'row 1 ID');
  assert_text('Active': g_list(1).STATUS_DESCRIPTION: 'STATUS_DESCRIPTION');
end-proc;

dcl-proc test_CUSDET_list_filter_by_code export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(CUSDET_list_selections_t) inz(*likeds);
  dcl-ds c1   likeds(CUSDET_t) inz(*likeds);
  dcl-ds c2   likeds(CUSDET_t) inz(*likeds);

  c1 = build_customer(1);
  c2 = build_customer(2);
  add_customer(c1);
  add_customer(c2);

  sel.CODE = %upper(c2.CODE);
  calc.req_page = 1;
  calc.req_page_rows = APP_DEFAULT_PAGE_ROWS;

  iEqual(1: CUSDET_list(calc: sel: g_list): 'got_rows');
  iEqual(c2.ID: g_list(1).ID: 'row 1 ID');
end-proc;

// Expectation not yet confirmed on the host: with no matching rows,
// APP_calc_page_data returns page_size 0, so CUSDETDL_list issues
// "FETCH ... FOR 0 ROWS". If Db2 rejects that, or SQLERRD(3) is stale, this
// is where it will show.
dcl-proc test_CUSDET_list_no_match export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);
  dcl-ds sel  likeds(CUSDET_list_selections_t) inz(*likeds);

  sel.SEARCH = g_run_id + ' no such customer';
  calc.req_page = 1;
  calc.req_page_rows = APP_DEFAULT_PAGE_ROWS;

  iEqual(0: CUSDET_list(calc: sel: g_list): 'got_rows');
  iEqual(0: calc.total_rows: 'total_rows');
  iEqual(0: calc.total_pages: 'total_pages');
end-proc;
