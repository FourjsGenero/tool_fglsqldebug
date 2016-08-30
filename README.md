# FGLSQLDEBUG log viewer

## Compilation (Linux only):

1. make clean all

## Usage:

1. Get an FGLSQLDEBUG log to analyze
2. Run the tool with fglrun fglsqldebug [-f logfile [-r]]
3. In the first field, you can load another log file
4. Use the Filter panel on bottom of the form to filter log records

The log records are loaded into an SQLite database created automatically if it does not exist.
One database file is created for each log.
By default, the tool does not re-parse the log file if the database exists already.
You can force a re-parsing with the -r option.


