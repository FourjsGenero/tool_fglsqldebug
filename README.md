# FGLSQLDEBUG log viewer

## Description

This tool can read an FGLSQLDEBUG output, to show the log records in a graphical interface.
You can then sort, search and filter log records, to find what you are looking for.

![FGLSQLDEBUG viewer (GDC)](https://github.com/FourjsGenero/tool_fglsqldebug/raw/master/docs/fglsqldebug-screen-001.png)

## Prerequisites

* Genero BDL 3.20+
* Genero Browser Client 1.00.52+
* Genero Desktop Client 3.20+
* Genero Studio 3.20+
* GNU Make

## Compilation from command line

1. make clean all

## Compilation in Genero Studio

1. Load the fglsqldebug.4pw project
2. Build the project

## Usage

1. Get an FGLSQLDEBUG log to analyze
2. Define FGLSOURCEPATH to the .4gl sources that generated the FGLSQLDEBUG log
3. Run the tool with fglrun fglsqldebug [-f logfile [-r]]
4. In the first field, you can load another log file
5. Use the Filter panel on bottom of the form to filter log records
6. Run profiling statistics for find time consuming SQL statements

The log records are loaded into an SQLite database created automatically if it does not exist.
One database file is created for each log.
By default, the tool does not re-parse the log file if the database exists already.
You can force a re-parsing with the -r option.

The tool can also show the source file, if the FGLSOURCEPATH environment variables is defined.

## See also

See [Genero BDL documentation](http://www.4js.com/download/documentation) for more details about
FGLSQLDEBUG and FGLSOURCEPATH environment variables.


## Bug fixes:

- 1.01: Multiple directories in FGLSOURCEPATH
- 1.02: Bug fixes
- 1.03: Global statistics
- 1.04: Avoid freezing program (with IFX) when trying SELECT to check DB availability
