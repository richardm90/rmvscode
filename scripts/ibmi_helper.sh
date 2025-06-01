#!/bin/ksh

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
# compile
# $1 = target library
# $2 = root folder
# $3 = tool to compile e.g. rmrunclp
# $4 = target release
function compile {
  system -beksvOE "$1/COMPILE TGTLIB($1) ROOTFOLDER('$2') TOOLFOLDER('$3') TGTRLS($4)"
  if_error "ERROR: Failed to compile tool $3"
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
  system -bvOE "CPYFRMSTMF FROMSTMF('$1') TOMBR('/QSYS.LIB/$TARGET_LIB.LIB/$TARGET_SRCF.FILE/$2.MBR') MBROPT(*REPLACE)"
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
  system -bvOE "CPYFRMSTMF FROMSTMF('$TEMPFILE') TOMBR('/QSYS.LIB/$TARGET_LIB.LIB/$TARGET_SRCF.FILE/$2.MBR') MBROPT(*REPLACE)"
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
    system -bvOE "CHGPFM FILE($1/$2) MBR($3) SRCTYPE($4)"
    if_error "ERROR: Failed to change physical file member $1/$2($3)"
  else
    system -bvOE "CHGPFM FILE($1/$2) MBR($3) SRCTYPE($4) TEXT('$5')"
    if_error "ERROR: Failed to change physical file member $1/$2($3)"
  fi
}

#===============================================================================
# create_service_program
# $1 = source stream file
# $2 = target library
# $3 = target object
# $4 = target object text
# $5 = target release
function create_service_program {
  system -bevOE "CRTSQLRPGI OBJ($2/$3) SRCSTMF('$1') OBJTYPE(*MODULE) TEXT('$4') RPGPPOPT(*LVL2) TGTRLS($5) DBGVIEW(*SOURCE) COMPILEOPT('TGTCCSID(*JOB)')"
  if_error "ERROR: Failed to create SQL ILE RPG object ($1)"
  system -bvOE "CRTSRVPGM SRVPGM($2/$3) EXPORT(*ALL) TEXT('$4') BNDDIR($2/RMTOOLS) TGTRLS($5)"
  if_error "ERROR: Failed to create SQL ILE RPG object ($1)"
  addbnddire $2 RMTOOLS $3
}

#===============================================================================
# create_qsqlpre
#   Create the SQL precompiled source physical file with a longer length, which
#   will cope the longer source line lengths
#
# $1 = source stream file
# $2 = target library
# $3 = target object
# $4 = target object text
# $4 = target release
function create_qsqlpre {
  system -bOE "DLTF FILE(QTEMP/QSQLPRE)"
  system -bOE "CRTSRCPF FILE(QTEMP/QSQLPRE) RCDLEN(240)"
}

#===============================================================================
# addbnddire
# $1 = binding directory and object library
# $2 = binding directory name
# $3 = binding directory entry object
function addbnddire {
  system -bOE "ADDBNDDIRE BNDDIR($1/$2) OBJ($3)"
  if_error "ERROR: Failed to add binding directory entry $3"
}

#===============================================================================
# addenvvar
# $1 = environment variable name
# $2 = environment variable value
# $3 = level, either *JOB or *SYS
function addenvvar {
  system -bOE "ADDENVVAR ENVVAR($1) VALUE('$2') LEVEL($3) REPLACE(*YES)"
  if_error "ERROR: Failed to add environment variable $1"
}

#===============================================================================
# crtbndcl
# $1 = source stream file
# $2 = target library
# $3 = target object
# $4 = target object text
# $5 = target release
function crtbndcl {
  copy_from_stmf $1 $3
  system -bksOE "CRTBNDCL PGM($2/$3) SRCFILE(QGPL/RMTOOLS) SRCMBR($3) TEXT('$4') TGTRLS($5)"
  if_error "ERROR: Failed to compile source for $3"
}

#===============================================================================
# crtsqlrpgi - from a source file
# $1 = target and source file library
# $2 = target object and member
# $3 = source file
# $4 = target object type
# $5 = target release
function crtsqlrpgi {
  system -beksvOE "CRTSQLRPGI OBJ($1/$2) SRCFILE($1/$3) SRCMBR($2) OBJTYPE($4) RPGPPOPT(*LVL2) TGTRLS($5) DBGVIEW(*SOURCE) COMPILEOPT('TGTCCSID(*JOB)')"
  if_error "ERROR: Failed to create SQL ILE RPG object ($1)"
}

#===============================================================================
# crtrpgmod - from a source file
# $1 = target and source file library
# $2 = target object and member
# $3 = source file
# $4 = target release
function crtrpgmod {
  system -bksOEv "CRTRPGMOD MODULE($1/$2) SRCFILE($1/$3) SRCMBR($2) TGTRLS($4)"
  if_error "ERROR: Failed to compile source for $3"
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
  system -beksvOE "CRTSRVPGM SRVPGM($1/$2) MODULE($4) EXPORT(*SRCFILE) SRCFILE($1/$3) SRCMBR($2) TGTRLS($5) TEXT('$6')"
  if_error "ERROR: Failed to create Service Program ($2)"
}

#===============================================================================
# runsqlstm - from a source file
# $1 = source file library
# $2 = source member
# $3 = source file
function runsqlstm {
  system -beksvOE "RUNSQLSTM SRCFILE($1/$3) SRCMBR($2) COMMIT(*NONE) MARGINS(1024) OUTPUT(*PRINT) DBGVIEW(*SOURCE)"
  if_error "ERROR: Failed to Run SQL Statements ($2)"
}

#===============================================================================
# crtbndrpg - from a source file
# $1 = target and source file library
# $2 = target object and member
# $3 = source file
# $4 = target release
function crtbndrpg {
  system -bksOEv "CRTBNDRPG PGM($1/$2) SRCFILE($1/$3) SRCMBR($2) TGTRLS($4)"
  if_error "ERROR: Failed to compile source for $2"
}

#===============================================================================
# crtdspf - from a source file
# $1 = target and source file library
# $2 = target object and member
# $3 = source file
# $4 = target object text
function crtdspf {
  system -bksOEv "CRTDSPF FILE($1/$2) SRCFILE($1/$3) SRCMBR($2) ENHDSP(*YES) RSTDSP(*YES) DFRWRT(*YES) TEXT('$4')"
  if_error "ERROR: Failed to compile source for $2"
}

#===============================================================================
# crtbnddir
# $1 = target library
# $2 = target object
# $3 = target object text
function crtbnddir {
  system -bOE "CRTBNDDIR BNDDIR($1/$2) TEXT('$3')"
  # if_error "ERROR: Failed to create binding directory $2"
}

#===============================================================================
# crtcmd
# $1 = source stream file
# $2 = target library
# $3 = target object
# $4 = target object text
function crtcmd {
  copy_from_stmf $1 $3
  system -bksOE "CRTCMD CMD($2/$3) PGM($2/$3) SRCFILE(QGPL/RMTOOLS) SRCMBR($3) TEXT('$4') REPLACE(*YES)"
  if_error "ERROR: Failed to create command $3"
}

#===============================================================================
# crtlib
# $1 = target library
# $2 = target library text
function crtlib {
  system -bOE "CRTLIB LIB($1) TEXT('$2')"
  # if_error "ERROR: Failed to create library $1" false
}

#===============================================================================
# crtsqlrpgi_stmf
# $1 = source stream file
# $2 = target library
# $3 = target object
# $4 = target object type
# $5 = target object text
# $6 = target release
function crtsqlrpgi_stmf {
  system -beksvOE "CRTSQLRPGI OBJ($2/$3) SRCSTMF('$1') OBJTYPE($4) TEXT('$5') RPGPPOPT(*LVL2) TGTRLS($6) DBGVIEW(*SOURCE) COMPILEOPT('TGTCCSID(*JOB)')"
  if_error "ERROR: Failed to create SQL ILE RPG object ($1)"
}

#===============================================================================
# crtpgm
# $1 = target library
# $2 = target object
# $3 = list of qualified modules
function crtpgm {
  system -bOE "CRTPGM PGM($1/$2) MODULE($3) ACTGRP(*NEW)"
  if_error "ERROR: Failed to create program object ($1)"
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
  system -bOE "CRTSRCPF FILE($1/$2) RCDLEN($RCDLEN)"
  # if_error "ERROR: Failed to create $2 in library $1"
}

#===============================================================================
# rmvbnddire
# $1 = binding directory library
# $2 = binding directory name
# $3 = binding directory entry object
function rmvbnddire {
  system -bOE "RMVBNDDIRE BNDDIR($1/$2) OBJ($1/$3)"
  if_error "ERROR: Failed to remove binding directory entry $3"
}
