Service program for reading CSV files into an RPG program.
                                      Scott Klement, November 25, 2008

To get started, upload the source members.  To make this easy, I've provided
an FTP script that will upload them for you (if FTP is available).  To use it:

a) Extract the ZIP file to a temporary directory
b) Open a command-line (DOS) prompt.
c) Navigate to the directory where you unzipped the code
d) run the following:

     ftpsrc x.x.x.x MYLIB MYUSERID MYPASSWORD

     replace x.x.x.x with the IP address or hostname of your IBM i,
     replace MYLIB with the name of the library to upload to,
     replace MYUSERID and MYPASSWORD with your userid/password

If FTP isn't available, or you'd prefer to upload the members manually,
you may do so according to the following table:

PC file name        IBM i Source File & Member
------------        ----------------------------
csvr4.bnd      ->   QSRVSRC     CSVR4
ifsio_h.rpgle  ->   QRPGLESRC   IFSIO_H
csv_h.rpgle    ->   QRPGLESRC   CSV_H
iconv_h.rpgle  ->   QRPGLESRC   ICONV_H
csvr4.rpgle    ->   QRPGLESRC   CSVR4
csvdemo.rpgle  ->   QRPGLESRC   CSVDEMO
csvdemo2.rpgle ->   QRPGLESRC   CSVDEMO2
csvdemo3.rpgle ->   QRPGLESRC   CSVDEMO3
csvdemo4.rpgle ->   QRPGLESRC   CSVDEMO4
csvdemo5.rpgle ->   QRPGLESRC   CSVDEMO5
csvtest.rpgle  ->   QRPGLESRC   CSVTEST
csvinto.rpgle  ->   QRPGLESRC   CSVINTO

Instructions on how to compile the source are found at the top of each
member. They should be built in the following order:

- CSVR4 (main service program)
- CSVDEMO 
- CSVDEMO4
- CSVTEST

- CSVINTO (data-into support, requires IBM i 7.2+)
- CSVDEMO2
- CSVDEMO3
- CSVDEMO5

You can skip the last four if you don't plan to use this with data-into. More detail may be found here:

http://www.scottklement.com/csv/
