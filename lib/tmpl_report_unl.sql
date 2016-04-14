/*
**
**	tmpl_report_unl.sql
**
**	- BESCHREIBUNG
**
**	- HISTORIE
**
**	PF	25.8.2005	Erstellung Template 
**
*/
SET NEWPAGE 0
SET SPACE 0
SET LINESIZE 9999
SET PAGESIZE 0
SET HEADING OFF
SET VERIFY   OFF
SET TRIMSPOOL ON
SET MARKUP HTML OFF SPOOL OFF
SET DEFINE OFF
SET SCAN OFF

WHENEVER OSERROR EXIT FAILURE

-- -----------------------------------------------------------------
-- Session-Infos setzen
-- -----------------------------------------------------------------
BEGIN
  DBMS_APPLICATION_INFO.SET_MODULE(   module_name => 'Reporting Framework',  action_name => 'Vxxxx');
END;
/

--      Den Job mit Loeschen von zuvor evtl. stehengebliebenen
--      Tabellen beginnen.

WHENEVER SQLERROR EXIT SQL.SQLCODE

SET COLSEP ";"

--      Sessioninformationen ausgeben
--
SELECT
    '--SESSIONINFO(SID,SERIAL#,USERNAME): ' || sid ||' '|| serial# ||' '|| username
FROM
    gv$session
WHERE
    audsid = sys_context('USERENV','SESSIONID');


SET ECHO OFF
SET FEEDBACK OFF
SET TERMOUT OFF

ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ', ';
ALTER SESSION SET NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS';

--      Erst eine Headerzeile erstellen, dann das
--      eigentliche SQL ausfuehren
--
--	Den Kommentar nach dem HeaderString unbedingt stehen lassen !!
--
SPOOL __RESULTFILE__

SELECT
	'Header;'	--HEADER
FROM
	dual;

--	Jetzt die Reportdaten ausgeben
--
SELECT
	dummy ||';'
FROM
	dual;
	
SPOOL OFF

--      Zum Abschluss werden die temporaeren Tabellen
--      gedroppt. Dazu das sqlplus Echo wieder
--      einschalten, damit man weiss was los ist.
--      SQL Fehler spielen keine Rolle mehr.
--
SET ECHO ON
SET FEEDBACK ON
SET TERMOUT ON

--	temporaeren Platzbedarf notieren
--
--call p_log_etl_size.log_table_size('Vxxxx');

WHENEVER SQLERROR CONTINUE

QUIT SQL.SQLCODE;
