#!/bin/ksh

## __SCRIPTNAME - name of the script without the path
##
typeset -r __SCRIPTNAME="${0##*/}"

## __SCRIPTDIR - path of the script (as entered by the user!)
##
__SCRIPTDIR="${0%/*}"

## __REAL_SCRIPTDIR - path of the script (real path, maybe a link)
##
__REAL_SCRIPTDIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )

# source install_lib.sh
. $__SCRIPTDIR/ibmi_helper.sh

#===============================================================================
# Handle input parameters
#===============================================================================

printenv

if [[ $# < 1 ]]; then
  print "Usage: install.sh <target_library> <source_folder> <target_release>"
  exit
fi

TGTLIB=$1

if [[ $# < 2 ]]; then
  SRCDIR="$(pwd)"
else
  SRCDIR=$2
fi

if [[ $# < 3 ]]; then
  TGTRLS="*CURRENT"
else
  TGTRLS=$3
fi

#===============================================================================
# Create source files
#===============================================================================

crtsrcpf $TGTLIB 'EXAMPLES'  112
crtsrcpf $TGTLIB 'QBNDSRC'
crtsrcpf $TGTLIB 'QCPYSRC'
crtsrcpf $TGTLIB 'QDDSSRC'
crtsrcpf $TGTLIB 'QRPGLESRC' 112
crtsrcpf $TGTLIB 'QSQLSRC'   240
crtsrcpf $TGTLIB 'VSCODE'    112

#===============================================================================
# Handle Scott Klement CSVUTIL
#===============================================================================

cpyfrmstmf "$SRCDIR/csvutil/csv_h.rpgle"        CSV_H      QRPGLESRC $TGTLIB RPGLE 'Copyright (c) 2008-2020 Scott C. Klement'
cpyfrmstmf "$SRCDIR/csvutil/csvr4.bnd"          CSVR4      QBNDSRC   $TGTLIB BND   'Copyright (c) 2008-2020 Scott C. Klement'
cpyfrmstmf "$SRCDIR/csvutil/csvr4.rpgle"        CSVR4      QRPGLESRC $TGTLIB RPGLE 'Copyright (c) 2008-2020 Scott C. Klement'
cpyfrmstmf "$SRCDIR/csvutil/iconv_h.rpgle"      ICONV_H    QRPGLESRC $TGTLIB RPGLE 'Copyright (c) 2008-2020 Scott C. Klement'
cpyfrmstmf "$SRCDIR/csvutil/ifsio_h.rpgle"      IFSIO_H    QRPGLESRC $TGTLIB RPGLE 'Copyright (c) 2008-2020 Scott C. Klement'

crtrpgmod  $TGTLIB CSVR4   QRPGLESRC          $TGTRLS
crtsrvpgm  $TGTLIB CSVR4   QBNDSRC            "$TGTLIB/CSVR4" $TGTRLS 'Copyright (c) 2008-2020 Scott C. Klement'

/QOpenSys/usr/bin/system "DLTOBJ OBJ($TGTLIB/CSV) OBJTYPE(*BNDDIR)"
/QOpenSys/usr/bin/system "CRTBNDDIR BNDDIR($TGTLIB/CSV)"
/QOpenSys/usr/bin/system "ADDBNDDIRE BNDDIR($TGTLIB/CSV) OBJ((*LIBL/CSVR4 *SRVPGM))"

#===============================================================================
# Copy EXAMPLES source
#===============================================================================

cpyfrmstmf "$SRCDIR/EXAMPLES/LINTER.pgm.rpgle"  LINTER     EXAMPLES $TGTLIB RPGLE 'RPGLE Linter Example'

#===============================================================================
# Copy QBNDSRC source
#===============================================================================

cpyfrmstmf "$SRCDIR/QBNDSRC/RMAPP.bnd"          RMAPP      QBNDSRC $TGTLIB BND   'Application Binder Source'

#===============================================================================
# Copy QCPYSRC source
#===============================================================================

tweakcopy "$SRCDIR/QCPYSRC/ADDMSG_D.rpgleinc"   ADDMSG_D   QCPYSRC $TGTLIB RPGLE 'ADDMSG Definition Copybook'
tweakcopy "$SRCDIR/QCPYSRC/ADDMSG_P.rpgleinc"   ADDMSG_P   QCPYSRC $TGTLIB RPGLE 'ADDMSG Procedures Copybook'
tweakcopy "$SRCDIR/QCPYSRC/APMDAL_D.rpgleinc"   APMDAL_D   QCPYSRC $TGTLIB RPGLE 'Application Messages DAL Copybook'
tweakcopy "$SRCDIR/QCPYSRC/APMSAL_D.rpgleinc"   APMSAL_D   QCPYSRC $TGTLIB RPGLE 'Application Messages SL Copybook'
tweakcopy "$SRCDIR/QCPYSRC/APP_D.rpgleinc"      APP_D      QCPYSRC $TGTLIB RPGLE 'Application system definitions'
tweakcopy "$SRCDIR/QCPYSRC/APP_H.rpgleinc"      APP_H      QCPYSRC $TGTLIB RPGLE 'Application system control specifications'
tweakcopy "$SRCDIR/QCPYSRC/CALLER_D.rpgleinc"   CALLER_D   QCPYSRC $TGTLIB RPGLE 'RMTOOLS Retrieve Caller Procedure Copybook'
tweakcopy "$SRCDIR/QCPYSRC/CALLER_P.rpgleinc"   CALLER_P   QCPYSRC $TGTLIB RPGLE 'RMTOOLS Retrieve Caller Procedure Copybook'
tweakcopy "$SRCDIR/QCPYSRC/CSV_H.rpgleinc"      CSV_H      QCPYSRC $TGTLIB RPGLE 'Copyright (c) 2008-2020 Scott C. Klement'
tweakcopy "$SRCDIR/QCPYSRC/CUSDET_D.rpgleinc"   CUSDET_D   QCPYSRC $TGTLIB RPGLE 'Customer Details SAL Copybook'
tweakcopy "$SRCDIR/QCPYSRC/CUSDETDL_D.rpgleinc" CUSDETDL_D QCPYSRC $TGTLIB RPGLE 'Customer Details DAL Copybook'
tweakcopy "$SRCDIR/QCPYSRC/FLASH_D.rpgleinc"    FLASH_D    QCPYSRC $TGTLIB RPGLE 'FLASH Definitions Copybook'
tweakcopy "$SRCDIR/QCPYSRC/FLASH_P.rpgleinc"    FLASH_P    QCPYSRC $TGTLIB RPGLE 'FLASH Procedures Copybook'
tweakcopy "$SRCDIR/QCPYSRC/INFDS_D.rpgleinc"    INFDS_D    QCPYSRC $TGTLIB RPGLE 'Display File Information Data Structure Copybook'
tweakcopy "$SRCDIR/QCPYSRC/PSDS_D.rpgleinc"     PSDS_D     QCPYSRC $TGTLIB RPGLE 'Program Status Data Structure Copybook'
tweakcopy "$SRCDIR/QCPYSRC/RMAPP_D.rpgleinc"    RMAPP_D    QCPYSRC $TGTLIB RPGLE 'Application Helper Copybook'
tweakcopy "$SRCDIR/QCPYSRC/RMEMBSQL_D.rpgleinc" RMEMBSQL_D QCPYSRC $TGTLIB RPGLE 'Embedded SQL RPG Helper Copybook'
tweakcopy "$SRCDIR/QCPYSRC/RMEMBSQL_P.rpgleinc" RMEMBSQL_P QCPYSRC $TGTLIB RPGLE 'Embedded SQL set options procedure copybook'
tweakcopy "$SRCDIR/QCPYSRC/RMTOOLS_D.rpgleinc"  RMTOOLS_D  QCPYSRC $TGTLIB RPGLE 'RMTOOLS standard definitions copybook'

#===============================================================================
# Copy QDDSSRC source
#===============================================================================

cpyfrmstmf "$SRCDIR/QDDSSRC/WRKCUSD.dspf" WRKCUSD QDDSSRC $TGTLIB DSPF 'Work with Customers'

#===============================================================================
# Copy QRPGLESRC source
#===============================================================================

tweakcopy "$SRCDIR/QRPGLESRC/APMDAL.sqlrpgle"         APMDAL     QRPGLESRC $TGTLIB SQLRPGLE 'Application Messages DAL Module'
tweakcopy "$SRCDIR/QRPGLESRC/APMSAL.rpgle"            APMSAL     QRPGLESRC $TGTLIB RPGLE    'Application Messages SAL Module'
tweakcopy "$SRCDIR/QRPGLESRC/CUSDET.sqlrpgle"         CUSDET     QRPGLESRC $TGTLIB SQLRPGLE 'Customer Details SAL Module'
tweakcopy "$SRCDIR/QRPGLESRC/CUSDETDL.sqlrpgle"       CUSDETDL   QRPGLESRC $TGTLIB SQLRPGLE 'Customer Details DAL Module'
tweakcopy "$SRCDIR/QRPGLESRC/RMAPP01.rpgle"           RMAPP01    QRPGLESRC $TGTLIB RPGLE    'Application Messages DAL Module'
tweakcopy "$SRCDIR/QRPGLESRC/RMAPP02.rpgle"           RMAPP02    QRPGLESRC $TGTLIB RPGLE    'Application Messages DAL Module'
tweakcopy "$SRCDIR/QRPGLESRC/RMAPP03.rpgle"           RMAPP03    QRPGLESRC $TGTLIB RPGLE    'Application Messages DAL Module'
tweakcopy "$SRCDIR/QRPGLESRC/RMEMBSQL.sqlrpgle"       RMEMBSQL   QRPGLESRC $TGTLIB SQLRPGLE 'Embedded SQL RPG Helper Module'
tweakcopy "$SRCDIR/QRPGLESRC/SEEDCUSDET.pgm.sqlrpgle" SEEDCUSDET QRPGLESRC $TGTLIB SQLRPGLE 'Seed CUSDET Table'
tweakcopy "$SRCDIR/QRPGLESRC/WRKCUS.pgm.rpgle"        WRKCUS     QRPGLESRC $TGTLIB RPGLE    'Work With Customers'

#===============================================================================
# Copy QSQLSRC source
#===============================================================================

cpyfrmstmf "$SRCDIR/QSQLSRC/APPMSG.table"      APPMSG   QSQLSRC   $TGTLIB SQL      'Application Messages'
cpyfrmstmf "$SRCDIR/QSQLSRC/APPMSGVL.view"     APPMSGVL QSQLSRC   $TGTLIB SQL      'Application Messages List View'
cpyfrmstmf "$SRCDIR/QSQLSRC/APPMSGVP.view"     APPMSGVP QSQLSRC   $TGTLIB SQL      'Application Messages Primary View'
cpyfrmstmf "$SRCDIR/QSQLSRC/APPMSGX1.index"    APPMSGX1 QSQLSRC   $TGTLIB SQL      'Application Messages by JOB_NAME'
cpyfrmstmf "$SRCDIR/QSQLSRC/CUSDET.table"      CUSDET   QSQLSRC   $TGTLIB SQL      'Customer Details'
cpyfrmstmf "$SRCDIR/QSQLSRC/CUSDETVL.view"     CUSDETVL QSQLSRC   $TGTLIB SQL      'Customer Details List View'
cpyfrmstmf "$SRCDIR/QSQLSRC/CUSDETVP.view"     CUSDETVP QSQLSRC   $TGTLIB SQL      'Customer Details Primary View'

#===============================================================================
# Copy VSCODE source
#===============================================================================

cpyfrmstmf "$SRCDIR/.vscode/rpglint.json"       RPGLINT VSCODE    $TGTLIB JSON     'RPGLE Linter Configuration'

#===============================================================================
# Create datebase objects
#===============================================================================

runsqlstm  $TGTLIB APPMSG   QSQLSRC
runsqlstm  $TGTLIB APPMSGVP QSQLSRC
runsqlstm  $TGTLIB APPMSGVL QSQLSRC
runsqlstm  $TGTLIB APPMSGX1 QSQLSRC
runsqlstm  $TGTLIB CUSDET   QSQLSRC
runsqlstm  $TGTLIB CUSDETVP QSQLSRC
runsqlstm  $TGTLIB CUSDETVL QSQLSRC

#===============================================================================
# Create modules
#===============================================================================

crtsqlrpgi $TGTLIB APMDAL   QRPGLESRC "*MODULE" $TGTRLS
crtrpgmod  $TGTLIB APMSAL   QRPGLESRC           $TGTRLS
crtsqlrpgi $TGTLIB CUSDET   QRPGLESRC "*MODULE" $TGTRLS
crtsqlrpgi $TGTLIB CUSDETDL QRPGLESRC "*MODULE" $TGTRLS
crtrpgmod  $TGTLIB RMAPP01  QRPGLESRC           $TGTRLS
crtrpgmod  $TGTLIB RMAPP02  QRPGLESRC           $TGTRLS
crtrpgmod  $TGTLIB RMAPP03  QRPGLESRC           $TGTRLS
crtsqlrpgi $TGTLIB RMEMBSQL QRPGLESRC "*MODULE" $TGTRLS

#===============================================================================
# Create message file
#===============================================================================

/QOpenSys/usr/bin/system "DLTOBJ OBJ($TGTLIB/RMMSGF) OBJTYPE(*MSGF)"
/QOpenSys/usr/bin/system "CRTMSGF MSGF($TGTLIB/RMMSGF) TEXT('RMTOOLS Message File')"
/QOpenSys/usr/bin/system "ADDMSGD MSGID(APP2901) MSGF($TGTLIB/RMMSGF) MSG('&1') FMT((*CHAR 512))"

#===============================================================================
# Create binding directory
#===============================================================================

/QOpenSys/usr/bin/system "DLTOBJ OBJ($TGTLIB/RMAPP) OBJTYPE(*BNDDIR)"
/QOpenSys/usr/bin/system "CRTBNDDIR BNDDIR($TGTLIB/RMAPP)"
/QOpenSys/usr/bin/system "ADDBNDDIRE BNDDIR($TGTLIB/RMAPP) OBJ((*LIBL/RMAPP *SRVPGM))"

#===============================================================================
# Create service programs
#===============================================================================

crtsrvpgm  $TGTLIB RMAPP   QBNDSRC    "$TGTLIB/RMAPP01 $TGTLIB/RMAPP02 $TGTLIB/RMAPP03 $TGTLIB/RMEMBSQL $TGTLIB/APMDAL $TGTLIB/APMSAL $TGTLIB/CUSDETDL $TGTLIB/CUSDET" $TGTRLS 'RMAPP Service Program'
# RMAPP.SRVPGM: private OPTION = *DUPPROC

#===============================================================================
# Create programs
#===============================================================================

crtbndrpg  $TGTLIB LINTER     EXAMPLES         $TGTRLS
crtsqlrpgi $TGTLIB SEEDCUSDET QRPGLESRC "*PGM" $TGTRLS
crtdspf    $TGTLIB WRKCUSD    QDDSSRC          'Work with Customers'
crtbndrpg  $TGTLIB WRKCUS     QRPGLESRC        $TGTRLS
