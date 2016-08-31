IMPORT os
IMPORT util

CONSTANT TOOL_VERSION = "1.01"
CONSTANT TOOL_ABOUT_MSG = "\nFGLSQLDEBUG Viewer Version %1\n\nFour Js Development Tools 2016\n\n"

TYPE t_connection RECORD
         connid INTEGER,
         name VARCHAR(50),
         dbsrc VARCHAR(200),
         driver VARCHAR(50),
         dlib VARCHAR(500),
         dtype CHAR(3)
     END RECORD

TYPE t_sqlvar RECORD
         cmdid INTEGER,
         vartype CHAR(1),
         position SMALLINT,
         datatype VARCHAR(50),
         flags SMALLINT,
         value VARCHAR(500)
     END RECORD

TYPE t_drvmsg RECORD
         cmdid INTEGER,
         position SMALLINT,
         srcfile VARCHAR(50),
         srcline INTEGER,
         message VARCHAR(500)
     END RECORD

TYPE t_command RECORD
         cmdid INTEGER,
         connid INTEGER,
         fglcmd VARCHAR(30),
         srcfile VARCHAR(200),
         srcline INTEGER,
         fglcursor VARCHAR(50),
         sqlcursor VARCHAR(50),
         c_scroll CHAR(1),
         c_hold CHAR(1),
         sqlcode INTEGER,
         sqlerrd2 INTEGER,
         sqlerrmsg VARCHAR(200),
         sqlstate VARCHAR(10),
         fglsql VARCHAR(2000),
         natsql1 VARCHAR(2000),
         natsql2 VARCHAR(2000),
         exectime INTERVAL DAY TO FRACTION(5)
       END RECORD
TYPE t_command_att RECORD
         cmdid STRING,
         connid STRING,
         fglcmd STRING,
         srcfile STRING,
         srcline STRING,
         fglcursor STRING,
         sqlcursor STRING,
         c_scroll STRING,
         c_hold STRING,
         sqlcode STRING,
         sqlerrd2 STRING,
         sqlerrmsg STRING,
         sqlstate STRING,
         fglsql STRING,
         natsql1 STRING,
         natsql2 STRING,
         exectime STRING
       END RECORD

TYPE t_params RECORD
         filename STRING,
         current_cursor STRING,
         current_source STRING,
         exec_time DATETIME HOUR TO SECOND,
         exec_time_frac INTEGER,
         only_errors BOOLEAN,
         with_uvars BOOLEAN,
         with_ivars BOOLEAN,
         find_keyword STRING
       END RECORD

DEFINE log_arr DYNAMIC ARRAY OF t_command
DEFINE log_att DYNAMIC ARRAY OF t_command_att
DEFINE uvars DYNAMIC ARRAY OF t_sqlvar
DEFINE ivars DYNAMIC ARRAY OF t_sqlvar

DEFINE fglsourcepath STRING

MAIN
    CALL check_front_end()
    OPTIONS INPUT WRAP
    --DEFER INTERRUPT DEFER QUIT
    LET fglsourcepath = fgl_getenv("FGLSOURCEPATH")
    CALL process_arguments()
END MAIN

FUNCTION check_front_end()
    DEFINE fen STRING
    LET fen = ui.Interface.getFrontEndName()
    IF fen!="GDC" AND fen!="GWC" AND fen!="GBC" THEN
       DISPLAY "ERROR: This tool is designed for desktop front-ends (GDC, GWC, GBC)"
       EXIT PROGRAM 1
    END IF
END FUNCTION

FUNCTION process_arguments()
    DEFINE filename STRING,
           force_reload BOOLEAN

    IF cmdarg_option_used("h") THEN
       CALL show_usage()
       EXIT PROGRAM 0
    END IF

    IF cmdarg_option_check( 1, "h|f+|r" ) != 0 THEN
       CALL show_usage()
       EXIT PROGRAM 1
    END IF

    LET filename = cmdarg_option_param("f")
    LET force_reload = cmdarg_option_used("r")

    CALL do_monitor(filename, force_reload)

END FUNCTION

FUNCTION do_monitor(filename, force_reload)
    DEFINE filename STRING,
           force_reload BOOLEAN
    DEFINE params t_params,
           x INTEGER

    OPEN FORM f1 FROM "fglsqldebug"
    DISPLAY FORM f1
    CALL ui.Interface.refresh()

    LET params.filename = filename
    LET params.exec_time = "00:00:00"
    LET params.exec_time_frac = 0
    LET params.only_errors = FALSE
    LET params.with_uvars = FALSE
    LET params.with_ivars = FALSE
    LET params.find_keyword = NULL

    IF filename IS NOT NULL THEN
       IF NOT load_file(filename, force_reload) THEN
          CALL mbox_ok(SFMT("Could not load FGLSQLDEBUG log from:\n%1", filename))
          LET params.filename = NULL
       END IF
    END IF

    CALL fill_cursor_list(NULL)
    CALL fill_source_list(NULL)

    DIALOG ATTRIBUTES(UNBUFFERED)

    DISPLAY ARRAY log_arr TO sr.* ATTRIBUTES(DOUBLECLICK=source)
        BEFORE ROW
           CALL sync_row_data(DIALOG,arr_curr())
           CALL setup_dialog(DIALOG,params.*)
        ON ACTION source
           CALL show_source(log_arr[arr_curr()].srcfile, log_arr[arr_curr()].srcline)
        ON ACTION details
            CALL show_driver_messages(log_arr[arr_curr()].cmdid)
    END DISPLAY

    DISPLAY ARRAY uvars TO sruv.*
    END DISPLAY
    DISPLAY ARRAY ivars TO sriv.*
    END DISPLAY

    INPUT BY NAME params.* ATTRIBUTES(WITHOUT DEFAULTS)
        ON CHANGE current_cursor
           CALL reload_rows(DIALOG,params.*)
        ON CHANGE current_source
           CALL reload_rows(DIALOG,params.*)
        ON CHANGE exec_time
           CALL reload_rows(DIALOG,params.*)
        ON CHANGE exec_time_frac
           CALL reload_rows(DIALOG,params.*)
        ON CHANGE only_errors
           CALL reload_rows(DIALOG,params.*)
        ON CHANGE with_uvars
           CALL reload_rows(DIALOG,params.*)
        ON CHANGE with_ivars
           CALL reload_rows(DIALOG,params.*)
        ON CHANGE find_keyword
           CALL reload_rows(DIALOG,params.*)
    END INPUT

    BEFORE DIALOG
        CALL DIALOG.setArrayAttributes("sr",log_att)
        CALL reload_rows(DIALOG,params.*)

    ON ACTION refresh
        CALL reload_rows(DIALOG,params.*)

    ON ACTION open
        LET filename = ask_file_name()
        IF filename IS NOT NULL THEN
           IF NOT load_file(filename, FALSE) THEN
              LET params.filename = NULL
              CALL load_array(DIALOG,params.*) -- cleanup
              CALL sync_row_data(DIALOG,0)
              CALL setup_dialog(DIALOG,params.*)
              CALL ui.Interface.refresh()
              CALL mbox_ok(SFMT("Could not load FGLSQLDEBUG log from:\n%1", filename))
           ELSE
              LET params.filename = filename
              CALL load_array(DIALOG,params.*)
              CALL sync_row_data(DIALOG,arr_curr())
              CALL setup_dialog(DIALOG,params.*)
           END IF
           LET params.current_cursor = NULL
           LET params.current_source = NULL
           CALL fill_cursor_list(NULL)
           CALL fill_source_list(NULL)
        END IF

    ON ACTION about
       CALL mbox_ok(SFMT(TOOL_ABOUT_MSG,TOOL_VERSION))

    ON ACTION close
       EXIT DIALOG

    END DIALOG

END FUNCTION

FUNCTION ask_file_name()
    DEFINE fn VARCHAR(200)
    --PROMPT "Enter FGLSQLDEBUG file name:" FOR fn
    --RETURN IIF(int_flag, NULL, fn)
    CALL ui.Interface.frontCall("standard", "openFile",
                                [NULL,NULL,"*","FGLSQLDEBUG file"], [fn])
    RETURN fn
END FUNCTION

FUNCTION reload_rows(d,params)
    DEFINE d ui.Dialog,
           params t_params
    CALL load_array(d,params.*)
    CALL sync_row_data(d,1)
    CALL setup_dialog(d,params.*)
END FUNCTION

FUNCTION sync_row_data(d,row)
    DEFINE d ui.Dialog,
           row INTEGER
    DEFINE tmp STRING,
           f ui.Form
    LET f = d.getForm()
    IF row>=1 AND row<=log_arr.getLength() THEN
       DISPLAY log_arr[row].fglsql TO curr_sql1
       DISPLAY log_arr[row].natsql1 TO curr_sql2
       DISPLAY log_arr[row].natsql2 TO curr_sql3
       CALL f.setFieldHidden("curr_sql3", (log_arr[row].natsql2 IS NULL))
       DISPLAY log_arr[row].sqlstate TO f_sqlstate
       DISPLAY log_arr[row].sqlerrd2 TO f_sqlerrd2
       DISPLAY log_arr[row].sqlerrmsg TO f_sqlerrmsg
       DISPLAY log_arr[row].srcfile TO f_srcfile
       DISPLAY log_arr[row].srcline TO f_srcline
       MESSAGE SFMT("Row %1/%2", row, log_arr.getLength())
    ELSE
       CLEAR curr_sql1, curr_sql2, curr_sql3,
             f_sqlstate, f_sqlerrd2, f_sqlerrmsg,
             f_srcfile, f_srcline
       MESSAGE NULL
       CALL f.setFieldHidden("curr_sql3", TRUE)
    END IF
    CALL load_sqlvars(d,row)
END FUNCTION

FUNCTION setup_dialog(d,params)
    DEFINE d ui.Dialog,
           params t_params
    DEFINE row INTEGER,
           s, r BOOLEAN
    LET row = d.getCurrentRow("sr")
    IF row>0 THEN
       LET s = (log_arr[row].srcfile IS NOT NULL)
       LET r = TRUE
    END IF
    CALL d.setActionActive("sr.source",s)
    CALL d.setActionActive("sr.details",r)
END FUNCTION

FUNCTION show_driver_messages(cid)
    DEFINE cid INTEGER
    DEFINE arr DYNAMIC ARRAY OF t_drvmsg,
           x INTEGER
 
    DECLARE c_drvmsg CURSOR FOR
     SELECT * FROM drvmsg WHERE cmdid = cid ORDER BY position
    LET x=1
    FOREACH c_drvmsg INTO arr[x].*
        LET x=x+1
    END FOREACH
    CALL arr.deleteElement(x)

    OPEN WINDOW w_drvmsg WITH FORM "drvmsgs"

    DISPLAY ARRAY arr TO sr.* ATTRIBUTES(CANCEL=FALSE,DOUBLECLICK=none)
        BEFORE ROW
          DISPLAY arr[arr_curr()].message TO msgtext
    END DISPLAY

    CLOSE WINDOW w_drvmsg

END FUNCTION

FUNCTION find_source(srcfile)
    DEFINE srcfile STRING
    DEFINE path STRING,
           tok base.StringTokenizer
    LET tok = base.StringTokenizer.create(fglsourcepath,os.Path.pathSeparator())
    WHILE tok.hasMoreTokens()
        LET path = os.Path.join(tok.nextToken(),srcfile)
        IF os.Path.exists(path) THEN
           RETURN path
        END IF
    END WHILE
    RETURN NULL
END FUNCTION

FUNCTION show_source(srcfile,srcline)
    DEFINE srcfile STRING, srcline INTEGER
    DEFINE arr DYNAMIC ARRAY OF RECORD
                   line INTEGER,
                   text STRING
               END RECORD,
           ch base.Channel,
           tmp STRING,
           x INTEGER
    IF fglsourcepath IS NULL THEN
       CALL mbox_ok("Define FGLSOURCEPATH to find application sources")
       RETURN
    END IF
    LET tmp = find_source(srcfile)
    IF tmp IS NULL THEN
       CALL mbox_ok(SFMT("Could not find source %1, check FGLSOURCEPATH",srcfile))
       RETURN
    END IF
    LET ch = base.Channel.create()
    TRY
        CALL ch.openFile(tmp,"r")
    CATCH
       CALL mbox_ok(SFMT("Could not open file:\n%1",tmp))
       RETURN
    END TRY
    WHILE NOT ch.isEOF()
       LET x = x+1
       LET arr[x].line = x
       LET arr[x].text = ch.readLine()
    END WHILE
    OPEN WINDOW w_source WITH FORM ("showtext")
         ATTRIBUTES(TEXT=tmp,STYLE="dialog")
    DISPLAY ARRAY arr TO sr.* ATTRIBUTES(CANCEL=FALSE)
        BEFORE DISPLAY
           CALL DIALOG.setCurrentRow("sr",srcline)
    END DISPLAY
    CLOSE WINDOW w_source
END FUNCTION

FUNCTION create_empty_file(fn)
    DEFINE fn STRING
    DEFINE ch base.Channel
    LET ch = base.Channel.create()
    CALL ch.openFile(fn,"w")
    CALL ch.close()
END FUNCTION

FUNCTION get_temp_dir()
    DEFINE tmpdir STRING
    IF fgl_getenv("WINDIR") THEN
       LET tmpdir = fgl_getenv("TEMP")
       IF LENGTH(tmpdir) == 0 THEN
          LET tmpdir = fgl_getenv("TMP")
       END IF
    ELSE
       LET tmpdir = fgl_getenv("TMPDIR")
       IF LENGTH(tmpdir) == 0 THEN
          LET tmpdir="/tmp"
       END IF
    END IF
    RETURN tmpdir
END FUNCTION

FUNCTION get_user_name()
    DEFINE username STRING
    LET username = fgl_getenv("USERNAME")
    IF LENGTH(username) == 0 THEN
       LET username = fgl_getenv("USER")
       IF LENGTH(username) == 0 THEN
          LET username="unknown"
       END IF
    END IF
    RETURN username
END FUNCTION

FUNCTION init_database(filename, force_reload)
    DEFINE filename STRING,
           force_reload BOOLEAN
    DEFINE tmpfile STRING, db STRING,
           username STRING, basename STRING,
           reuse BOOLEAN

    LET username = get_user_name()
    LET basename = os.Path.baseName(filename)

    LET tmpfile = os.Path.join(get_temp_dir(),SFMT("fglsqldebug_%1_%2.tmp",username,basename))

    IF os.Path.exists(tmpfile) AND NOT force_reload THEN
       LET reuse = TRUE
    ELSE
       CALL create_empty_file(tmpfile)
    END IF

    TRY

    WHENEVER ERROR CONTINUE
    DISCONNECT ALL
    WHENEVER ERROR STOP
    LET db = SFMT("tmpdb+driver='dbmsqt',source='%1'",tmpfile)
    CONNECT TO db

    IF reuse THEN RETURN 1, tmpfile END IF

    CREATE TABLE connection (
         connid INTEGER,
         name VARCHAR(50),
         dbsrc VARCHAR(200),
         driver VARCHAR(50),
         dlib VARCHAR(500),
         dtype CHAR(3)
    )

    CREATE TABLE sqlvar (
         cmdid INTEGER,
         vartype CHAR(1),
         position SMALLINT,
         datatype VARCHAR(50),
         flags SMALLINT,
         value VARCHAR(500),
         PRIMARY KEY (cmdid, vartype, position)
    )

    CREATE TABLE drvmsg (
         cmdid INTEGER,
         position SMALLINT,
         srcfile VARCHAR(50),
         srcline INTEGER,
         message VARCHAR(500),
         PRIMARY KEY (cmdid, position)
    )

    CREATE TABLE command (
         cmdid INTEGER PRIMARY KEY,
         connid INTEGER,
         fglcmd VARCHAR(30),
         srcfile VARCHAR(200),
         srcline INTEGER,
         fglcursor VARCHAR(50),
         sqlcursor VARCHAR(50),
         c_scroll CHAR(1),
         c_hold CHAR(1),
         sqlcode INTEGER,
         sqlerrd2 INTEGER,
         sqlerrmsg VARCHAR(200),
         sqlstate VARCHAR(10),
         fglsql VARCHAR(2000),
         natsql1 VARCHAR(2000),
         natsql2 VARCHAR(2000),
         exectime INTERVAL DAY TO FRACTION(5)
    )

    CATCH
        RETURN -1, NULL
    END TRY

    RETURN 0, tmpfile

END FUNCTION

FUNCTION database_available()
    DEFINE c INTEGER
    WHENEVER ERROR CONTINUE
    SELECT COUNT(*) INTO c FROM connection
    WHENEVER ERROR STOP
    RETURN (SQLCA.SQLCODE==0)
END FUNCTION

FUNCTION fill_cursor_list(cmb)
    DEFINE cmb ui.ComboBox
    DEFINE fc, sc VARCHAR(100)
    IF cmb IS NULL THEN
       LET cmb = ui.ComboBox.forName("formonly.current_cursor")
    END IF
    CALL cmb.clear()
    IF NOT database_available() THEN RETURN END IF
    DECLARE c_cursor CURSOR FOR
       SELECT DISTINCT fglcursor, sqlcursor FROM command
        WHERE fglcursor IS NOT NULL AND fglcursor != '?'
        ORDER BY fglcursor
    CALL cmb.addItem(NULL, "<All>")
    FOREACH c_cursor INTO fc, sc
       CALL cmb.addItem(fc, SFMT("%1 (%2)",fc,sc))
    END FOREACH
END FUNCTION

FUNCTION fill_source_list(cmb)
    DEFINE cmb ui.ComboBox
    DEFINE sf VARCHAR(200)
    IF cmb IS NULL THEN
       LET cmb = ui.ComboBox.forName("formonly.current_source")
    END IF
    CALL cmb.clear()
    IF NOT database_available() THEN RETURN END IF
    DECLARE c_source CURSOR FOR
       SELECT DISTINCT srcfile FROM command
        WHERE srcfile IS NOT NULL
        ORDER BY srcfile
    CALL cmb.addItem(NULL, "<All>")
    FOREACH c_source INTO sf
       CALL cmb.addItem(sf, sf)
    END FOREACH
END FUNCTION

FUNCTION extract_tail(head,line)
    DEFINE head, line STRING
    DEFINE len SMALLINT, tail STRING
    LET head = head || "*"
    LET len = head.getLength()
    IF line MATCHES head THEN
       LET tail = line.subString(len,line.getLength())
       RETURN TRUE, tail
    END IF
    RETURN FALSE, NULL
END FUNCTION

FUNCTION get_cmd_from_sql(sqltext)
    DEFINE sqltext STRING
    LET sqltext = sqltext.toUpperCase()
    LET sqltext = sqltext.trimLeft()
    CASE
      WHEN sqltext MATCHES "SELECT*"       RETURN "SELECT"
      WHEN sqltext MATCHES "INSERT*"       RETURN "INSERT"
      WHEN sqltext MATCHES "UPDATE*"       RETURN "UPDATE"
      WHEN sqltext MATCHES "DELETE*"       RETURN "DELETE"
      WHEN sqltext MATCHES "CREATE TABLE*" RETURN "CREATE TABLE"
      WHEN sqltext MATCHES "ALTER TABLE*"  RETURN "ALTER TABLE"
      WHEN sqltext MATCHES "DROP TABLE*"   RETURN "DROP TABLE"
      WHEN sqltext MATCHES "CREATE INDEX*" RETURN "CREATE INDEX"
      WHEN sqltext MATCHES "DROP INDEX*"   RETURN "DROP INDEX"
      OTHERWISE                            RETURN sqltext
    END CASE
END FUNCTION

FUNCTION load_array(d,params)
    DEFINE d ui.Dialog,
           params t_params
    DEFINE x INTEGER,
           sql STRING,
           max_time INTERVAL DAY TO FRACTION(5)

    CALL log_arr.clear()
    CALL log_att.clear()

    IF NOT database_available() THEN RETURN END IF

    LET sql = "SELECT * FROM command WHERE 1=1"
    IF params.current_cursor IS NOT NULL THEN
       LET sql = sql || SFMT(" AND fglcursor = '%1'",params.current_cursor)
    END IF
    IF params.current_source IS NOT NULL THEN
       LET sql = sql || SFMT(" AND srcfile = '%1'",params.current_source)
    END IF
    IF params.exec_time != "00:00:00" OR params.exec_time_frac>0 THEN
       LET max_time = SFMT(" 0 %1.%2", params.exec_time, (params.exec_time_frac USING "&&&&&"))
       LET sql = sql || SFMT(" AND exectime > '%1'", max_time)
    END IF
    IF params.only_errors THEN
       LET sql = sql || " AND sqlcode < 0"
    END IF
    IF params.with_uvars THEN
       LET sql = sql || " AND cmdid IN (SELECT DISTINCT cmdid FROM sqlvar WHERE vartype='U')"
    END IF
    IF params.with_ivars THEN
       LET sql = sql || " AND cmdid IN (SELECT DISTINCT cmdid FROM sqlvar WHERE vartype='I')"
    END IF
    IF params.find_keyword THEN
       LET sql = sql || SFMT(" AND fglsql LIKE '%%%1%%'", params.find_keyword)
    END IF
    LET sql = sql || " ORDER BY cmdid"

    DECLARE c1 CURSOR FROM sql
    LET x=1
    FOREACH c1 INTO log_arr[x].*
       LET log_att[x].cmdid = "#CCCCCC reverse"
       LET log_att[x].exectime = "#BBEEFF reverse"
       LET log_att[x].fglcmd = "#EEFFBB reverse"
       IF log_arr[x].sqlcode < 0 THEN
          LET log_att[x].sqlcode = "red reverse"
       END IF
       IF log_arr[x].sqlcode == 100 THEN
          LET log_att[x].sqlcode = "blue reverse"
       END IF
       LET x=x+1
    END FOREACH
    CALL log_arr.deleteElement(x)

    CALL d.setCurrentRow("sr",1)

END FUNCTION

FUNCTION load_sqlvars(d,row)
    DEFINE d ui.Dialog,
           row INTEGER
    DEFINE cid INTEGER,
           xu, xi INTEGER,
           rec t_sqlvar

    CALL uvars.clear()
    CALL ivars.clear()

    IF row==0 OR NOT database_available() THEN RETURN END IF

    LET cid = log_arr[row].cmdid

    DECLARE c_sqlvars CURSOR FOR
     SELECT * FROM sqlvar WHERE cmdid = ? ORDER BY vartype, position

    FOREACH c_sqlvars USING cid INTO rec.*
        IF rec.vartype == "U" THEN
           LET xu = xu + 1
           LET uvars[xu].* = rec.*
        ELSE
           LET xi = xi + 1
           LET ivars[xi].* = rec.*
        END IF
    END FOREACH

    CALL d.setCurrentRow("sruv",1)
    CALL d.setCurrentRow("sriv",1)

END FUNCTION

FUNCTION load_file(filename, force_reload)
    DEFINE filename STRING,
           force_reload BOOLEAN
    DEFINE ch base.Channel,
           tmpfile STRING,
           valid BOOLEAN,
           line STRING,
           found BOOLEAN,
           tail STRING,
           cmd t_command,
           sv t_sqlvar,
           dm t_drvmsg,
           conn t_connection,
           p, p2, s SMALLINT,
           tmp1, tmp2 STRING,
           cursz, totsz, progress, totkb INTEGER

    CALL init_database(filename, force_reload) RETURNING s, tmpfile
    CASE s
       WHEN  1 RETURN TRUE  -- Reuse existing database
       WHEN -1 RETURN FALSE -- Failure
       WHEN  0 EXIT CASE
    END CASE

    BEGIN WORK
    DELETE FROM drvmsg
    DELETE FROM sqlvar
    DELETE FROM command
    DELETE FROM connection
    COMMIT WORK

    EXECUTE IMMEDIATE "VACUUM"

    LET cursz = 0
    LET totsz = os.Path.size(filename)
    LET totkb = totsz / 1024

    TRY
        LET ch = base.Channel.create()
        CALL ch.openFile(filename,"r")
    CATCH
        LET s= os.Path.delete(tmpfile)
        RETURN FALSE
    END TRY

    BEGIN WORK

    LET cmd.cmdid = 0
    WHILE NOT ch.isEOF()

        LET line = ch.readLine()
        LET cursz = cursz + line.getLength()
        IF cursz MOD 2000 == 0 THEN
           LET progress = ((cursz/totsz)*100)
           MESSAGE SFMT("Loading: %1%% / %2 Kb", progress, totkb)
           CALL ui.Interface.refresh()
        END IF

        IF sv.vartype IS NOT NULL THEN
           CALL extract_tail(" |  t:", line) RETURNING found, tail
           IF NOT found THEN
              LET sv.vartype = NULL
           ELSE
              LET sv.position = sv.position + 1
              LET p = tail.getIndexOf(" f:",1)
              LET tmp1 = tail.subString(1,p-1)
              LET sv.datatype = tmp1.trim()
              LET sv.flags = tail.subString(p+4,p+5)
              LET p = tail.getIndexOf(" v:",1)
              LET sv.value = tail.subString(p+4,tail.getLength()-1)
              INSERT INTO sqlvar VALUES (cmd.cmdid, sv.vartype, sv.position, sv.datatype, sv.flags, sv.value)
              CONTINUE WHILE
           END IF
        END IF

        CALL extract_tail(" | using: ", line) RETURNING found, tail
        IF found THEN
           LET sv.vartype = "U"
           LET sv.position = 0
           --LET sqlvar_count = tail
           CONTINUE WHILE
        END IF

        CALL extract_tail(" | into: ", line) RETURNING found, tail
        IF found THEN
           LET sv.vartype = 'I'
           LET sv.position = 0
           --LET sqlvar_count = tail
           CONTINUE WHILE
        END IF

        CALL extract_tail("SQL: ", line) RETURNING found, tail
        IF found THEN
           LET cmd.fglcmd = get_cmd_from_sql(tail)
           LET cmd.fglsql = tail
           IF cmd.fglcmd == "CONNECT"
           OR cmd.fglcmd == "DATABASE"
           OR cmd.fglcmd == "CREATE DATABASE" THEN
              LET conn.connid = conn.connid + 1
              LET conn.name = NULL
              LET conn.dbsrc = NULL
              LET conn.driver = NULL
              LET conn.dlib = NULL
              LET conn.dtype = NULL
              LET cmd.connid = conn.connid
              INSERT INTO connection (connid) VALUES (conn.connid)
           END IF
           LET cmd.cmdid = cmd.cmdid + 1
           INSERT INTO command (cmdid, connid, fglcmd, fglsql) VALUES (cmd.cmdid, cmd.connid, cmd.fglcmd, cmd.fglsql)
           LET dm.position = 0
           CONTINUE WHILE
        END IF

        IF conn.driver IS NULL THEN -- found connection statement
           CALL extract_tail(" | curr driver     : ", line) RETURNING found, tail
           IF found THEN
              LET valid=TRUE
              LET p = tail.getIndexOf("ident='",1)
              IF p>0 THEN
                 LET conn.driver = tail.subString(p+7,tail.getLength()-1)
                 UPDATE connection SET driver = conn.driver WHERE connid = conn.connid
              END IF
              CONTINUE WHILE
           END IF
        END IF

        IF conn.name IS NULL THEN -- found connection statement
           CALL extract_tail(" | curr connection : ", line) RETURNING found, tail
           IF found THEN
              LET p = tail.getIndexOf("ident='",1)
              IF p>0 THEN
                 LET tmp1 = tail.subString(p+7,tail.getLength())
                 LET p2 = tmp1.getIndexOf("' (dbspec=[",1)
                 LET tmp2 = tmp1.subString(p,p2-1)
                 LET conn.name = tmp1.subString(p,p2-1)
                 LET conn.dbsrc = tmp1.subString(p2+11,tmp1.getLength()-2)
                 UPDATE connection
                    SET name = conn.name,
                        dbsrc = conn.dbsrc
                  WHERE connid = conn.connid
              END IF
              CONTINUE WHILE
           END IF
        END IF

        IF conn.dlib IS NULL THEN -- found connection statement
           CALL extract_tail(" | loading driver  : ", line) RETURNING found, tail
           IF found THEN
              LET conn.dlib = tail.subString(2,tail.getLength()-1)
              UPDATE connection SET dlib = conn.dlib WHERE connid = conn.connid
              CONTINUE WHILE
           END IF
        END IF

        IF conn.dtype IS NULL THEN -- found connection statement
           CALL extract_tail(" | db driver type  : ", line) RETURNING found, tail
           IF found THEN
              LET conn.dtype = tail
              UPDATE connection SET dtype = conn.dtype WHERE connid = conn.connid
              CONTINUE WHILE
           END IF
        END IF

        CALL extract_tail(" | 4gl source      : ", line) RETURNING found, tail
        IF found THEN
           LET p = tail.getIndexOf(" line=",1)
           IF p>0 THEN
              LET cmd.srcfile = tail.subString(1,p-1)
              LET cmd.srcline = tail.subString(p+6,tail.getLength())
              UPDATE command
                 SET srcfile = cmd.srcfile,
                     srcline = cmd.srcline
               WHERE cmdid = cmd.cmdid
           END IF
           CONTINUE WHILE
        END IF

        CALL extract_tail(" | sql cursor      : ", line) RETURNING found, tail
        IF found THEN
           LET p = tail.getIndexOf("ident='",1)
           LET tmp1 = tail.subString(p+7,tail.getLength()-1)
           LET p = tmp1.getIndexOf("'",1)
           LET cmd.sqlcursor = tmp1.subString(1,p-1)
           LET tmp1 = tmp1.subString(p+1,tmp1.getLength())
           CALL extract_tail(" (fglname='", tmp1) RETURNING found, tail
           LET p = tail.getIndexOf("'",1)
           LET cmd.fglcursor = tail.subString(1,p-1)
           UPDATE command
              SET fglcursor = cmd.fglcursor,
                  sqlcursor = cmd.sqlcursor
            WHERE cmdid = cmd.cmdid
           CONTINUE WHILE
        END IF

        CALL extract_tail(" | sqlcode         :", line) RETURNING found, tail
        IF found THEN
           LET cmd.sqlcode = tail
           UPDATE command SET sqlcode = cmd.sqlcode WHERE cmdid = cmd.cmdid
           CONTINUE WHILE
        END IF

        CALL extract_tail(" |   sqlerrd2      :", line) RETURNING found, tail
        IF found THEN
           LET cmd.sqlerrd2 = tail
           UPDATE command SET sqlerrd2 = cmd.sqlerrd2 WHERE cmdid = cmd.cmdid
           CONTINUE WHILE
        END IF

        CALL extract_tail(" |   sqlstate      :", line) RETURNING found, tail
        IF found THEN
           LET cmd.sqlstate = tail
           UPDATE command SET sqlstate = cmd.sqlstate WHERE cmdid = cmd.cmdid
           CONTINUE WHILE
        END IF

        CALL extract_tail(" |   sql message   :", line) RETURNING found, tail
        IF found THEN
           LET cmd.sqlerrmsg = tail
           UPDATE command SET sqlerrmsg = cmd.sqlerrmsg WHERE cmdid = cmd.cmdid
           CONTINUE WHILE
        END IF

        CALL extract_tail(" |   scroll cursor :", line) RETURNING found, tail
        IF found THEN
           LET cmd.c_scroll = IIF(tail=="0","N","Y")
           UPDATE command SET c_scroll = cmd.c_scroll WHERE cmdid = cmd.cmdid
           CONTINUE WHILE
        END IF

        CALL extract_tail(" |   with hold     :", line) RETURNING found, tail
        IF found THEN
           LET cmd.c_hold = IIF(tail=="0","N","Y")
           UPDATE command SET c_hold = cmd.c_hold WHERE cmdid = cmd.cmdid
           CONTINUE WHILE
        END IF

        CALL extract_tail(" | Execution time  : ", line) RETURNING found, tail
        IF found THEN
           LET cmd.exectime = tail
           UPDATE command SET exectime = cmd.exectime WHERE cmdid = cmd.cmdid
           CONTINUE WHILE
        END IF

        CALL extract_tail(" |   fgl stmt      : ", line) RETURNING found, tail
        IF found THEN
           LET cmd.fglsql = tail
           UPDATE command SET fglsql = cmd.fglsql WHERE cmdid = cmd.cmdid
           CONTINUE WHILE
        END IF

-- FIXME: CALL extract_tail(" |   sql stmt      : ", line) RETURNING found, tail

        -- Other = driver messages...
        CALL extract_tail(" | ", line) RETURNING found, tail
        IF found THEN
           LET p = tail.getIndexOf(" : ",1)
           IF p>0 AND tail MATCHES "*:[0-9][0-9][0-9][0-9][0-9]([0-9])*" THEN
              LET dm.cmdid = cmd.cmdid
              LET dm.position = dm.position + 1
              LET dm.message = tail.subString(p+3, tail.getLength())
              LET tmp1 = tail.subString(1,p-1)
              LET p = tmp1.getIndexOf(":",1)
              IF p>0 THEN
                 LET dm.srcfile = tmp1.subString(1,p-1)
                 LET p2 = tmp1.getIndexOf("(",1)
                 IF p2>0 THEN
                    LET dm.srcline = tmp1.subString(p+1,p2-1)
                    CALL extract_tail("Nat stmt1 = ", dm.message) RETURNING found, cmd.natsql1
                    IF found THEN
                       UPDATE command SET natsql1 = cmd.natsql1 WHERE cmdid = cmd.cmdid
                       CONTINUE WHILE
                    END IF
                    CALL extract_tail("Nat stmt2 = ", dm.message) RETURNING found, cmd.natsql2
                    IF found THEN
                       UPDATE command SET natsql2 = cmd.natsql2 WHERE cmdid = cmd.cmdid
                       CONTINUE WHILE
                    END IF
                    INSERT INTO drvmsg VALUES (dm.*)
                 END IF
              END IF
           END IF
           CONTINUE WHILE
        END IF

    END WHILE

    COMMIT WORK

    IF NOT valid THEN
       CALL mbox_ok(SFMT("The file %1 does not seem to be a valid FGLSQLDEBUG file",filename))
       LET s= os.Path.delete(tmpfile)
       RETURN FALSE
    END IF

    RETURN TRUE

END FUNCTION


FUNCTION show_usage()
    DISPLAY "Usage: fglsqldebug <options> ..."
    DISPLAY "Options:"
    DISPLAY " -f filename : FGLSQLDEBUG log file"
    DISPLAY " -r : Force reload of log file"
END FUNCTION

FUNCTION mbox_ok(msg)
    DEFINE msg STRING
    MENU "ENAudit" ATTRIBUTES(STYLE="dialog",COMMENT=msg)
        COMMAND "Ok" EXIT MENU
    END MENU
END FUNCTION

FUNCTION mbox_yn(msg)
    DEFINE msg STRING
    DEFINE r BOOLEAN
    MENU "ENAudit" ATTRIBUTES(STYLE="dialog",COMMENT=msg)
        COMMAND "Yes" LET r = TRUE
        COMMAND "No"  LET r = FALSE
    END MENU
    RETURN r
END FUNCTION

FUNCTION cmdarg_option_used(optname)
    DEFINE optname STRING -- The option name without '-'
    RETURN ( cmdarg_option_index(optname)>0 )
END FUNCTION

FUNCTION cmdarg_option_param(optname)
    DEFINE optname STRING -- The option name without '-'
    DEFINE optidx INTEGER
    DEFINE paramval STRING -- Can be a directory path !
    LET paramval = NULL
    LET optidx = cmdarg_option_index(optname)
    IF (optidx>0) AND (optidx<num_args()) THEN
       -- Get value ( follows option argument )
       LET paramval = arg_val(optidx+1)
    END IF
    RETURN paramval
END FUNCTION

FUNCTION cmdarg_option_index(optname)
    DEFINE optname STRING -- The option name without '-'
    DEFINE idx, cnt, optidx INTEGER
    DEFINE fopt STRING
    LET optidx = -1
    LET cnt = num_args()
    LET fopt = "-", optname -- UNIX convention
    FOR idx=1 TO cnt
        IF (arg_val(idx)=fopt) THEN
           LET optidx = idx
           EXIT FOR
        END IF
    END FOR
    RETURN optidx
END FUNCTION

FUNCTION cmdarg_option_isopt(name)
    DEFINE name STRING
    RETURN ( name.getCharAt(1) == "-" )
END FUNCTION

-- Syntax:
--  <option>+ = option has parameter (next arg must not use -)
--     *      = simple string is allowed as argument
# This implementation of command line parsing does not follow standards as
# defined by man 1 getopt
FUNCTION cmdarg_option_check(stindex,optlist)
    DEFINE stindex SMALLINT -- Start at this argument
    DEFINE optlist STRING -- The possible options (v|x|cv|of+|*)
    DEFINE optspec STRING
    DEFINE optpara STRING
    DEFINE i, j INTEGER
    DEFINE indiv, found INTEGER
    DEFINE tok base.StringTokenizer
    DEFINE optarr DYNAMIC ARRAY OF RECORD
                      optname STRING,
                      hasparam INTEGER
                  END RECORD
    LET tok = base.StringTokenizer.create(optlist, "|")
    WHILE tok.hasMoreTokens()
       LET optspec = tok.nextToken()
       IF optspec = "*" THEN
          LET indiv = TRUE
          CONTINUE WHILE
       END IF
       LET i = optspec.getIndexOf("+",1)
       CALL optarr.appendElement()
       IF i > 0 THEN
          LET optarr[optarr.getLength()].hasparam = 1
          LET optspec = optspec.substring(1,i-1)
       END IF
       LET optarr[optarr.getLength()].optname = optspec
    END WHILE
    FOR i=stindex TO num_args()
        LET optspec = arg_val(i)
        IF NOT cmdarg_option_isopt(optspec) THEN
           IF indiv THEN CONTINUE FOR ELSE RETURN i END IF
        END IF
        LET optspec = optspec.substring(2,optspec.getLength())
        LET found = FALSE
        FOR j=1 TO optarr.getLength()
            IF optarr[j].optname == optspec THEN
               LET found = TRUE
               LET optpara = arg_val(i+1)
               IF optarr[j].hasparam THEN
                  IF i + 1 > num_args() OR cmdarg_option_isopt(optpara) THEN
                     LET found = FALSE
                  ELSE
                     LET i = i + 1
                  END IF
               ELSE
                  IF i + 1 <= num_args() AND NOT cmdarg_option_isopt(optpara) THEN
                     LET found = FALSE
                  END IF
               END IF
               EXIT FOR
            END IF
        END FOR
        IF NOT found THEN RETURN i END IF
    END FOR
    RETURN 0
END FUNCTION
