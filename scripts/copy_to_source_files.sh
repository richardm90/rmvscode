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

if [[ $# = 1 ]]; then
  SRCDIR="$(pwd)"
else
  SRCDIR=$2
fi

if [[ $# = 2 ]]; then
  TGTRLS=*CURRENT
else
  TGTRLS=$3
fi

#===============================================================================
# Create source files
#===============================================================================

crtsrcpf $TGTLIB 'QBNDSRC'
crtsrcpf $TGTLIB 'QCPYSRC'
crtsrcpf $TGTLIB 'QDDSSRC'
crtsrcpf $TGTLIB 'QRPGLESRC' 112
crtsrcpf $TGTLIB 'QSQLSRC'

#===============================================================================
# Copy QCPYSRC source
#===============================================================================

tweakcopy "$SRCDIR/QCPYSRC/ADDMSG_D.rpgleinc"   ADDMSG_D   QCPYSRC $TGTLIB RPGLE 'ADDMSG Definition Copybook'
tweakcopy "$SRCDIR/QCPYSRC/APMDAL_D.rpgleinc"   APMDAL_D   QCPYSRC $TGTLIB RPGLE 'Application Messages DAL Copybook'
tweakcopy "$SRCDIR/QCPYSRC/APP_D.rpgleinc"      APP_D      QCPYSRC $TGTLIB RPGLE 'Application system definitions'
tweakcopy "$SRCDIR/QCPYSRC/APP_H.rpgleinc"      APP_H      QCPYSRC $TGTLIB RPGLE 'Application system control specifications'
tweakcopy "$SRCDIR/QCPYSRC/CALLER_D.rpgleinc"   CALLER_D   QCPYSRC $TGTLIB RPGLE 'RMTOOLS Retrieve Caller Procedure Copybook'
tweakcopy "$SRCDIR/QCPYSRC/CALLER_P.rpgleinc"   CALLER_P   QCPYSRC $TGTLIB RPGLE 'RMTOOLS Retrieve Caller Procedure Copybook'
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

tweakcopy "$SRCDIR/QRPGLESRC/APMDAL.sqlrpgle" APMDAL QRPGLESRC $TGTLIB SQLRPGLE 'Application Messages DAL Module'

#===============================================================================
# Build modules
#===============================================================================

# crtrpgmod $TGTLIB APMDAL QRPGLESRC $TGTRLS
crtsqlrpgi $TGTLIB APMDAL QRPGLESRC "*MODULE" $TGTRLS
