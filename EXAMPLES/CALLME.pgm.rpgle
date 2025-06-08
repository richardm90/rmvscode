**free

ctl-opt text('Call From VS Code Example');
ctl-opt dftactgrp(*no) actgrp(*new);
ctl-opt main(CALLME);

/include 'QCPYSRC/APP_D.rpgleinc'

dcl-proc CALLME;
  dcl-pi *n;
    first_name char(20) options(*nopass) const;
    last_name char(20) options(*nopass) const;
  end-pi;

  if %passed(first_name);
    snd-msg 'First name: ' + first_name;
  endif;

  if %passed(last_name);
    snd-msg 'Last name: ' + last_name;
  endif;

  if not %passed(first_name) and not %passed(last_name);
    snd-msg 'Neither first or last name provided';
  endif;

  return;
end-proc;
