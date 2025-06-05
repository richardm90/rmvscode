      CMD PROMPT('Seed CUSDET Table')

      PARM KWD(TRUNCATE) +
            TYPE(*NAME) +
            LEN(4) +
            RSTD(*YES) +
            DFT(*YES) +
            SPCVAL((*YES) (*NO)) +
            PROMPT('TRUNCATE CUSDET')

      PARM KWD(CSVSTMF) +
           TYPE(*PNAME) +
           LEN(5000) +
           MIN(1) +
           VARY(*YES *INT2) +
           CASE(*MIXED) +
           PROMPT('CSV Data Stream File')
