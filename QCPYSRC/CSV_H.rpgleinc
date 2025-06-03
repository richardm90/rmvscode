     /*-                                                                            +
      * Copyright (c) 2008-2020 Scott C. Klement                                    +
      * All rights reserved.                                                        +
      *                                                                             +
      * Redistribution and use in source and binary forms, with or without          +
      * modification, are permitted provided that the following conditions          +
      * are met:                                                                    +
      * 1. Redistributions of source code must retain the above copyright           +
      *    notice, this list of conditions and the following disclaimer.            +
      * 2. Redistributions in binary form must reproduce the above copyright        +
      *    notice, this list of conditions and the following disclaimer in the      +
      *    documentation and/or other materials provided with the distribution.     +
      *                                                                             +
      * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND      +
      * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE       +
      * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE  +
      * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE     +
      * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL  +
      * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS     +
      * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)       +
      * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT  +
      * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY   +
      * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF      +
      * SUCH DAMAGE.                                                                +
      *                                                                             +
      */                                                                            +
      /if defined(CSV_H_DEFINED)
      /eof
      /endif
      /define CSV_H_DEFINED

     D CSV_HANDLE      S               *   based(TEMPLATE)

      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * CSV_open(): open a delimited text file
      *
      *    peFilename = (input) IFS pathname to file to open
      *      peStrDel = (input/omit) String delimiter
      *                  if *OMIT, a double-quote character is used
      *      peFldDel = (input/omit) Field delimiter
      *                  if *OMIT, a comma is used
      *     peUnicode - (input/omit) open/process the file as Unicode
      *                  data rather than EBCDIC. Default: *OFF
      *
      * returns a CSV_HANDLE used to track the opened file
      *        or an *ESCAPE message upon error
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     D CSV_open        PR                  like(CSV_HANDLE)
     D   peFilename                5000A   varying const options(*varsize)
     D   peStrDel1                    1A   const options(*omit:*nopass)
     D   peStrDel2                    1A   const options(*omit:*nopass)
     D   peFldDel                     1A   const options(*omit:*nopass)
     D   peUnicode                    1n   const options(*omit:*nopass)


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * CSV_openBuf():  Open CSV from a memory buffer (vs. stream file)
      *
      *      peBuffer = (input) memory buffer to read from
      *      peBufLen = (input) length of memory buffer in bytes
      *    peBufCCSID = (input) CCSID of memory buffer (0=Job)
      *     peStrDel1 = (input/omit) String delimiter
      *                  if *OMIT, a double-quote character is used
      *     peStrDel2 = (input/omit) Secondary string delimiter
      *                  if *OMIT, a single-quote character is used
      *      peFldDel = (input/omit) Field delimiter
      *                  if *OMIT, a comma is used
      *     peUnicode - (input/omit) oprocess the data as Unicode
      *                  data rather than EBCDIC. Default: *OFF
      *
      * returns a CSV_HANDLE used to track the opened file
      *        or an *ESCAPE message upon error
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     D CSV_openBuf     PR                  like(CSV_HANDLE)
     D   peBuffer                      *   value
     D   peBufLen                    10u 0 value
     D   peBufCCSID                   5u 0 value
     D   peStrDel1                    1A   const options(*omit:*nopass)
     D   peStrDel2                    1A   const options(*omit:*nopass)
     D   peFldDel                     1A   const options(*omit:*nopass)
     D   peUnicode                    1n   const options(*omit:*nopass)


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * CSV_loadrec(): Load a record from a delimited file into memory
      *
      *     peHandle = (i/o) handle to file returned by CSV_open()
      *
      * Returns *ON if successful, *OFF upon failure or EOF
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     D CSV_loadrec     PR             1N   extproc(*CL:'CSV_LOADREC')
     D   peHandle                          like(CSV_HANDLE) value


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * CSV_rewindfile():  Move file cursor back to the start
      *                    (so you can re-read from the beginning)
      *
      *   peHandle = (i/o) handle to file returned by CSV_open
      *
      * Returns *ON if successful, *OFF otherwise.
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     D CSV_rewindfile  PR             1N   extproc(*CL:'CSV_REWINDFILE')
     D   peHandle                          like(CSV_HANDLE) value


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * CSV_rewindrec():  Move field cursor back to the start
      *                  (so you can re-read fields from this record)
      *
      *   peHandle = (i/o) handle to file returned by CSV_open
      *
      * Returns *ON if successful, *OFF otherwise.
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     D CSV_rewindrec   PR             1N   extproc(*CL:'CSV_REWINDREC')
     D   peHandle                          like(CSV_HANDLE) value


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * CSV_getfld(): Get the next field from a delimited file record
      *
      *  peHandle = (i/o)  handle to file opened by CSV_open()
      * peFldData = (output) data read from file
      * peVarSize = (input) size, in bytes, of the peFldData
      *                     variable that you passed (including
      *                     the two bytes for the length)
      *
      * Returns *ON if data was read, *OFF otherwise
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     D CSV_getfld      PR             1N   extproc(*CL:'CSV_GETFLD')
     D   peHandle                          like(CSV_HANDLE) value
     D   peFldData                65502A   varying options(*varsize)
     D   peVarSize                   10I 0 value


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * CSV_getfldUni(): Get the next field from a delimited file
      *                  and return it in Unicode format
      *
      *  peHandle = (i/o)  handle to file opened by CSV_open()
      * peFldData = (output) data read from file
      * peVarSize = (input) size, in bytes, of the peFldData
      *                     variable that you passed (including
      *                     the two bytes for the length)
      *
      * Returns *ON if data was read, *OFF otherwise
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     D CSV_getFldUni   PR             1N
     D   peHandle                          like(CSV_HANDLE) value
     D   peFldData                65502C   varying options(*varsize) ccsid(1200)
     D   peVarSize                   10I 0 value


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * CSV_close(): Close Delimited File
      *
      *  peHandle = (i/o) handle to file opened by CSV_open()
      *                   this is set to *NULL if when file is
      *                   closed successfully.
      *
      * Returns an *ESCAPE message upon failure
      *         otherwise, returns nothing.
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     D CSV_close       PR
     D   peHandle                          like(CSV_HANDLE) 
