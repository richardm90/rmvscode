**free

//==============================================================================
// RMAPP03    - Application Helper - Logger Module
//
// 11/11/2024 - RM - created
//==============================================================================

ctl-opt text('RMTOOLS: Application Helper - Logger Module');
ctl-opt option(*nodebugio:*noexpdds:*noext:*nounref:*noshowcpy:*noshowskp:*srcstmt);
ctl-opt nomain;

///
// Copybook definitions
///

/include 'QCPYSRC/RMAPP_D.rpgleinc'
/include 'QCPYSRC/RMTOOLS_D.rpgleinc'


dcl-proc APP_log export;
  dcl-pi *n;
    message_text like(APP_MESSAGE_TEXT_t) const;
    message_type like(SMALLINT_t) const options(*nopass:*omit);
    stack_offset like(SMALLINT_t) const options(*nopass);
  end-pi;

  dcl-s message_type_l like(SMALLINT_t) inz(APP_LOG_INFO);
  dcl-s stack_offset_l like(SMALLINT_t) inz(1);

  if %passed(message_type);
    message_type_l = message_type;
  endif;

  if %passed(stack_offset);
    stack_offset_l = stack_offset;
  endif;

  select;

  when message_type_l = APP_LOG_INFO;
    snd-msg *info message_text %target(*caller: stack_offset_l);

  when message_type_l = APP_LOG_ESCAPE;
    snd-msg *escape %msg('APP2901':'RMMSGF':message_text) %target(*caller: stack_offset_l);

  endsl;

  return;
end-proc;

dcl-proc APP_escape export;
  dcl-pi *n;
    message_text like(APP_MESSAGE_TEXT_t) const;
  end-pi;

  APP_log(message_text: APP_LOG_ESCAPE);

  return;
end-proc;
