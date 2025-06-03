**free

//==============================================================================
// CUSDETDL   - Customer Details DAL Module
//
// 07/04/2021 - RM - created
//==============================================================================

/define APP_SERVICE_PROGRAM
/include 'QCPYSRC/APP_H.rpgleinc'

//==============================================================================
// Define global data structures
//==============================================================================

dcl-ds g_state likeds(EMBSQL_state_t) inz;

//==============================================================================
// Copybook definitions
//==============================================================================

/include 'QCPYSRC/APP_D.rpgleinc'
/include 'QCPYSRC/CUSDETDL_D.rpgleinc'
/include 'QCPYSRC/RMAPP_D.rpgleinc'
/include 'QCPYSRC/RMEMBSQL_D.rpgleinc'

//==============================================================================
// Copybook procedures
//==============================================================================

/include 'QCPYSRC/RMEMBSQL_P.rpgleinc'

//==============================================================================
// CUSDETDL_add
//   Data access layer add procedure
//==============================================================================

dcl-proc CUSDETDL_add export;
  dcl-pi *n like(BOOLEAN_t);
    data likeds(CUSDET_t);
  end-pi;

  data.CREATED_BY_USER = %trimr(APP_user());
  data.CREATED_TIMESTAMP = APP_timestamp();

  exec sql
    INSERT INTO CUSDETVP
      ( CODE,
        STATUS,
        NAME,
        ADDRESS_LINE1,
        ADDRESS_LINE2,
        ADDRESS_LINE3,
        ADDRESS_LINE4,
        POSTCODE,
        CONTACT_NAME,
        CONTACT_TELP,
        CONTACT_EMAIL,
        VAT_CODE,
        CURRENCY,
        CREDIT_LIMIT,
        CURRENT_BALANCE,
        COMMENTS,
        CREATED_BY_USER,
        CREATED_TIMESTAMP )
      VALUES( UPPER(:data.CODE),
              UPPER(:data.STATUS),
              :data.NAME,
              :data.ADDRESS_LINE1,
              :data.ADDRESS_LINE2,
              :data.ADDRESS_LINE3,
              :data.ADDRESS_LINE4,
              :data.POSTCODE,
              :data.CONTACT_NAME,
              :data.CONTACT_TELP,
              :data.CONTACT_EMAIL,
              UPPER(:data.VAT_CODE),
              UPPER(:data.CURRENCY),
              :data.CREDIT_LIMIT,
              :data.CURRENT_BALANCE,
              :data.COMMENTS,
              :data.CREATED_BY_USER,
              :data.CREATED_TIMESTAMP );

  g_state = EMBSQL_state();

  if not g_state.error;
    exec sql VALUES IDENTITY_VAL_LOCAL() INTO :data.ID;
  endif;

  return g_state.error;
end-proc;

//==============================================================================
// CUSDETDL_get
//   Data access layer get procedure
//==============================================================================

dcl-proc CUSDETDL_get export;
  dcl-pi *n like(BOOLEAN_t);
    data likeds(CUSDET_t);
  end-pi;

  exec sql
    SELECT
      ID,
      CODE,
      STATUS,
      NAME,
      ADDRESS_LINE1,
      ADDRESS_LINE2,
      ADDRESS_LINE3,
      ADDRESS_LINE4,
      POSTCODE,
      CONTACT_NAME,
      CONTACT_TELP,
      CONTACT_EMAIL,
      VAT_CODE,
      CURRENCY,
      CREDIT_LIMIT,
      CURRENT_BALANCE,
      COMMENTS,
      CREATED_BY_USER,
      CREATED_TIMESTAMP
      // AUDIT_TYPE_CHANGE,
      // AUDIT_USER,
      // AUDIT_CLIENT_IP,
      // AUDIT_JOB_NAME,
      // AUDIT_TIME
    INTO
      :data
    FROM
      CUSDETVP
    WHERE
      :data.ID = ID
    FETCH FIRST ROW ONLY;

  g_state = EMBSQL_state();

  return g_state.found;
end-proc;

//==============================================================================
// CUSDETDL_update
//   Data access layer update procedure
//==============================================================================

dcl-proc CUSDETDL_update export;
  dcl-pi *n like(BOOLEAN_t);
    data likeds(CUSDET_t);
  end-pi;

  exec sql
    UPDATE
      CUSDETVP
    SET
      CODE            = UPPER(:data.CODE),
      STATUS          = UPPER(:data.STATUS),
      NAME            = :data.NAME,
      ADDRESS_LINE1   = :data.ADDRESS_LINE1,
      ADDRESS_LINE2   = :data.ADDRESS_LINE2,
      ADDRESS_LINE3   = :data.ADDRESS_LINE3,
      ADDRESS_LINE4   = :data.ADDRESS_LINE4,
      POSTCODE        = :data.POSTCODE,
      CONTACT_NAME    = :data.CONTACT_NAME,
      CONTACT_TELP    = :data.CONTACT_TELP,
      CONTACT_EMAIL   = :data.CONTACT_EMAIL,
      VAT_CODE        = UPPER(:data.VAT_CODE),
      CURRENCY        = UPPER(:data.CURRENCY),
      CREDIT_LIMIT    = :data.CREDIT_LIMIT,
      CURRENT_BALANCE = :data.CURRENT_BALANCE,
      COMMENTS        = :data.COMMENTS
    WHERE
      ID = :data.ID;

  g_state = EMBSQL_state();

  return g_state.error;
end-proc;

//==============================================================================
// CUSDETDL_delete
//   Data access layer delete procedure
//==============================================================================

dcl-proc CUSDETDL_delete export;
  dcl-pi *n like(BOOLEAN_t);
    data likeds(CUSDET_t);
  end-pi;

  exec sql
    DELETE FROM
      CUSDETVP
    WHERE
      ID = :data.ID;

  g_state = EMBSQL_state();

  return g_state.error;
end-proc;

//==============================================================================
// CUSDETDL_list
//   Data access layer list procedure
//==============================================================================

dcl-proc CUSDETDL_list export;
  dcl-pi *n like(UNSIGNED_INTEGER_t);
    calc likeds(APP_paging_t);
    sel  likeds(CUSDET_list_selections_t) const;
    data likeds(CUSDET_list_t) dim(APP_MAXIMUM_PAGE_ROWS);
  end-pi;

  dcl-s page_size  like(INTEGER_t);
  dcl-s row_offset like(INTEGER_t);
  dcl-s got_rows   like(UNSIGNED_INTEGER_t);
  dcl-s l_search   like(CUSDET_NAME_t);

  l_search = %trim(sel.SEARCH);
  if l_search <> '';
    l_search = '%' + l_search + '%';
  endif;

  exec SQL
    DECLARE list_cursor INSENSITIVE SCROLL CURSOR FOR
      SELECT
        ID,
        CODE,
        STATUS,
        STATUS_DESCRIPTION,
        NAME,
        ADDRESS_LINE1,
        ADDRESS_LINE2,
        ADDRESS_LINE3,
        ADDRESS_LINE4,
        POSTCODE,
        CONTACT_NAME,
        CONTACT_TELP,
        CONTACT_EMAIL,
        VAT_CODE,
        CURRENCY,
        CREDIT_LIMIT,
        CURRENT_BALANCE,
        COMMENTS
      FROM
        CUSDETVL
      WHERE
        ( :sel.CODE = '' OR :sel.CODE = CODE )
           AND
        ( :sel.STATUS = '' OR :sel.STATUS = STATUS )
           AND
        ( :sel.NAME = '' OR :sel.NAME = NAME )
           AND
        ( :l_search = '' OR (
            UPPER(CODE) LIKE UPPER(:l_search)
              OR
            UPPER(NAME) LIKE UPPER(:l_search) ) )
      ORDER BY
        ID
      FOR READ ONLY;

  exec SQL
    open list_cursor;

  g_state = EMBSQL_state();

  exec SQL
    get diagnostics :calc.total_rows = DB2_NUMBER_ROWS;

  APP_calc_page_data(calc: page_size: row_offset);

  exec SQL
    fetch relative :row_offset from list_cursor
      for :page_size rows into :data;

  got_rows = SQLERRD(3);
  calc.got_rows = got_rows;

  exec SQL
    close list_cursor;

  return got_rows;
end-proc;

//==============================================================================
// CUSDETDL_fetch
//   Data access layer fetch procedure
//==============================================================================

dcl-proc CUSDETDL_fetch export;
  dcl-pi *n like(BOOLEAN_t);
    sel  likeds(CUSDET_fetch_selections_t) const;
    data likeds(CUSDET_list_t);
  end-pi;

  exec SQL
    SELECT
      ID,
      CODE,
      STATUS,
      STATUS_DESCRIPTION,
      NAME,
      ADDRESS_LINE1,
      ADDRESS_LINE2,
      ADDRESS_LINE3,
      ADDRESS_LINE4,
      POSTCODE,
      CONTACT_NAME,
      CONTACT_TELP,
      CONTACT_EMAIL,
      VAT_CODE,
      CURRENCY,
      CREDIT_LIMIT,
      CURRENT_BALANCE,
      COMMENTS
    INTO
      :data
    FROM
      CUSDETVL
    WHERE
      ( :sel.CODE = '' OR :sel.CODE = CODE )
          AND
      ( :sel.ID = 0 OR ( :sel.ID = ID AND :sel.NOT_ID = 'N'
                      OR :sel.ID != ID AND :sel.NOT_ID = 'Y' ) )
    FETCH FIRST ROW ONLY;

  g_state = EMBSQL_state();

  return g_state.error;
end-proc;

//==============================================================================
// CUSDETDL_error
//   Returns the error state from the last SQL command
//==============================================================================

dcl-proc CUSDETDL_error export;
  dcl-pi *n like(BOOLEAN_t) end-pi;

  return g_state.error;
end-proc;

//==============================================================================
// CUSDETDL_found
//   Returns the found state from the last _get procedure
//==============================================================================

dcl-proc CUSDETDL_found export;
  dcl-pi *n like(BOOLEAN_t) end-pi;

  return g_state.found;
end-proc;
