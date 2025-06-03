      * CSVR4 -- service program for working with Comma Separated
      *          Values (CSV) files, and other delimited files
      *
      *     To compile:
      *     - First, make sure the CSVR4.rpgle, CSV_H.rpgle, and
      *         IFSIO_H.rpgle files from the ZIP file have been
      *         uploaded to a QRPGLESRC in your library list.
      *     - Make sure the CSVR4.bnd file from the ZIP file has
      *         been uploaded to a QSRVSRC file in your library list.
      *     - Run the following commands:
      *>        CRTRPGMOD CSVR4 SRCFILE(*LIBL/QRPGLESRC) DBGVIEW(*LIST)
      *>        CRTSRVPGM CSVR4 MODULE(CSVR4) EXPORT(*SRCFILE) -
      *>                  SRCFILE(*LIBL/QSRVSRC)
      *     - (First time only) run the following commands:
      *> ign:   CRTBNDDIR CSV
      *> ign:   ADDBNDDIRE CSV OBJ((*LIBL/CSVR4 *SRVPGM))
      *
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
      *                                                                             +
     H NOMAIN OPTION(*SRCSTMT: *NOSHOWCPY) BNDDIR('QC2LE')

      /copy csv_h
      /copy iconv_h
      /copy ifsio_h

     D LINEFEED        C                   X'25'
     D ULINEFEED       C                   U'000A'
     D CARRTN          C                   X'0D'
     D UCARRTN         C                   U'000D'

     D stmf_t          ds                  qualified template
     D  fd                           10i 0 inz
     D  ccsid                        10i 0 inz
     D  bufAlloc                     10i 0 inz
     D  chunkSize                    10i 0 inz
     D  buf                            *   inz
     D  bufPos                         *   inz
     D  bufLen                       10i 0 inz
     D  unicode                       1n   inz(*off)

     D CSVFILE_t       ds                  qualified
     D    fp                           *           inz(*NULL)
     D    buf                     65502A   varying inz('')
     D    bufpos                     10I 0         inz(0)
     D    flddel                      1A           inz(',')
     D    strdel1                     1A           inz('"')
     D    strdel2                     1A           inz('''')
     D    data                         *           inz(*NULL)
     D    dataLen                    10u 0         inz(0)
     D    dataPos                    10u 0         inz(0)
     D    row                        10u 0         inz(0)
     D    unicode                     1n           inz(*off)
     D    unibuf                  65502C   varying inz('') ccsid(1200)

     D BUFMAX          C                   %len(CSVFILE_t.buf)
     D BUFMAXUNI       C                   %len(CSVFILE_t.unibuf)

     D GetFromData     PR              *
     D   peHandle                      *   value
     D GetFromDataUni  PR              *
     D   peHandle                      *   value
     D GetFldEbc       PR             1N
     D   peHandle                          like(CSV_HANDLE) value
     D   peFldData                65502A   varying
     D GetFldUni       PR             1N
     D   peHandle                          like(CSV_HANDLE) value
     D   peFldData                65502C   varying ccsid(1200)
     D getJobCCSID     PR            10i 0
     D findEOL         PR              *
     D   bufPos                        *   value
     D   len                         10u 0 value
     D   unicode                      1n   const

     D stmfOpen        PR              *
     D   pathName                  5000a   varying const
     D   ccsid                       10i 0 const
     D stmfClose       PR
     D  stmf                           *   value
     D stmfReadline    PR            10i 0
     D  stmf                           *   value
     D  dst                            *   value
     D  size                         10u 0 value
     D stmfRewind      PR
     D  fp                             *   value

     D ReportError     PR
     D   peMsg                      256a   varying const
     D                                     options(*varsize:*nopass:*omit)

     D memchr          pr              *   extproc(*CWIDEN:'memchr')
     D   buf                           *   value
     D   chr                          1a   value
     D   len                         10u 0 value

     D memcpy          pr              *   extproc(*CWIDEN:'memcpy')
     D   dst                           *   value
     D   src                           *   value
     D   len                         10u 0 value

     D loadrec_ebc     PR             1N
     D   peHandle                          like(CSV_HANDLE) value
     D loadrec_uni     PR             1N
     D   peHandle                          like(CSV_HANDLE) value


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * CSV_open(): open a delimited text file
      *
      *    peFilename = (input) IFS pathname to file to open
      *     peStrDel1 = (input/omit) String delimiter
      *                  if *OMIT, a double-quote character is used
      *     peStrDel2 = (input/omit) Secondary string delimiter
      *                  if *OMIT, a single-quote character is used
      *      peFldDel = (input/omit) Field delimiter
      *                  if *OMIT, a comma is used
      *     peUnicode - (input/omit) open/process the file as Unicode
      *                  data rather than EBCDIC. Default: *OFF
      *
      * returns a CSV_HANDLE used to track the opened file
      *        or an *ESCAPE message upon error
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     P CSV_open        B                   export
     D CSV_open        PI                  like(CSV_HANDLE)
     D   peFilename                5000A   varying const options(*varsize)
     D   peStrDel1                    1A   const options(*omit:*nopass)
     D   peStrDel2                    1A   const options(*omit:*nopass)
     D   peFldDel                     1A   const options(*omit:*nopass)
     D   peUnicode                    1n   const options(*omit:*nopass)

     D myCSV           ds                  likeds(CSVFILE_t)
     D                                     inz(*LIKEDS)
     D CSV             ds                  likeds(CSVFILE_t)
     D                                     based(p_CSV)

      /free
         if (%parms>=2 and %addr(peStrDel1)<>*NULL);
            myCSV.StrDel1 = peStrDel1;
         endif;
         if (%parms>=3 and %addr(peStrDel2)<>*NULL);
            myCSV.StrDel2 = peStrDel2;
         endif;
         if (%parms>=4 and %addr(peFldDel)<>*NULL);
            myCSV.FldDel = peFldDel;
         endif;

         if (%parms>=5 and %addr(peUnicode)<>*NULL);
            myCSV.unicode = peUnicode;
         endif;

         if myCSV.unicode = *on;
            myCSV.fp = stmfOpen(peFilename: 1200);
         else;
            myCSV.fp = stmfOpen(peFilename: 0);
         endif;

         if myCSV.fp = *null;
            ReportError();
         endif;

         myCSV.buf = '';
         myCSV.unibuf = '';

         monitor;
            p_CSV = %alloc(%size(CSV));
         on-error;
            ReportError('Unable to allocate memory.');
         endmon;

         CSV = myCSV;
         csv_rewindrec(p_CSV);
         return p_CSV;
      /end-free
     P                 E


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
     P CSV_openBuf     B                   export
     D CSV_openBuf     PI                  like(CSV_HANDLE)
     D   peBuffer                      *   value
     D   peBufLen                    10u 0 value
     D   peBufCCSID                   5u 0 value
     D   peStrDel1                    1A   const options(*omit:*nopass)
     D   peStrDel2                    1A   const options(*omit:*nopass)
     D   peFldDel                     1A   const options(*omit:*nopass)
     D   peUnicode                    1n   const options(*omit:*nopass)

     D myCSV           ds                  likeds(CSVFILE_t)
     D                                     inz(*LIKEDS)
     D CSV             ds                  likeds(CSVFILE_t)
     D                                     based(p_CSV)

     D JobCCSID        s             10i 0 inz(0)

     D src             ds                  likeds(QtqCode_t) inz(*likeds)
     D dst             ds                  likeds(QtqCode_t) inz(*likeds)
     D ic              ds                  likeds(iconv_t)
     D srcptr          s               *   inz(*null)
     D dstptr          s               *   inz(*null)
     D srcleft         s             10u 0 inz(0)
     D dstleft         s             10u 0 inz(0)
     D rc              s             10u 0 inz(0)
     D needTranslate   s              1n

      /free
         if (%parms>=2 and %addr(peStrDel1)<>*NULL);
            myCSV.StrDel1 = peStrDel1;
         endif;
         if (%parms>=3 and %addr(peStrDel2)<>*NULL);
            myCSV.StrDel2 = peStrDel2;
         endif;
         if (%parms>=4 and %addr(peFldDel)<>*NULL);
            myCSV.FldDel = peFldDel;
         endif;
         if (%parms>=5 and %addr(peUnicode)<>*NULL);
            myCSV.Unicode = peUnicode;
         endif;

         myCSV.data = %alloc(peBufLen);
         myCSV.dataLen = 0;
         myCSV.dataPos = 0;

         JobCCSID = getJobCCSID();

         src.CCSID = peBufCCSID;
         dst.CCSID = 0;

         if (myCSV.Unicode = *on);
           dst.CCSID = 1200;
         endif;

         needTranslate = *off;

         if myCSV.Unicode = *on;
            if src.CCSID<>1200 and src.CCSID<>13488;
               needTranslate = *on;
            endif;
         else;
            if src.CCSID<>0 and src.CCSID<>JobCCSID;
               needTranslate = *on;
            endif;
         endif;

         if needTranslate = *on;

            ic = QtqIconvOpen( dst: src );
            if (ic.return_value = -1);
               dealloc myCSV.data;
               myCSV.data = *null;
               ReportError();
            endif;

            srcptr  = peBuffer;
            srcleft = peBufLen;
            dstptr  = myCSV.data;
            dstleft = peBufLen;

            rc = iconv(ic: srcptr: srcleft: dstptr: dstleft);
            iconv_close(ic);

            if rc = ICONV_FAIL;
               dealloc myCSV.data;
               myCSV.data = *null;
               ReportError();
            endif;

            myCSV.dataLen = peBufLen - dstleft;
         else;
            memcpy(myCSV.data: peBuffer: peBufLen);
            myCSV.dataLen = peBufLen;
         endif;

         p_CSV = %alloc(%size(CSV));
         CSV = myCSV;

         csv_rewindrec(p_CSV);
         return p_CSV;
      /end-free
     P                 E


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * CSV_loadrec(): Load a record from a delimited file into memory
      *
      *     peHandle = (i/o) handle to file returned by CSV_open()
      *
      * Returns *ON if successful, *OFF upon failure or EOF
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     P CSV_loadrec     B                   export
     D CSV_loadrec     PI             1N
     D   peHandle                          like(CSV_HANDLE) value

     D CSV             DS                  likeds(CSVFILE_t)
     D                                     based(peHandle)

     D rc              s              1n

      /free
         if (CSV.unicode);
            rc = loadrec_uni(peHandle);
         else;
            rc = loadrec_ebc(peHandle);
         endif;

         return rc;
      /end-free
     P                 E


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * loadrec_ebc(): Load a record from a delimited file into memory
      *
      *     peHandle = (i/o) handle to file returned by CSV_open()
      *
      * Returns *ON if successful, *OFF upon failure or EOF
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     P loadrec_ebc     B                   export
     D loadrec_ebc     PI             1N
     D   peHandle                          like(CSV_HANDLE) value

     D CSV             DS                  likeds(CSVFILE_t)
     D                                     based(peHandle)

     D p_buf           s               *
     D len             s             10I 0

      /free

         %len(CSV.buf) = BUFMAX;

         if (CSV.fp <> *NULL);

            len = stmfReadline( CSV.fp
                              : %addr(CSV.buf: *data)
                              : BUFMAX );
            if len < 1;
               CSV.buf = '';
               return *off;
            endif;
            %len(CSV.buf) = len;
         else;

            p_buf = GetFromData( peHandle );
            len = %len(CSV.buf);
            if (p_buf = *NULL);
               return *OFF;
            endif;

         endif;

         if (len > 1 and %subst(CSV.buf : len : 1) = LINEFEED );
            len = len - 1;
            %len(CSV.buf) = len;
         endif;

         if (len > 1 and %subst(CSV.buf : len : 1) = CARRTN );
            len = len - 1;
            %len(CSV.buf) = len;
         endif;

         CSV.row += 1;
         csv_rewindrec(peHandle);

         return *ON;
      /end-free
     P                 E


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * loadrec_uni(): Load a record from a delimited file into memory
      *
      *     peHandle = (i/o) handle to file returned by CSV_open()
      *
      * Returns *ON if successful, *OFF upon failure or EOF
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     P loadrec_uni     B                   export
     D loadrec_uni     PI             1N
     D   peHandle                          like(CSV_HANDLE) value

     D CSV             DS                  likeds(CSVFILE_t)
     D                                     based(peHandle)

     D p_buf           s               *
     D len             s             10I 0
     D pos             s             10u 0
     D null            s              1C   inz(U'0000') ccsid(1200)

      /free

         %len(CSV.unibuf) = BUFMAXUNI;

         if (CSV.fp <> *NULL);

            len = stmfReadline( CSV.fp
                              : %addr(CSV.unibuf: *data)
                              : BUFMAXUNI * 2 );
            if len < 1;
               CSV.unibuf = '';
               return *off;
            endif;
            len = %div(len: 2);
            %len(CSV.unibuf) = len;
         else;

            p_buf = GetFromDataUni( peHandle );
            len = %len(CSV.unibuf);
            if (p_buf = *NULL);
               return *OFF;
            endif;

         endif;

         if (len > 1 and %subst(CSV.unibuf : len : 1) = ULINEFEED );
            len = len - 1;
            %len(CSV.unibuf) = len;
         endif;

         if (len > 1 and %subst(CSV.unibuf : len : 1) = UCARRTN );
            len = len - 1;
            %len(CSV.unibuf) = len;
         endif;

         CSV.row += 1;
         csv_rewindrec(peHandle);

         return *ON;
      /end-free
     P                 E


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * CSV_rewindfile():  Move file cursor back to the start
      *                    (so you can re-read from the beginning)
      *
      *   peHandle = (i/o) handle to file returned by CSV_open
      *
      * Returns *ON if successful, *OFF otherwise.
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     P CSV_rewindfile  B                   EXPORT
     D CSV_rewindfile  PI             1N
     D   peHandle                          like(CSV_HANDLE) value

     D CSV             DS                  likeds(CSVFILE_t)
     D                                     based(peHandle)
      /free
       if CSV.fp <> *null;
         stmfRewind(CSV.fp);
       endif;
       CSV.dataPos = 0;
       csv_rewindrec(peHandle);
       return *ON;
      /end-free
     P                 E


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
     P CSV_getfld      B                   export
     D CSV_getfld      PI             1N
     D   peHandle                          like(CSV_HANDLE) value
     D   peFldData                65502A   varying options(*varsize)
     D   peVarSize                   10I 0 value

     D CSV             DS                  likeds(CSVFILE_t)
     D                                     based(peHandle)
     D rc              s              1N
     D myEbcData       s          65502A   varying
     D myUniData       s          65502C   varying ccsid(1200)
     D max             s             10i 0
     D len             s             10i 0
      /free
         %len(peFldData) = 0;
         max = peVarSize - 2;

         if CSV.unicode = *on;

            rc = GetFldUni( peHandle: myUniData );
            if rc = *on;
               if max > %len(myUniData);
                  max = %len(myUniData);
               endif;
               if max > 0;
                  %len(peFldData) = max;
                  %subst(peFldData:1:max) = %char(myUniData);
               endif;
            endif;

         else;

            rc = GetFldEbc( peHandle: myEbcData );
            if rc = *on;
               if max > %len(myEbcData);
                  max = %len(myEbcData);
               endif;
               if max > 0;
                  %len(peFldData) = max;
                  %subst(peFldData:1:max) = myEbcData;
               endif;
            endif;

         endif;

         return rc;
      /end-free
     P                 E


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
     P CSV_getFldUni   B                   export
     D CSV_getFldUni   PI             1N
     D   peHandle                          like(CSV_HANDLE) value
     D   peFldData                65502C   varying options(*varsize) ccsid(1200)
     D   peVarSize                   10I 0 value

     D CSV             DS                  likeds(CSVFILE_t)
     D                                     based(peHandle)
     D rc              s              1N
     D myEbcData       s          65502A   varying
     D myUniData       s          65502C   varying ccsid(1200)
     D max             s             10i 0
     D len             s             10i 0
      /free
         %len(peFldData) = 0;
         max = %div(peVarSize - 2 : 2);

         if CSV.unicode = *on;

            rc = GetFldUni( peHandle: myUniData );
            if rc = *on;
               if max > %len(myUniData);
                  max = %len(myUniData);
               endif;
               if max > 0;
                  %len(peFldData) = max;
                  %subst(peFldData:1:max) = myUniData;
               endif;
            endif;

         else;

            rc = GetFldEbc( peHandle: myEbcData );
            if rc = *on;
               if max > %len(myEbcData);
                  max = %len(myEbcData);
               endif;
               if max > 0;
                  %len(peFldData) = max;
                  %subst(peFldData:1:max) = %ucs2(myEbcData);
               endif;
            endif;

         endif;

         return rc;
      /end-free
     P                 E


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * GetFldEbc():  Get next field when record is in EBCDIC format
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     P GetFldEbc       B                   export
     D GetFldEbc       PI             1N
     D   peHandle                          like(CSV_HANDLE) value
     D   peFldData                65502A   varying

     D UNQUOTED        C                   0
     D QUOTED          C                   1
     D ENDQUOTE        C                   2

     D CSV             DS                  likeds(CSVFILE_t)
     D                                     based(peHandle)

     D state           s             10i 0 inz(UNQUOTED)
     D len             s             10I 0
     D start           s             10I 0
     D pos             s             10I 0
     D char            s              1A   based(p_char)
     D qchar           s              1A

      /free

         len = %len(CSV.buf) - 1;
         start = CSV.bufpos;
         %len(peFldData) = 0;

         if (start > len);
             return *OFF;
         endif;

         for pos = start to len;

             p_char = %addr(CSV.buf: *data) + pos;

             select;
             when state = UNQUOTED;

                select;
                when char = CSV.flddel;
                   leave;
                when char = CSV.strdel1
                  or char = CSV.strDel2;
                   state = QUOTED;
                   qchar = char;
                when %len(peFldData) < BUFMAX;
                   peFldData += char;
                endsl;

             when state = QUOTED;

                 select;
                 when char = qchar;
                    state = ENDQUOTE;
                 when %len(peFldData) < BUFMAX;
                    peFldData += char;
                 endsl;

             when state = ENDQUOTE;

                select;
                when char = qchar;
                    state = QUOTED;
                    if (%len(peFldData) < BUFMAX);
                       peFldData += char;
                    endif;
                when char = CSV.flddel;
                    leave;
                when char = CSV.strdel1
                  or char = CSV.strDel2;
                    state = QUOTED;
                    qchar = char;
                when %len(peFldData) < BUFMAX;
                    state = UNQUOTED;
                    peFldData += char;
                endsl;

             endsl;

         endfor;

         CSV.bufpos = pos + 1;
         return *ON;
      /end-free
     P                 E


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * GetFldUni: Get next field when record is in Unicode format
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     P GetFldUni       B                   export
     D GetFldUni       PI             1N
     D   peHandle                          like(CSV_HANDLE) value
     D   peFldData                65502C   varying ccsid(1200)

     D UNQUOTED        C                   0
     D QUOTED          C                   1
     D ENDQUOTE        C                   2

     D CSV             DS                  likeds(CSVFILE_t)
     D                                     based(peHandle)

     D state           s             10i 0 inz(UNQUOTED)
     D len             s             10I 0
     D start           s             10I 0
     D pos             s             10I 0
     D char            s              1C   based(p_char) ccsid(1200)
     D qchar           s              1C   ccsid(1200)

      /free

         len = %len(CSV.unibuf) - 1;
         start = CSV.bufpos;
         %len(peFldData) = 0;

         if (start > len);
             return *OFF;
         endif;

         for pos = start to len;

             p_char = %addr(CSV.unibuf: *data) + (pos * %size(char));

             select;
             when state = UNQUOTED;

                select;
                when char = %ucs2(CSV.flddel);
                   leave;
                when char = %ucs2(CSV.strdel1)
                  or char = %ucs2(CSV.strDel2);
                   state = QUOTED;
                   qchar = char;
                when %len(peFldData) < BUFMAXUNI;
                   peFldData += char;
                endsl;

             when state = QUOTED;

                 select;
                 when char = qchar;
                    state = ENDQUOTE;
                 when %len(peFldData) < BUFMAXUNI;
                    peFldData += char;
                 endsl;

             when state = ENDQUOTE;

                select;
                when char = qchar;
                    state = QUOTED;
                    if (%len(peFldData) < BUFMAXUNI);
                       peFldData += char;
                    endif;
                when char = %ucs2(CSV.flddel);
                    leave;
                when char = %ucs2(CSV.strdel1)
                  or char = %ucs2(CSV.strDel2);
                    state = QUOTED;
                    qchar = char;
                when %len(peFldData) < BUFMAXUNI;
                    state = UNQUOTED;
                    peFldData += char;
                endsl;

             endsl;

         endfor;

         CSV.bufpos = pos + 1;
         return *ON;
      /end-free
     P                 E


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * CSV_rewindrec():  Move field cursor back to the start
      *                  (so you can re-read fields from this record)
      *
      *   peHandle = (i/o) handle to file returned by CSV_open
      *
      * Returns *ON if successful, *OFF otherwise.
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     P CSV_rewindrec   B                   EXPORT
     D CSV_rewindrec   PI             1N
     D   peHandle                          like(CSV_HANDLE) value

     D CSV             DS                  likeds(CSVFILE_t)
     D                                     based(peHandle)
      /free
         CSV.bufpos = 0;
         return *ON;
      /end-free
     P                 E


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
     P CSV_close       B                   export
     D CSV_close       PI
     D   peHandle                          like(CSV_HANDLE)
     D CSV             DS                  likeds(CSVFILE_t)
     D                                     based(p_CSV)

      /free

         p_CSV = peHandle;

         if CSV.fp <> *null;
            stmfClose(CSV.fp);
            CSV.fp = *null;
         endif;

         if (CSV.data <> *null);
            dealloc CSV.data;
            CSV.data = *null;
            CSV.dataLen = 0;
            CSV.dataPos = 0;
         endif;

         dealloc p_CSV;
         peHandle = *null;

      /end-free
     P                 E


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * GetFromData(): Read one record (line of text) from a data buffer
      *
      *   peHandle = (input) CSV handle to use
      *
      * Returns pointer to record buffer, or *NULL upon error
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     P GetFromData     B
     D GetFromData     PI              *
     D   peHandle                      *   value

     D CSV             ds                  likeds(CSVFILE_t)
     D                                     based(peHandle)

     D lineLen         s             10u 0
     D copyLen         s             10u 0
     D sol             s               *
     D eol             s               *

      /free
       if CSV.dataPos >= CSV.dataLen;
          return *NULL;
       endif;

       sol = CSV.data + CSV.dataPos;

       eol = findEOL( sol: CSV.dataLen - CSV.dataPos: *off);
       if eol = *null;
          eol = CSV.data + (CSV.dataLen - 1);
       endif;

       lineLen = (eol - sol) + 1;
       copyLen = lineLen;
       if copyLen > BUFMAX;
          copyLen = BUFMAX;
       endif;

       %len(CSV.buf) = copyLen;
       memcpy( %addr(CSV.buf : *data): sol: copyLen);
       CSV.dataPos += lineLen;

       return %ADDR(CSV.buf : *DATA);
      /end-free
     P                 E


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * GetFromDataUni(): Read one record (line of text) from a data
      *                    buffer
      *
      *   peHandle = (input) CSV handle to use
      *
      * Returns pointer to record buffer, or *NULL upon error
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     P GetFromDataUni  B
     D GetFromDataUni  PI              *
     D   peHandle                      *   value

     D CSV             ds                  likeds(CSVFILE_t)
     D                                     based(peHandle)

     D lineLen         s             10u 0
     D copyLen         s             10u 0
     D sol             s               *
     D eol             s               *
     D scanLen         s             10u 0

      /free
       if CSV.dataPos >= CSV.dataLen;
          return *NULL;
       endif;

       sol = CSV.data + CSV.dataPos;
       scanLen = CSV.dataLen - CSV.dataPos;

       eol = findEOL( sol: scanLen: *on);
       if eol = *null;
          eol = CSV.data + (CSV.dataLen - 2);
       endif;

       lineLen = (eol - sol) + 2;
       copyLen = lineLen;
       if copyLen > BUFMAXUNI * 2;
          copyLen = BUFMAXUNI * 2;
       endif;

       %len(CSV.unibuf) = %div(copyLen : 2);
       memcpy( %addr(CSV.unibuf : *DATA): sol: copyLen);
       CSV.dataPos += lineLen;

       return %ADDR(CSV.unibuf : *DATA);
      /end-free
     P                 E


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * ReportError():  Send an escape message explaining any errors
      *                 that occurred.
      *
      *    peMsg = (input/optional) if passed, this message will
      *                 be sent as CPF9897 to calling application.
      *                 if not passed, CPExxxx will be sent, where
      *                 xxxx is the ILE C errno value.
      *
      * Calling this subproc terminates the service program.
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     P ReportError     B
     D ReportError     PI
     D   peMsg                      256a   varying const
     D                                     options(*varsize:*nopass:*omit)

     D my_errno_func   PR              *   ExtProc('__errno')
     D my_errno        s             10I 0 based(p_my_errno)

     D QMHSNDPM        PR                  ExtPgm('QMHSNDPM')
     D   MessageID                    7A   Const
     D   QualMsgF                    20A   Const
     D   MsgData                  32767A   Const options(*varsize)
     D   MsgDtaLen                   10I 0 Const
     D   MsgType                     10A   Const
     D   CallStkEnt                  10A   Const
     D   CallStkCnt                  10I 0 Const
     D   MessageKey                   4A
     D   ErrorCode                32767A   options(*varsize)

     D ErrorCode       DS                  qualified
     D  BytesProv                    10I 0 inz(0)
     D  BytesAvail                   10I 0 inz(0)

     D MsgKey          S              4A
     D MsgID           s              7A
     D MsgDta          s            256a   varying

      /free

         if  %parms>=1 and %addr(peMsg)<>*null;
            MsgId = 'CPF9897';
            MsgDta = peMsg;
         else;
            p_my_errno = my_errno_func();
            MsgID = 'CPE' + %editc( %dec(my_errno:4:0) : 'X' );
            %len(MsgDta) = 0;
         endif;

         QMHSNDPM( MsgID
                 : 'QCPFMSG   *LIBL'
                 : MsgDta
                 : %len(MsgDta)
                 : '*ESCAPE'
                 : '*PGMBDY'
                 : 1
                 : MsgKey
                 : ErrorCode         );

      /end-free
     P                 E


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * getJobCCSID(): Returns the CCSID of the current job
      *                if the job is 65535, returns the default CCSID
      *
      * returns the CCSID, or 0 upon failure
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     P getJobCCSID     B
     D getJobCCSID     PI            10i 0

     D QUSRJOBI        PR                  ExtPgm('QSYS/QUSRJOBI')
     D   rcvvar                   65535a   options(*varsize)
     D   rcvvarlen                   10i 0 const
     D   format                       8a   const
     D   qualJob                     26a   const
     D   intJobId                    16a   const
     D   errorcode                32767a   options(*varsize)

     D JOBI0400        ds          1024    qualified
     D   CCSID                       10i 0 overlay(JOBI0400:301) inz
     D   DftCCSID                    10i 0 overlay(JOBI0400:373) inz

     D errorCode       ds                  qualified
     D   bytesProv                   10i 0 inz
     D   bytesAvail                  10i 0 inz

      /free

       monitor;
         QUSRJOBI( JOBI0400
                 : %size(JOBI0400)
                 : 'JOBI0400'
                 : '*'
                 : *blanks
                 : errorCode );
       on-error;
         reset JOBI0400;
       endmon;

       if JOBI0400.CCSID = 65535;
          JOBI0400.CCSID = JOBI0400.DftCCSID;
       endif;

       return JOBI0400.CCSID;
      /end-free
     P                 E


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * stmfOpen(): Open a stream file for buffered reading
      *
      *   pathName = (input) IFS path to file to open
      *      ccsid = (input) CCSID to read data into (i.e. CCSID of
      *                      variables in this program)
      *
      * returns a pointer to the stream file instance
      *      or *NULL upon failure
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     P stmfOpen        B
     D                 PI              *
     D   pathName                  5000a   varying const
     D   ccsid                       10i 0 const

     D p_stmf          s               *   inz(*null)
     D stmf            ds                  likeds(stmf_t)
     D                                     based(p_stmf)
     D vfs             ds                  likeds(ds_statvfs)

      /free

       p_stmf = %alloc(%size(stmf));

       stmf.fd = open( %trim(pathName)
                     : O_RDONLY + O_CCSID + O_TEXTDATA + O_LARGEFILE
                     : 0
                     : ccsid );

       if stmf.fd = -1;
          dealloc p_stmf;
          ReportError();
          return *null;
       endif;

       // Calculate an optimal chunk size to use when reading data
       //  for this file based on the optimal size for the file system
       //  it is located in.

       stmf.chunkSize = 64 * 1024;
       if fstatvfs( stmf.fd: vfs ) = 0
          and vfs.f_bsize >= 256
          and vfs.f_bsize <= 65536;
          stmf.chunkSize = vfs.f_bsize;
       endif;

       // Set up buffer for reading 10 chunks a at a time.

       stmf.bufAlloc = stmf.chunkSize * 10;
       stmf.buf      = %alloc(stmf.bufAlloc);
       stmf.bufPos   = stmf.buf;
       stmf.bufLen   = 0;
       stmf.ccsid    = ccsid;
       stmf.unicode  = *off;

       if stmf.ccsid = 1200 or stmf.ccsid = 13488;
          stmf.unicode = *on;
       endif;

       return p_stmf;
      /end-free
     P                 E


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * stmfClose():  Close a buffered stream file
      *
      *   fp = (input) pointer to file as returned by stmfOpen
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     P stmfClose       B
     D                 PI
     D  fp                             *   value

     D stmf            ds                  likeds(stmf_t)
     D                                     based(fp)
      /free

       if stmf.fd <> -1 and close(stmf.fd) <> 0;
          ReportError();
       endif;

       dealloc stmf.buf;
       stmf.fd       = -1;
       stmf.buf      = *null;
       stmf.bufPos   = *null;
       stmf.bufAlloc = 0;

      /end-free
     P                 E


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      *  stmfReadLine(): Read line from a buffered stream file
      *
      *      fp = (input) pointer to stream file opened by stmfOpen
      *     dst = (input) pointer to buffer that line is read into
      *    size = (input) size of buffer that line is read into
      *
      *  returns the length of data read into the buffer
      *      or  0 if the buffer size was too small
      *      or -1 upon failure
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     P stmfReadLine    B
     D                 PI            10i 0
     D  fp                             *   value
     D  dst                            *   value
     D  size                         10u 0 value

     D stmf            ds                  likeds(stmf_t)
     D                                     based(fp)

     D left            s             10u 0
     D len             s             10u 0
     D pos             s               *
     D resultLen       s             10i 0

      /free

        if size <= 0;
           return 0;
        endif;

        left = size;

        dow left > 0;

           len = stmf.bufLen;
           if len > left;
              len = left;
           endif;

           if len > 0;
              pos = findEOL( stmf.bufPos: len: stmf.unicode);

              // ----------------------------------------------
              // EOL character found in buffer
              //   -- copy up to the EOL into result
              //   -- advance buffer
              // ----------------------------------------------

              if pos <> *null;

                 if (stmf.unicode);
                    len = (pos - stmf.bufPos) + 2;
                 else;
                    len = (pos - stmf.bufPos) + 1;
                 endif;
                 memcpy(dst: stmf.bufPos: len);
                 stmf.bufLen -= len;
                 left -= len;

                 if stmf.bufLen > 0;
                    stmf.bufPos += len;
                 endif;

                 leave;

              endif;

              // ----------------------------------------------
              // EOL character not found in buffer
              //   -- copy whatever is available now
              //   -- try to get more data
              // ----------------------------------------------

              memcpy(dst: stmf.bufPos: len);
              stmf.bufLen -= len;
              dst  += len;
              left -= len;

              if stmf.bufLen > 0;
                 stmf.bufPos += len;
              endif;

           endif;

           // ----------------------------------------------
           // At this point there should be nothing left
           // in the buffer because either an EOL was found
           // (and therefore, it would not get here) or the
           // entire remainder of the buffer was used.
           //
           // Therefore, try to get more from the file.
           // ----------------------------------------------

           stmf.bufPos = stmf.buf;
           len = read(stmf.fd: stmf.buf: stmf.bufAlloc );

           select;
           when len = 0;
              stmf.bufLen = len;
              leave;
           when len = -1;
              stmf.bufLen = 0;
              return -1;
           other;
              stmf.bufLen = len;
              // continue loop
           endsl;

        enddo;

        resultLen = size - left;
        return resultLen;

      /end-free
     P                 E


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * stmfRewind(): Reposition buffered stream file back to the start
      *
      *   fp = (input) pointer to file as returned by stmfOpen
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     P stmfRewind      B
     D                 PI
     D  fp                             *   value

     D stmf            ds                  likeds(stmf_t)
     D                                     based(fp)
      /free
       if stmf.fd <> -1;
          lseek( stmf.fd: 0: SEEK_SET);
          stmf.bufPos = stmf.buf;
          stmf.bufLen = 0;
       endif;
      /end-free
     P                 E


      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      * findEOL(): Search for the line feed character (x'25' or x'000A')
      *            within a buffer.
      *
      *   bufPos = (input) pointer to buffer position to search
      *      len = (input) length of area to search
      *  unicode = (input) whether the EOF is Unicode (vs. EBCDIC)
      *
      * Returns a pointer to the buffer position, or *NULL if not found
      *+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
     P findEOL         B
     D                 PI              *
     D   bufPos                        *   value
     D   len                         10u 0 value
     D   unicode                      1n   const

     D eol             s               *
     D scanLen         s             10u 0
     D p_char          s               *
     D char            s              1C   CCSID(1200) based(p_char)
      /free

       if not unicode;

          // The sample data file I was used had x'0D' as an end
          // of line character not x'0A'
          eol = memchr( bufPos: LINEFEED: len);
          if eol = *null;
            eol = memchr( bufPos: CARRTN: len);
          endif;

          return eol;
       else;

          eol = *null;
          p_char = bufPos;

          dow len >= %size(char);
             if char = ULINEFEED;
               eol = p_char;
               leave;
             endif;
             p_char += %size(char);
             len -= %size(char);
          enddo;

          return eol;
       endif;

      /end-free
     P                 E
