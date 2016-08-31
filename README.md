# FGLSQLDEBUG log viewer

## Description

This tool can read an FGLSQLDEBUG output, to show the log records in a graphical interface.
You can then sort, search and filter log records, to find what you are looking for.

Log records can be filtered on:
* BDL cursor name
* BDL source
* Execution time
* SQL errors
* USING variable usage
* INTO variable usage
* SQL keyword

## Prerequisites

* Genero BDL 3.00+
* Genero Desktop Client 3.00+
* GNU Make

## Compilation

1. make clean all

## Usage

1. Get an FGLSQLDEBUG log to analyze
2. Define FGLSOURCEPATH to the .4gl sources that generated the FGLSQLDEBUG log.
3. Run the tool with fglrun fglsqldebug [-f logfile [-r]]
4. In the first field, you can load another log file
5. Use the Filter panel on bottom of the form to filter log records

The log records are loaded into an SQLite database created automatically if it does not exist.
One database file is created for each log.
By default, the tool does not re-parse the log file if the database exists already.
You can force a re-parsing with the -r option.

The tool can also show the source file, if the FGLSOURCEPATH environment variables is defined.

## See also

See [Genero BDL documentation](http://www.4js.com/download/documentation) for more details about
FGLSQLDEBUG and FGLSOURCEPATH environment variables.


