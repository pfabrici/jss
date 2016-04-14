/*
**
**	tmpl_mysql_unl.sql
**
**	- BESCHREIBUNG
**
**	Der lokale Spool ueber den Pager scheint nur
**	bei Client Versionen >5.0 moeglich zu sein !!
**
**	- HISTORIE
**
**	PF	10.3.2008	Erstellung Template 
**
*/
--      Den Job mit Loeschen von zuvor evtl. stehengebliebenen
--      Tabellen beginnen.


--      Erst eine Headerzeile erstellen, dann das
--      eigentliche SQL ausfuehren
--
--	Den Kommentar nach dem HeaderString unbedingt stehen lassen !!
--
\P cat | awk -f __LIBDIR__/myspoolpager.awk > __RESULTFILE__

SELECT "Header;";

--	Jetzt die Reportdaten ausgeben
--
SELECT concat('X',';');
	
\n

--      Zum Abschluss werden die temporaeren Tabellen
--      gedroppt. 
--

\q
