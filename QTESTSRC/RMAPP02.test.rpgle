**free

//==============================================================================
// RMAPP02.TEST - Unit tests for RMAPP02 (Application Helper - DAL Module)
//
// Object name is TRMAPP02 (strip .TEST, prefix T).
//
// These are true unit tests: APP_calc_page_data and the APP_where_add_*
// procedures are pure functions with no database, IFS or job dependencies, so
// no setUp/tearDown is needed.
//
// Tests marked RED document a defect in RMAPP02 and are expected to fail until
// the module is fixed.
//
// 29/10/2026 - RM - created
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
//
// aEqual is not used because it is declared char(32565) and so rejects the
// varchar(32740) that STRING_SQL_t returns.
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
// Run APP_calc_page_data for the given inputs.
///

dcl-proc calc_page;
  dcl-pi *n;
    req_page      like(INTEGER_t) const;
    req_page_rows like(INTEGER_t) const;
    total_rows    like(INTEGER_t) const;
    total_pages   like(INTEGER_t);
    page_size     like(INTEGER_t);
    row_offset    like(INTEGER_t);
  end-pi;

  dcl-ds calc likeds(APP_paging_t) inz(*likeds);

  calc.req_page = req_page;
  calc.req_page_rows = req_page_rows;
  calc.total_rows = total_rows;

  APP_calc_page_data(calc: page_size: row_offset);

  total_pages = calc.total_pages;
end-proc;

//==============================================================================
// APP_calc_page_data
//==============================================================================

dcl-proc test_APP_calc_page_data_first_page export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s total_pages like(INTEGER_t);
  dcl-s page_size   like(INTEGER_t);
  dcl-s row_offset  like(INTEGER_t);

  calc_page(1: 10: 25: total_pages: page_size: row_offset);

  iEqual(3: total_pages: 'total_pages');
  iEqual(1: row_offset: 'row_offset');
  iEqual(10: page_size: 'page_size');
end-proc;

dcl-proc test_APP_calc_page_data_middle_page export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s total_pages like(INTEGER_t);
  dcl-s page_size   like(INTEGER_t);
  dcl-s row_offset  like(INTEGER_t);

  calc_page(2: 10: 25: total_pages: page_size: row_offset);

  iEqual(3: total_pages: 'total_pages');
  iEqual(11: row_offset: 'row_offset');
  iEqual(10: page_size: 'page_size');
end-proc;

dcl-proc test_APP_calc_page_data_last_partial_page export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s total_pages like(INTEGER_t);
  dcl-s page_size   like(INTEGER_t);
  dcl-s row_offset  like(INTEGER_t);

  calc_page(3: 10: 25: total_pages: page_size: row_offset);

  iEqual(3: total_pages: 'total_pages');
  iEqual(21: row_offset: 'row_offset');
  iEqual(5: page_size: 'page_size');
end-proc;

dcl-proc test_APP_calc_page_data_exact_multiple export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s total_pages like(INTEGER_t);
  dcl-s page_size   like(INTEGER_t);
  dcl-s row_offset  like(INTEGER_t);

  // 20 rows at 10 per page is exactly 2 pages, not 3
  calc_page(2: 10: 20: total_pages: page_size: row_offset);

  iEqual(2: total_pages: 'total_pages');
  iEqual(11: row_offset: 'row_offset');
  iEqual(10: page_size: 'page_size');
end-proc;

dcl-proc test_APP_calc_page_data_fewer_rows_than_page export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s total_pages like(INTEGER_t);
  dcl-s page_size   like(INTEGER_t);
  dcl-s row_offset  like(INTEGER_t);

  calc_page(1: 10: 5: total_pages: page_size: row_offset);

  iEqual(1: total_pages: 'total_pages');
  iEqual(1: row_offset: 'row_offset');
  iEqual(5: page_size: 'page_size');
end-proc;

dcl-proc test_APP_calc_page_data_single_row export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s total_pages like(INTEGER_t);
  dcl-s page_size   like(INTEGER_t);
  dcl-s row_offset  like(INTEGER_t);

  calc_page(1: 10: 1: total_pages: page_size: row_offset);

  iEqual(1: total_pages: 'total_pages');
  iEqual(1: row_offset: 'row_offset');
  iEqual(1: page_size: 'page_size');
end-proc;

dcl-proc test_APP_calc_page_data_no_rows export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s total_pages like(INTEGER_t);
  dcl-s page_size   like(INTEGER_t);
  dcl-s row_offset  like(INTEGER_t);

  calc_page(1: 10: 0: total_pages: page_size: row_offset);

  iEqual(0: total_pages: 'total_pages');
  iEqual(0: row_offset: 'row_offset');
  iEqual(0: page_size: 'page_size');
end-proc;

dcl-proc test_APP_calc_page_data_invalid_page export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s total_pages like(INTEGER_t);
  dcl-s page_size   like(INTEGER_t);
  dcl-s row_offset  like(INTEGER_t);

  calc_page(0: 10: 25: total_pages: page_size: row_offset);
  iEqual(0: total_pages: 'page 0 total_pages');
  iEqual(0: row_offset: 'page 0 row_offset');
  iEqual(0: page_size: 'page 0 page_size');

  calc_page(-1: 10: 25: total_pages: page_size: row_offset);
  iEqual(0: total_pages: 'page -1 total_pages');
  iEqual(0: row_offset: 'page -1 row_offset');
  iEqual(0: page_size: 'page -1 page_size');
end-proc;

dcl-proc test_APP_calc_page_data_invalid_page_rows export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s total_pages like(INTEGER_t);
  dcl-s page_size   like(INTEGER_t);
  dcl-s row_offset  like(INTEGER_t);

  // Zero rows per page must not divide by zero
  calc_page(1: 0: 25: total_pages: page_size: row_offset);
  iEqual(0: total_pages: 'rows 0 total_pages');
  iEqual(0: row_offset: 'rows 0 row_offset');
  iEqual(0: page_size: 'rows 0 page_size');

  calc_page(1: -10: 25: total_pages: page_size: row_offset);
  iEqual(0: total_pages: 'rows -10 total_pages');
  iEqual(0: row_offset: 'rows -10 row_offset');
  iEqual(0: page_size: 'rows -10 page_size');
end-proc;

dcl-proc test_APP_calc_page_data_page_beyond_end export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s total_pages like(INTEGER_t);
  dcl-s page_size   like(INTEGER_t);
  dcl-s row_offset  like(INTEGER_t);

  // Page 4 of a 3 page result: nothing to return
  calc_page(4: 10: 25: total_pages: page_size: row_offset);

  iEqual(3: total_pages: 'total_pages');
  iEqual(0: row_offset: 'row_offset');
  iEqual(0: page_size: 'page_size');
end-proc;

// RED: with a single page of results, asking for page 2 yields row_offset 0
// but page_size 6 (total_rows + 1) instead of 0. The (total_rows - row_offset)
// + 1 branch runs with the reset row_offset. It is only guarded by
// "page_size > req_page_rows", which a short result does not trip.
// CUSDETDL_list would then fetch 6 rows relative 0.
// Fix: treat "row_offset reset to 0" as out of range and set page_size = 0.
dcl-proc test_APP_calc_page_data_page_beyond_end_single_page export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s total_pages like(INTEGER_t);
  dcl-s page_size   like(INTEGER_t);
  dcl-s row_offset  like(INTEGER_t);

  calc_page(2: 10: 5: total_pages: page_size: row_offset);

  iEqual(1: total_pages: 'total_pages');
  iEqual(0: row_offset: 'row_offset');
  iEqual(0: page_size: 'page_size');
end-proc;

//==============================================================================
// APP_where_add_string
//==============================================================================

dcl-proc test_APP_where_add_string export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_string('NAME': 'ABC': selections);

  assert_text('WHERE NAME = ''ABC''': clause: 'clause');
  iEqual(1: selections: 'selections');
end-proc;

dcl-proc test_APP_where_add_string_second_selection export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_string('NAME': 'ABC': selections);
  clause += APP_where_add_string('CODE': 'XYZ': selections);

  assert_text('WHERE NAME = ''ABC'' AND CODE = ''XYZ''': clause: 'clause');
  iEqual(2: selections: 'selections');
end-proc;

dcl-proc test_APP_where_add_string_empty_value export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_string('NAME': '': selections);

  assert_text('': clause: 'clause');
  iEqual(0: selections: 'selections');
end-proc;

dcl-proc test_APP_where_add_string_no_quotes export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_string('QTY': '5': selections: false);

  assert_text('WHERE QTY = 5': clause: 'clause');
  iEqual(1: selections: 'selections');
end-proc;

dcl-proc test_APP_where_add_string_wrap_in_quotes_true export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_string('NAME': 'ABC': selections: true);

  assert_text('WHERE NAME = ''ABC''': clause: 'clause');
end-proc;

// RED: a single quote in the value is not doubled, so the clause is broken
// SQL (and an injection vector). RMAPP02.rpgle:APP_where_add_string,
// APP_where_add_starts_with and APP_where_add_contains all concatenate the
// value unescaped. Fix: %scanrpl('''': '''''': field_value) before building
// the selection text.
dcl-proc test_APP_where_add_string_escapes_quote export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_string('NAME': 'O''BRIEN': selections);

  assert_text('WHERE NAME = ''O''''BRIEN''': clause: 'clause');
end-proc;

//==============================================================================
// APP_where_add_integer
//==============================================================================

// Note the value is wrapped in quotes ('30'), which differs from the example
// in the procedure's doc comment (DUE_DAYS = 30). Db2 casts it implicitly, so
// this pins the behaviour as it is today.
dcl-proc test_APP_where_add_integer export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_integer('DUE_DAYS': 30: selections);

  assert_text('WHERE DUE_DAYS = ''30''': clause: 'clause');
  iEqual(1: selections: 'selections');
end-proc;

dcl-proc test_APP_where_add_integer_negative export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_integer('BALANCE': -5: selections);

  assert_text('WHERE BALANCE = ''-5''': clause: 'clause');
end-proc;

dcl-proc test_APP_where_add_integer_zero export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_integer('DUE_DAYS': 0: selections);

  assert_text('': clause: 'clause');
  iEqual(0: selections: 'selections');
end-proc;

//==============================================================================
// APP_where_add_starts_with
//==============================================================================

dcl-proc test_APP_where_add_starts_with export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_starts_with('NAME': 'ABC': selections);

  assert_text('WHERE NAME LIKE ''ABC%''': clause: 'clause');
  iEqual(1: selections: 'selections');
end-proc;

dcl-proc test_APP_where_add_starts_with_empty_value export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_starts_with('NAME': '': selections);

  assert_text('': clause: 'clause');
  iEqual(0: selections: 'selections');
end-proc;

//==============================================================================
// APP_where_add_contains
//==============================================================================

dcl-proc test_APP_where_add_contains export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_contains('NAME': 'AbC': selections);

  // Column and value are both lower-cased
  assert_text('WHERE LOWER(NAME) LIKE ''%abc%''': clause: 'clause');
  iEqual(1: selections: 'selections');
end-proc;

dcl-proc test_APP_where_add_contains_empty_value export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_contains('NAME': '': selections);

  assert_text('': clause: 'clause');
  iEqual(0: selections: 'selections');
end-proc;

//==============================================================================
// APP_where_add_date_range
//==============================================================================

dcl-proc test_APP_where_add_date_range export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_date_range('DUE_DATE': d'2023-09-01': d'2023-09-30':
                                    selections);

  assert_text('WHERE DUE_DATE >= ''2023-09-01'' AND DUE_DATE <= ''2023-09-30'''
             : clause: 'clause');
  iEqual(2: selections: 'selections');
end-proc;

dcl-proc test_APP_where_add_date_range_exclusive export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_date_range('DUE_DATE': d'2023-09-01': d'2023-09-30':
                                    selections: false);

  assert_text('WHERE DUE_DATE > ''2023-09-01'' AND DUE_DATE < ''2023-09-30'''
             : clause: 'clause');
  iEqual(2: selections: 'selections');
end-proc;

dcl-proc test_APP_where_add_date_range_from_only export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_date_range('DUE_DATE': d'2023-09-01': EMPTY_DATE:
                                    selections);

  assert_text('WHERE DUE_DATE >= ''2023-09-01''': clause: 'clause');
  iEqual(1: selections: 'selections');
end-proc;

dcl-proc test_APP_where_add_date_range_to_only export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_date_range('DUE_DATE': EMPTY_DATE: d'2023-09-30':
                                    selections);

  assert_text('WHERE DUE_DATE <= ''2023-09-30''': clause: 'clause');
  iEqual(1: selections: 'selections');
end-proc;

dcl-proc test_APP_where_add_date_range_both_empty export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_date_range('DUE_DATE': EMPTY_DATE: EMPTY_DATE:
                                    selections);

  assert_text('': clause: 'clause');
  iEqual(0: selections: 'selections');
end-proc;

//==============================================================================
// APP_where_add_integer_range
//==============================================================================

dcl-proc test_APP_where_add_integer_range export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_integer_range('PRIORITY': 30: 40: selections);

  assert_text('WHERE PRIORITY >= 30 AND PRIORITY <= 40': clause: 'clause');
  iEqual(2: selections: 'selections');
end-proc;

dcl-proc test_APP_where_add_integer_range_exclusive export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_integer_range('PRIORITY': 30: 40: selections: false);

  assert_text('WHERE PRIORITY > 30 AND PRIORITY < 40': clause: 'clause');
  iEqual(2: selections: 'selections');
end-proc;

dcl-proc test_APP_where_add_integer_range_from_only export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_integer_range('PRIORITY': 30: 0: selections);

  assert_text('WHERE PRIORITY >= 30': clause: 'clause');
  iEqual(1: selections: 'selections');
end-proc;

dcl-proc test_APP_where_add_integer_range_to_only export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_integer_range('PRIORITY': 0: 40: selections);

  assert_text('WHERE PRIORITY <= 40': clause: 'clause');
  iEqual(1: selections: 'selections');
end-proc;

dcl-proc test_APP_where_add_integer_range_both_zero export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_integer_range('PRIORITY': 0: 0: selections);

  assert_text('': clause: 'clause');
  iEqual(0: selections: 'selections');
end-proc;

//==============================================================================
// APP_where_add_in_list
//==============================================================================

dcl-proc test_APP_where_add_in_list export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_in_list('STOCK_POINT': '''ND'',''N2''': selections);

  assert_text('WHERE STOCK_POINT IN (''ND'',''N2'')': clause: 'clause');
  iEqual(1: selections: 'selections');
end-proc;

dcl-proc test_APP_where_add_in_list_empty_value export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_in_list('STOCK_POINT': '': selections);

  assert_text('': clause: 'clause');
  iEqual(0: selections: 'selections');
end-proc;

//==============================================================================
// Combining selections
//==============================================================================

// The WHERE / AND keyword depends on the shared selections counter, which is
// how a caller chains different kinds of selection into one clause.
dcl-proc test_APP_where_add_chained export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add_string('CODE': 'ABC': selections);
  clause += APP_where_add_string('NAME': '': selections);      // skipped
  clause += APP_where_add_integer('DUE_DAYS': 30: selections);
  clause += APP_where_add_contains('NAME': 'Smith': selections);
  clause += APP_where_add_integer_range('PRIORITY': 1: 5: selections);

  assert_text('WHERE CODE = ''ABC'' AND DUE_DAYS = ''30'''
            + ' AND LOWER(NAME) LIKE ''%smith%'''
            + ' AND PRIORITY >= 1 AND PRIORITY <= 5'
             : clause: 'clause');
  iEqual(5: selections: 'selections');
end-proc;

// The APP_where_add overload group resolves to the same procedures
dcl-proc test_APP_where_add_overload export;
  dcl-pi *n extproc(*dclcase) end-pi;

  dcl-s clause varchar(1024);
  dcl-s selections like(SMALLINT_t);

  selections = 0;
  clause = APP_where_add('NAME': 'ABC': selections);
  clause += APP_where_add('QTY': 5: selections);

  assert_text('WHERE NAME = ''ABC'' AND QTY = ''5''': clause: 'clause');
  iEqual(2: selections: 'selections');
end-proc;
