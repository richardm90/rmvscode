#!/QOpenSys/pkgs/bin/bash

#===============================================================================
# if_error
# $1 = error message
# $2 = boolean value, exit on error
function if_error {
  if [[ $? != 0 ]]; then  # check return code of last command
    print "$1"            # if rc > 0 then print error msg and quit
    if [[ $# < 2 || $2 = "true" ]]; then
      exit $?
    fi
  fi
}

#===============================================================================
# crtsrcpf
# $1 = target library
# $2 = source physical file name
# $3 = source physical file record length, defaults to 92
function crtsrcpf {
  if [[ $# < 3 ]]; then
    RCDLEN=92
  else
    RCDLEN=$3
  fi
  cl -bOE "CRTSRCPF FILE($1/$2) RCDLEN($RCDLEN)"
  # if_error "ERROR: Failed to create $2 in library $1"
}

#===============================================================================
# cpyfrmstmf
#   Copies the given stream file to QGPL/RMTOOLS
#
# $1 = source stream file
# $2 = target member
# $3 = optional, target source file
# $4 = optional, target library
# $5 = optional, source member type
# $6 = optional, source member text
function cpyfrmstmf {
  if [[ $# < 3 ]]; then
    TARGET_SRCF=RMTOOLS
  else
    TARGET_SRCF=$3
  fi
  if [[ $# < 4 ]]; then
    TARGET_LIB=QGPL
  else
    TARGET_LIB=$4
  fi

  if [[ $# < 3 ]]; then
    crtsrcpf $TARGET_LIB $TARGET_SRCF
  fi
  cl -bvOE "CPYFRMSTMF FROMSTMF('$1') TOMBR('/QSYS.LIB/$TARGET_LIB.LIB/$TARGET_SRCF.FILE/$2.MBR') MBROPT(*REPLACE)"
  if_error "ERROR: Failed to copy source stream file ($1)"

  if [[ $# = 5 ]]; then
    chgpfm $TARGET_LIB $TARGET_SRCF $2 $5
  fi
  if [[ $# > 5 ]]; then
    chgpfm $TARGET_LIB $TARGET_SRCF $2 $5 "$6"
  fi
}

#===============================================================================
# tweakcopy
#   Copies the given stream file to QGPL/RMTOOLS
#
# $1 = source stream file
# $2 = target member
# $3 = optional, target source file
# $4 = optional, target library
# $5 = optional, source member type
# $6 = optional, source member text
function tweakcopy {
  if [[ $# < 3 ]]; then
    TARGET_SRCF=RMTOOLS
  else
    TARGET_SRCF=$3
  fi
  if [[ $# < 4 ]]; then
    TARGET_LIB=QGPL
  else
    TARGET_LIB=$4
  fi

  # Tweak source
  # - specifically for RPGLE includes
  # - leaves the source IFS file intact
  # - generates a temp copy of the file, which is cleaned up
  TEMPFILE=$(mktemp)
  sed 's/'\''QCPYSRC\//QCPYSRC,/g' $1 | sed 's/.rpgleinc'\''//g' > $TEMPFILE

  if [[ $# < 3 ]]; then
    crtsrcpf $TARGET_LIB $TARGET_SRCF
  fi
  cl -bvOE "CPYFRMSTMF FROMSTMF('$TEMPFILE') TOMBR('/QSYS.LIB/$TARGET_LIB.LIB/$TARGET_SRCF.FILE/$2.MBR') MBROPT(*REPLACE)"
  if_error "ERROR: Failed to copy source stream file ($1)"

  # Remove temp file
  rm $TEMPFILE

  if [[ $# = 5 ]]; then
    chgpfm $TARGET_LIB $TARGET_SRCF $2 $5
  fi
  if [[ $# > 5 ]]; then
    chgpfm $TARGET_LIB $TARGET_SRCF $2 $5 "$6"
  fi
}

#===============================================================================
# chgpfm
#   Change Physical File Member
#
# $1 = library
# $2 = source stream file
# $3 = source member
# $4 = optional, source member type
# $5 = optional, source member text
function chgpfm {
  if [[ $# = 4 ]]; then
    cl -bvOE "CHGPFM FILE($1/$2) MBR($3) SRCTYPE($4)"
    if_error "ERROR: Failed to change physical file member $1/$2($3)"
  else
    cl -bvOE "CHGPFM FILE($1/$2) MBR($3) SRCTYPE($4) TEXT('$5')"
    if_error "ERROR: Failed to change physical file member $1/$2($3)"
  fi
}

#===============================================================================
# crtbndcl - from a source file
# $1 = target and source file library
# $2 = target object and member
# $3 = source file
# $4 = target release
function crtbndcl {
  cl -bksOE "CRTBNDCL PGM($1/$2) SRCFILE($1/$3) SRCMBR($2) TGTRLS($4)"
  if_error "ERROR: Failed to compile source for $2"
}

#===============================================================================
# crtcmd - from a source file
# $1 = target and source file library
# $2 = target object and member
# $3 = source file
# $4 = target object text
function crtcmd {
  cl -bksOE "CRTCMD CMD($1/$2) PGM($1/$2) SRCFILE($1/$3) SRCMBR($2) TEXT('$4') REPLACE(*YES)"
  if_error "ERROR: Failed to create command $2"
}

#===============================================================================
# crtsqlrpgi - from a source file
# $1 = target and source file library
# $2 = target object and member
# $3 = source file
# $4 = target object type
# $5 = target release
function crtsqlrpgi {
  cl -beksvOE "CRTSQLRPGI OBJ($1/$2) SRCFILE($1/$3) SRCMBR($2) OBJTYPE($4) RPGPPOPT(*LVL2) TGTRLS($5) DBGVIEW(*SOURCE) COMPILEOPT('TGTCCSID(*JOB)')"
  if_error "ERROR: Failed to create SQL ILE RPG object ($1)"
}

#===============================================================================
# crtrpgmod - from a source file
# $1 = target and source file library
# $2 = target object and member
# $3 = source file
# $4 = target release
function crtrpgmod {
  cl -bksOEv "CRTRPGMOD MODULE($1/$2) SRCFILE($1/$3) SRCMBR($2) TGTRLS($4)"
  if_error "ERROR: Failed to compile source for $2"
}

#===============================================================================
# crtsrvpgm - from a source file
# $1 = target and binder source file library
# $2 = target object and binder source member
# $3 = binder source file
# $4 = list of modules e.g. "$1/MOD1 $1/MOD2"
# $5 = target release
# $6 = object text
function crtsrvpgm {
  cl -beksvOE "CRTSRVPGM SRVPGM($1/$2) MODULE($4) EXPORT(*SRCFILE) SRCFILE($1/$3) SRCMBR($2) TGTRLS($5) TEXT('$6')"
  if_error "ERROR: Failed to create Service Program ($2)"
}

#===============================================================================
# runsqlstm - from a source file
# $1 = source file library
# $2 = source member
# $3 = source file
function runsqlstm {
  cl -beksvOE "RUNSQLSTM SRCFILE($1/$3) SRCMBR($2) COMMIT(*NONE) MARGINS(1024) OUTPUT(*PRINT) DBGVIEW(*SOURCE)"
  if_error "ERROR: Failed to Run SQL Statements ($2)"
}

#===============================================================================
# crtbndrpg - from a source file
# $1 = target and source file library
# $2 = target object and member
# $3 = source file
# $4 = target release
function crtbndrpg {
  cl -bksOEv "CRTBNDRPG PGM($1/$2) SRCFILE($1/$3) SRCMBR($2) TGTRLS($4)"
  if_error "ERROR: Failed to compile source for $2"
}

#===============================================================================
# crtdspf - from a source file
# $1 = target and source file library
# $2 = target object and member
# $3 = source file
# $4 = target object text
function crtdspf {
  cl -bksOEv "CRTDSPF FILE($1/$2) SRCFILE($1/$3) SRCMBR($2) ENHDSP(*YES) RSTDSP(*YES) DFRWRT(*YES) TEXT('$4')"
  if_error "ERROR: Failed to compile source for $2"
}
