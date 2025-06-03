**free

ctl-opt text('RPGLE Linter Example');
ctl-opt dftactgrp(*no) actgrp(*new);
ctl-opt main(LINTER);

/copy 'QCPYSRC/APP_D.rpgleinc'
/include 'QCPYSRC/CUSDET_D.rpgleinc'
/Include 'QCPYSRC/PSDS_D.rpgleinc'

// @rpglint-skip
dcl-c STATUS_Closed const('C');
dcl-c STATUS_NEW const('N');

dcl-s valid_customer like(Boolean_t) inz(false);

dcl-proc LINTER;
  dcl-pi *n end-pi;

  dcl-s cust_name like(CUSDET_NAME_t) inz('Richard Moulton');
  dcl-s balance packed(11:2);
  Dcl-s message varchar(52);
  dcl-s status char(1);

  if %Len(cust_name) < 5;
     message = 'Name too short';

  elseif status = STATUS_CLOSED;
    message = 'Account is closed';

  else;
    message = 'Account is valid';
    valid_customer = true;
  endif;

  dsply message;

  return;
end-proc;