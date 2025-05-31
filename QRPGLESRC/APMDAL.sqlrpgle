**free

//==============================================================================
// APMDAL     - Application Messages DAL Module
//
// NOTE: APMDAL must not use EMBSQL. EMBSQL_error or EMBSQL_found as
//   these procedures themselves call APMDAL (via APMSAL) and this
//   recursion can corrupt the global g_sql_state and g_sql_code values.
//
// 07/04/2021 - RM - created
//==============================================================================

/define APP_SERVICE_PROGRAM
/include 'QCPYSRC/APP_H.rpgleinc'

//==============================================================================
// Define global data structures
//==============================================================================

dcl-s g_error like(t_BOOLEAN);
dcl-s g_found like(t_BOOLEAN);
dcl-s g_first_message like(t_BOOLEAN);
dcl-s g_first_message_id like(t_INTEGER);

//==============================================================================
// Copybook definitions
//==============================================================================

/include 'QCPYSRC/APP_D.rpgleinc'
/include 'QCPYSRC/APMDAL_D.rpgleinc'
/include 'QCPYSRC/CALLER_D.rpgleinc'
/include 'QCPYSRC/RMAPP_D.rpgleinc'
/include 'QCPYSRC/RMEMBSQL_D.rpgleinc'

//==============================================================================
// Copybook procedures
//==============================================================================

/include 'QCPYSRC/CALLER_P.rpgleinc'
/include 'QCPYSRC/RMEMBSQL_P.rpgleinc'

//==============================================================================
// APMDAL_first_message
//   Getter and setter for the first_message global field
//==============================================================================

dcl-proc APMDAL_first_message export;
  dcl-pi *n like(t_BOOLEAN);
    first_message like(t_BOOLEAN) options(*nopass) const;
  end-pi;

  if %parms() >= %parmnum(first_message);
    g_first_message = first_message;
  endif;

  return g_first_message;
end-proc;

//==============================================================================
// APMDAL_first_message_id
//   Getter and setter for the first_message_id global field
//==============================================================================

dcl-proc APMDAL_first_message_id export;
  dcl-pi *n like(t_INTEGER);
    first_message_id like(t_INTEGER) options(*nopass) const;
  end-pi;

  if %parms() >= %parmnum(first_message_id);
    g_first_message_id = first_message_id;
    APMDAL_first_message(false);
  endif;

  return g_first_message_id;
end-proc;

//==============================================================================
// APMDAL_add
//   Data access layer add procedure for view APPMSGVP
//==============================================================================

dcl-proc APMDAL_add export;
  dcl-pi *n like(t_BOOLEAN);
    data likeds(APMDAL_t);
  end-pi;

  dcl-ds caller likeds(CALLER_T) inz(*likeds);

  caller = retrieve_caller();

  data.JOB_NAME = APP_job_full_name();
  if data.CREATED_BY_PROCESS = '';
    data.CREATED_BY_PROCESS = '*UNKNOWN';
  endif;
  data.CREATED_BY_PGM = caller.pgm_name;
  data.CREATED_BY_PRC = caller.proc_name;
  data.CREATED_BY_USER = APP_user();
  data.CREATED_TIMESTAMP = APP_timestamp();

  exec sql
    INSERT INTO APPMSGVP
      ( JOB_NAME,
        FIELD_NAME,
        TYPE,
        TEXT,
        CREATED_BY_PROCESS,
        CREATED_BY_PGM,
        CREATED_BY_PRC,
        CREATED_BY_USER,
        CREATED_TIMESTAMP )
      VALUES( :data.JOB_NAME,
              :data.FIELD_NAME,
              :data.TYPE,
              :data.TEXT,
              :data.CREATED_BY_PROCESS,
              :data.CREATED_BY_PGM,
              :data.CREATED_BY_PRC,
              :data.CREATED_BY_USER,
              :data.CREATED_TIMESTAMP );
  set_error();

  exec sql VALUES IDENTITY_VAL_LOCAL() INTO :data.ID;

  if not get_error() and APMDAL_first_message();
    APMDAL_first_message_id(data.ID);
  endif;

  return get_error();
end-proc;

//==============================================================================
// APMDAL_get
//   Data access layer get procedure for view APPMSGVP
//==============================================================================

dcl-proc APMDAL_get export;
  dcl-pi *n like(t_BOOLEAN);
    data likeds(APMDAL_t);
  end-pi;

  exec sql
    SELECT
      ID,
      JOB_NAME,
      FIELD_NAME,
      TYPE,
      TEXT,
      CREATED_BY_PROCESS,
      CREATED_BY_PGM,
      CREATED_BY_PRC,
      CREATED_BY_USER,
      CREATED_TIMESTAMP
    INTO
      :data
    FROM
      APPMSGVP
    WHERE
      ID = :data.ID
    FETCH FIRST ROW ONLY;
  set_error();
  set_found();

  return get_error();
end-proc;

//==============================================================================
// APMDAL_update
//   Data access layer update procedure for view APPMSGVP
//==============================================================================

dcl-proc APMDAL_update export;
  dcl-pi *n like(t_BOOLEAN);
    data likeds(APMDAL_t);
  end-pi;

  exec sql
    UPDATE
      APPMSGVP
    SET
      JOB_NAME = :data.JOB_NAME,
      FIELD_NAME = :data.FIELD_NAME,
      TYPE = :data.TYPE,
      TEXT = :data.TEXT
    WHERE
      ID = :data.ID;
  set_error();

  return get_error();
end-proc;

//==============================================================================
// APMDAL_delete
//   Data access layer delete procedure for view APPMSGVP
//==============================================================================

dcl-proc APMDAL_delete export;
  dcl-pi *n like(t_BOOLEAN);
    data likeds(APMDAL_t);
  end-pi;

  exec sql
    DELETE FROM
      APPMSGVP
    WHERE
      ID = :data.ID;
  set_error();
  set_found();

  return get_error();
end-proc;

//==============================================================================
// APMDAL_delete_by_session_id
//   Data access layer delete procedure for view APPMSGVP
//==============================================================================

dcl-proc APMDAL_delete_by_session_id export;
  dcl-pi *n like(t_BOOLEAN);
    data likeds(APMDAL_t);
  end-pi;

  exec sql
    DELETE FROM
      APPMSGVP
    WHERE
      JOB_NAME = :data.JOB_NAME;
  set_error();
  set_found();

  return get_error();
end-proc;

//==============================================================================
// APMDAL_list
//   Data access layer list procedure for view APPMSGVL
//   - Always returns messages from the first_message_id
//==============================================================================

dcl-proc APMDAL_list export;
  dcl-pi *n like(t_UNSIGNED_INTEGER);
    calc likeds(APP_paging_t);
    sel  likeds(APMDAL_list_selections_t) const;
    data likeds(APMDAL_list_t) dim(APP_MAXIMUM_PAGE_ROWS);
  end-pi;

  dcl-s page_size  like(t_INTEGER) inz(APP_MAXIMUM_PAGE_ROWS);
  dcl-s row_offset like(t_INTEGER) inz(1);
  dcl-s got_rows   like(t_UNSIGNED_INTEGER);

  exec SQL
    DECLARE list_cursor INSENSITIVE SCROLL CURSOR FOR
      SELECT
        ID,
        JOB_NAME,
        FIELD_NAME,
        TYPE,
        TEXT,
        CREATED_BY_PROCESS,
        CREATED_BY_PGM,
        CREATED_BY_PRC,
        CREATED_BY_USER,
        CREATED_TIMESTAMP
      FROM
        APPMSGVL
      WHERE
        ( :g_first_message = '0' AND ID >= :g_first_message_id )
           AND
        JOB_NAME = :sel.JOB_NAME
           AND
        ( :sel.TYPE = '' OR :sel.TYPE = TYPE )
      ORDER BY
        ID DESC
      FOR READ ONLY;

  exec SQL
    open list_cursor;

  exec SQL
    get diagnostics :calc.total_rows = DB2_NUMBER_ROWS;

  APP_calc_page_data(calc: page_size: row_offset);

  exec SQL
    fetch relative :row_offset from list_cursor
      for :page_size rows into :data;
  set_error();

  got_rows = SQLERRD(3);
  calc.got_rows = got_rows;

  exec SQL
    close list_cursor;

  return got_rows;
end-proc;

//==============================================================================
// APMDAL_error
//   Returns the error state from the last SQL command
//==============================================================================

dcl-proc APMDAL_error export;
  dcl-pi *n like(t_BOOLEAN) end-pi;

  return get_error();
end-proc;

//==============================================================================
// APMDAL_found
//   Returns the found state from the last _get procedure
//==============================================================================

dcl-proc APMDAL_found export;
  dcl-pi *n like(t_BOOLEAN) end-pi;

  return get_found();
end-proc;

//==============================================================================
// APMDAL_open
//   Data access layer open cursor procedure for view APPMSGVP
//   - Selections on the passed JOB_NAME and the optionally passed FIELD_NAME
//     and TYPE field values
//   - Always returns messages from the first_message_id
//==============================================================================

dcl-proc APMDAL_open export;
  dcl-pi *n like(t_BOOLEAN);
    sel likeds(APMDAL_open_selections_t) const;
  end-pi;

  exec sql
    DECLARE fetch_cursor CURSOR FOR
      SELECT
        ID,
        JOB_NAME,
        FIELD_NAME,
        TYPE,
        TEXT,
        CREATED_BY_PROCESS,
        CREATED_BY_PGM,
        CREATED_BY_PRC,
        CREATED_BY_USER,
        CREATED_TIMESTAMP
      FROM
        APPMSGVP
      WHERE
        ( :g_first_message = '0' AND ID >= :g_first_message_id )
           AND
        JOB_NAME = :sel.JOB_NAME
           AND
        ( :sel.FIELD_NAME = '' OR :sel.FIELD_NAME = FIELD_NAME )
           AND
        ( :sel.TYPE = '' OR :sel.TYPE = TYPE )
      ORDER BY
        CREATED_TIMESTAMP,
        ID;

  exec sql OPEN fetch_cursor;
  set_error();

  return get_error();
end-proc;

//==============================================================================
// APMDAL_fetch
//   Data access layer fetch cursor procedure for view APPMSGVP
//   - The return boolean specifies whether the fetch was successful
//==============================================================================

dcl-proc APMDAL_fetch export;
  dcl-pi *n like(t_BOOLEAN);
    data likeds(APMDAL_t);
  end-pi;

  exec sql FETCH fetch_cursor INTO :data;
  set_error();
  set_found();

  return get_found();
end-proc;

//==============================================================================
// APMDAL_close
//   Data access layer close cursor procedure for view APPMSGVP
//==============================================================================

dcl-proc APMDAL_close export;
  dcl-pi *n like(t_BOOLEAN) end-pi;

  exec sql CLOSE fetch_cursor;
  set_error();

  return get_error();
end-proc;

//==============================================================================
// APMDAL_open_desc
//   Data access layer open_desc cursor procedure for view APPMSGVP
//   - Selections on the passed JOB_NAME and the optionally passed FIELD_NAME
//     and TYPE field values
//   - Performs an ORDER BY CREATED_TIMESTAMP DESC
//   - Always returns messages from the first_message_id
//==============================================================================

dcl-proc APMDAL_open_desc export;
  dcl-pi *n like(t_BOOLEAN);
    sel likeds(APMDAL_open_selections_t) const;
  end-pi;

  exec sql
    DECLARE fetch_desc_cursor CURSOR FOR
      SELECT
        ID,
        JOB_NAME,
        FIELD_NAME,
        TYPE,
        TEXT,
        CREATED_BY_PROCESS,
        CREATED_BY_PGM,
        CREATED_BY_PRC,
        CREATED_BY_USER,
        CREATED_TIMESTAMP
      FROM
        APPMSGVP
      WHERE
        ( :g_first_message = '0' AND ID >= :g_first_message_id )
           AND
        JOB_NAME = :sel.JOB_NAME
           AND
        ( :sel.FIELD_NAME = '' OR :sel.FIELD_NAME = FIELD_NAME )
           AND
        ( :sel.TYPE = '' OR :sel.TYPE = TYPE )
      ORDER BY
        CREATED_TIMESTAMP DESC,
        ID DESC;

  exec sql OPEN fetch_desc_cursor;
  set_error();

  return get_error();
end-proc;

//==============================================================================
// APMDAL_fetch_desc
//   Data access layer fetch_desc cursor procedure for view APPMSGVP
//   - The return boolean specifies whether the fetch was successful
//==============================================================================

dcl-proc APMDAL_fetch_desc export;
  dcl-pi *n like(t_BOOLEAN);
    data likeds(APMDAL_t);
  end-pi;

  exec sql FETCH fetch_desc_cursor INTO :data;
  set_error();
  set_found();

  return get_found();
end-proc;

//==============================================================================
// APMDAL_close_desc
//   Data access layer close_desc cursor procedure for view APPMSGVP
//==============================================================================

dcl-proc APMDAL_close_desc export;
  dcl-pi *n like(t_BOOLEAN) end-pi;

  exec sql CLOSE fetch_desc_cursor;
  set_error();

  return get_error();
end-proc;

//==============================================================================
// set_error
//   Sets the global error state for the SQL command
//   - This logic has been taken from EMBSQL, which cannot be referenced
//==============================================================================

dcl-proc set_error export;
  dcl-pi *n end-pi;

  select;
  when %subst(sqlstate:1:2) = '00'; // Class Code 00: Unqualified Successful Completion
    g_error = false;
  when %subst(sqlstate:1:2) = '01'; // Class Code 01: Warning
    g_error = false;
  when %subst(sqlstate:1:2) = '02'; // Class Code 02: No Data
    g_error = false;
  other;
    g_error = true;
  endsl;

  return;
end-proc;

//==============================================================================
// get_error
//   Returns the global error state
//==============================================================================

dcl-proc get_error export;
  dcl-pi *n like(t_BOOLEAN) end-pi;

  return g_error;
end-proc;

//==============================================================================
// set_found
//   Sets the global found state for the SQL command
//   - This logic has been taken from EMBSQL, which cannot be referenced
//==============================================================================

dcl-proc set_found export;
  dcl-pi *n end-pi;

  if not get_error()
    and ( sqlstate <> '02000' or sqlcode <> 100);
    g_found = true;
  else;
    g_found = false;
  endif;

  return;
end-proc;

//==============================================================================
// get_found
//   Returns the global found state
//==============================================================================

dcl-proc get_found export;
  dcl-pi *n like(t_BOOLEAN) end-pi;

  return g_found;
end-proc;
