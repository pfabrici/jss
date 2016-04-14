/*
**	reporter.sql
**
**	DDL Statements fuer die Datenbankobjekte 
**	des Reporting Frameworks.
**	Angelegt werden Tabelle, Funktionen, eine Sequence
**	und verschiedene Views.
**	Es wird das Schema verwendet, welches beim
**	Aufrufen des DB Frontends angegeben wurde.
**	
**	Sequence:
**		reportseq 
**	Tabellen:
**		reportlist
**		reportorder
**		reportctrl
**		reporttmp
**		reportlog
**	Funktionen:
**		insvalue
**		getsid
**	Views:
**		reportstart_ce
**		reportstart_blank
**
**	ACHTUNG :
**	Bei der Ausfuehrung dieses Skripts werden evtl.
**	bestehende Objekte aus der oben aufgefuehrten
**	Liste ohne Rueckfrage gedropped und wieder 
**	angelegt.
**	Alle bestehenden Daten gehen verloren.
**
**	P.Fabricius	4.1.2006	Erstellung
**			...
**			25.8.2006	Erweiterungen
**			26.6.2007	Views, reportlog etc.
**
*/
WHENEVER OSERROR EXIT FAILURE

DROP SEQUENCE reportseq;

DROP TABLE reportlog;
DROP TABLE reportcontent;
DROP TABLE reporttables;
DROP TABLE reportparams;
DROP TABLE reporttmp;
DROP TABLE reportorder;
DROP TABLE reportctrl;
DROP TABLE reportlist;
DROP TABLE reportverzeichnis;
DROP TABLE reporttyp;

DROP FUNCTION insvalue;
DROP FUNCTION getsid;

DROP VIEW reportstart_ce;
DROP VIEW reportstart_kunde_ce;
DROP VIEW reportstart_blank_ce;

WHENEVER SQLERROR EXIT SQL.SQLCODE;

--------------------------------------------------------------------------------

CREATE SEQUENCE reportseq;

-- Tabelle reportverzeichnis ---------------------------------------------------
CREATE TABLE reportverzeichnis (
        verzeichnis     number PRIMARY KEY,
        titel           varchar2(100) NOT NULL
);

COMMENT ON TABLE reportverzeichnis IS 'Tabelle beinhaltet alle Anforderungsverzeichnisse unter G:\V_HVD\VI_HVD\VIT_HVD\Datenablage\yard\03-Projekte\01-Anforderungen. Sie ist die Mastertabelle der Skriptumgebung. Es gibt keinen automatisierten Bewirtschaftungsprozes, die Verzeichnisse muessen hier manuel eingefuegt werden.';

COMMENT ON COLUMN reportverzeichnis.verzeichnis IS 'Verzeichnisnummer aus dem Verzeichnisnamen';
COMMENT ON COLUMN reportverzeichnis.titel IS 'Titel des Verzeichnisses ohne die Nummer';

-- Tabelle reporttyp ---------------------------------------------------------
CREATE TABLE reporttyp (
	reptyp		NUMBER 		PRIMARY KEY,
	beschr		VARCHAR2(80)	NOT NULL
);

COMMENT ON TABLE reporttyp IS 'Tabelle enthaelt die Reporttypen, die eingesetzt werden.Jobs sollen auch beruecksichtigt werden';

COMMENT ON COLUMN reporttyp.reptyp IS 'Primary Key der Tabelle reporttyp';
COMMENT ON COLUMN reporttyp.beschr IS 'Beschreibung eines Reporttyps';

INSERT INTO reporttyp VALUES ( 1, 'UNIX Skript');
INSERT INTO reporttyp VALUES ( 2, 'UNIX Skript mit Crystal-Enterprise -Frontend');
INSERT INTO reporttyp VALUES ( 3, 'Crystal-Enterprise Report');


-- Tabelle reportlist ---------------------------------------------------------

CREATE TABLE reportlist (
	repname		VARCHAR2(100) 	NOT NULL,
	repnum		NUMBER 		PRIMARY KEY,
	repbinary	VARCHAR2(255) 	NOT NULL,
	anzkeys		NUMBER 		DEFAULT 0 NOT NULL,
	easyplan	NUMBER,
	verzeichnis	NUMBER		NOT NULL REFERENCES reportverzeichnis,
	unixuser	VARCHAR2(8),
	active		VARCHAR2(1),
	reptyp		NUMBER		NOT NULL REFERENCES reporttyp,
	beschr		VARCHAR2(2048)
);

COMMENT ON TABLE reportlist IS 'Alle Jobs in der UNIX Skriptumgebung auf picasso, die einem Verzeichnis in der Windows Dokumentation und damit einer Anforderung zuzuordnen sind. Ansprechpartner ist  P.Fabricius (-4752)';

COMMENT ON COLUMN reportlist.repname IS 'Stringidentifier eines Reports. Muss eindeutig sein.';
COMMENT ON COLUMN reportlist.repnum IS 'Primary key. Wird durch weitere Tabellen referenziert.';
COMMENT ON COLUMN reportlist.repbinary IS 'Pfad zum Reportskript in der Skriptumgebung';
COMMENT ON COLUMN reportlist.anzkeys IS 'Anzahl der benoetigten KEYS/Variablen fuer diesen Report';
COMMENT ON COLUMN reportlist.easyplan IS 'Easyplan Anforderungsnummer zu diesem Skript';
COMMENT ON COLUMN reportlist.verzeichnis IS 'Verzeichnisnummer der Windowsdokumentation. Schluessel zur tabelle reportverzeichnis';
COMMENT ON COLUMN reportlist.unixuser IS 'UNIX Benutzername des Skripterstellers.';
COMMENT ON COLUMN reportlist.beschr IS 'Kurzbeschreibung des Skripts';

CREATE UNIQUE INDEX reportlist_name ON reportlist(repname);

-- Tabelle reportcontent  -----------------------------------------------------
CREATE TABLE reportcontent (
        repnum          NUMBER NOT NULL REFERENCES reportlist,
        repsub          NUMBER DEFAULT 1 NOT NULL,
        attrib_num      NUMBER NOT NULL,
        attrib          VARCHAR2(128),
        attrib_desc     VARCHAR2(255)
);

COMMENT ON TABLE reportcontent IS 'Zu jedem Job aus reportlist wird hier abgelegt, welche Reports mit welchen Attributen erzeugt werden. Erzeugt ein Job mehr als einen Report wird mit repsub differenziert. Es exisiert ein Shellskript, mit dessen Hilfe die Eintraege fuer diese Tabelle generiert werden koennen. Ansprechpartner ist P.Fabricius (-4752)';

COMMENT ON COLUMN reportcontent.repnum IS 'Referenz zur Tabelle Reportlist';
COMMENT ON COLUMN reportcontent.repsub IS 'Nummer des Reports aus dem Skript';
COMMENT ON COLUMN reportcontent.attrib_num IS 'Attributreihenfolge';
COMMENT ON COLUMN reportcontent.attrib IS 'Attribut';
COMMENT ON COLUMN reportcontent.attrib_desc IS 'Attributbeschreibung';

-- Tabelle reportparams --------------------------------------------------------

CREATE TABLE reportorder (    
	SID 		NUMBER NOT NULL ENABLE,
        REPNAME 	VARCHAR2(100) NOT NULL ENABLE,
        REPNUM 		NUMBER DEFAULT 0 NOT NULL ENABLE,
        KEY 		VARCHAR2(40),
        VALUE 		VARCHAR2(128),
        SESSION_USER 	VARCHAR2(30),
        OS_USER 	VARCHAR2(30),
        INS_TIMESTAMP 	DATE
);

COMMENT ON TABLE reportorder IS 'hier werden ueber die Funktion insvalues die neu geplanten Reports/Jobs eingetr
agen. Sollte nicht manuell gepflegt werden.';
COMMENT ON COLUMN reportorder.sid IS 'eindeutiger Identifier einer Reportanfrage';
COMMENT ON COLUMN reportorder.repname IS 'Name des zu startenden Reports ( siehe reportlist.repname )';
COMMENT ON COLUMN reportorder.repnum IS 'obsolet, muss aber gesetzt sein ( siehe reportlist.repnum )';
COMMENT ON COLUMN reportorder.key IS 'Variablenname';
COMMENT ON COLUMN reportorder.value IS 'Variablenwert';


-- Tabelle reportparams --------------------------------------------------------
CREATE TABLE reportparams (
        repnum          NUMBER NOT NULL REFERENCES reportlist,
        keyorder        NUMBER NOT NULL,
        key             VARCHAR2(80),
        keytype         VARCHAR2(1),
        value           VARCHAR2(2048)
);

COMMENT ON TABLE reportparams IS 'Tabelle gehoert zum Reportstartmechanismus. Uebersicht der fuer einen Job verfuegbaren Parameter und deren Quellen.Anpsrechpartner P.Fabricius (-4752).';
COMMENT ON COLUMN reportparams.repnum IS 'Schluessel zur Tabelle reportlist';
COMMENT ON COLUMN reportparams.keyorder IS 'Reihenfolge des Parameters fuer evtl. Frontend';
COMMENT ON COLUMN reportparams.key IS 'Parametername';
COMMENT ON COLUMN reportparams.keytype IS 'Parametertyp. Gueltig ist C (Konstante) und D fuer Datenbank';
COMMENT ON COLUMN reportparams.value IS 'Abhaengig vom keytype entweder ein SQL Statement oder ein Konstanter Wert';

-- Tabelle reporttables --------------------------------------------------------
CREATE TABLE reporttables (
	repnum		NUMBER NOT NULL REFERENCES reportlist,
	autoflag	VARCHAR2(1),
	permanent	VARCHAR2(1),
	table_owner	VARCHAR2(128),
	table_name	VARCHAR2(128),
	table_descr	VARCHAR2(512) 
);

COMMENT ON TABLE reporttables IS 'Tabelle gehoert zum Reportstartmechanismus.  Uebersicht der zu einen Job gehoerenden Tabellen.Anpsrechpartner P.Fabricius (-4752).';
COMMENT ON COLUMN reporttables.repnum IS 'Schluessel zur Tabelle reportlist';
COMMENT ON COLUMN reporttables.autoflag IS 'Manuelles oder automatisches (X) eintragen der Tabelle';
COMMENT ON COLUMN reporttables.permanent IS 'Permanente (X) Tabelle';
COMMENT ON COLUMN reporttables.table_owner IS 'Tabellenowner';
COMMENT ON COLUMN reporttables.table_name IS 'Tabellenname ohne Schema';
COMMENT ON COLUMN reporttables.table_descr IS 'Tabellenbeschreibung';

-- Tabelle reportctrl ---------------------------------------------------------
CREATE TABLE reportctrl (
	sid		NUMBER,
	repbinary	VARCHAR2(255),
	str		VARCHAR2(1024),
	status		VARCHAR2(50),
	starttime	DATE,
	endtime		DATE,
	ecode		NUMBER,
	ins_timestamp	DATE DEFAULT SYSDATE NOT NULL,
	last_update	DATE DEFAULT SYSDATE NOT NULL
);

COMMENT ON TABLE reportctrl IS 'Protokolltabelle fuer den Reportstartmechanismus. Hier erscheinen nur die Reports, die ueber einen INSERT in die Tabelle reportorder gestartet wurden.';

COMMENT ON COLUMN reportctrl.sid IS 'Identifier einer Reportbearbeitung';
COMMENT ON COLUMN reportctrl.repbinary IS 'Pfad zum ausgefuehrten/auszufuehrenden Skript';
COMMENT ON COLUMN reportctrl.str IS 'Parameterstring';
COMMENT ON COLUMN reportctrl.status IS 'aktueller Status dieser Bearbeitung';
COMMENT ON COLUMN reportctrl.starttime IS 'Startzeit der Report/Jobbearbeitug';
COMMENT ON COLUMN reportctrl.endtime IS 'Endzeitpunkt der Report/Jobbearbeitung';
COMMENT ON COLUMN reportctrl.ins_timestamp IS 'Zeitpunkt des ersten Eintrags';
COMMENT ON COLUMN reportctrl.last_update IS 'letzter Schreibzugriff';

-- Tabelle reporttmp ---------------------------------------------------------

--	Tabelle reporttmp
--	eine Hilfstabelle, die bei der Transformation
--	der Daten von reportorder nach reportctrl
--	benoetigt wird.
--	- sid		: Identifier der Bearbeitung
--	- repname	: Reportname
--	- str		: Parameterstring
--
CREATE TABLE reporttmp (
	sid		NUMBER,
	repname		VARCHAR2(100),
	str		VARCHAR2(1024)
);

COMMENT ON TABLE reporttmp IS 'Hilfstabelle des Reportstartmechanismus. Achtung, der INSERT in diese Tabelle fuehrt unter Umstaenden zum Start von UNIX Skripten! Ansprechpartner ist P.Fabricius (-4752)';
COMMENT ON COLUMN reporttmp.sid IS 'Eindeutige ID, unter der die Ausfuehrung eines Jobs gefuehrt wird. Schluessel zur Tabelle reportctrl';
COMMENT ON COLUMN reporttmp.repname IS 'Name des zu startenden Reports. Referenziert die Tabelle reportlist.';
COMMENT ON COLUMN reporttmp.str IS 'Enthaelt einen Parameter in der Form KEY=VALUE. Wird dem Skript uebergeben';

-- Tabelle reportlog ---------------------------------------------------------

CREATE TABLE reportlog (
   	ID 		NUMBER(10,0) NOT NULL ENABLE,
	TMSTMP 		DATE NOT NULL ENABLE,
	VORGANG_ID 	NUMBER(10,0),
	OBJEKTNAME 	VARCHAR2(100),
	ERRORLOG 	VARCHAR2(200),
	TECHDELTA 	VARCHAR2(10),
	FACHDELTA 	VARCHAR2(20),
	PROZESS_NR 	NUMBER(10,0),
	STATUS_OK 	NUMBER(1,0),
	QUELLSYSTEM 	VARCHAR2(20)
);

COMMENT ON TABLE reportlog IS 'Logtabelle fuer das Reporting Framework';
COMMENT ON COLUMN reportlog.vorgang_id IS 'VORGANG_ID referenziert auf reportlist.easyplan';

------------------------------------------------------------------------------

--	Funktion getsid
--	Ermittelt mit Hilfe der Sequenz reportseq 
--	bei Bedarf eine neue SID. 
--	Wird beim Aufuruf von insvalue verwendet.
--
CREATE FUNCTION getsid 
RETURN NUMBER IS
	PRAGMA AUTONOMOUS_TRANSACTION;
	v_SID	NUMBER;
BEGIN
	SELECT reportseq.nextval INTO v_SID FROM dual;
	RETURN v_SID;
END getsid;
.
/
show errors

--	Funktion insvalue
--
--	Die Funktion fuegt Werte in die 
--	Tabelle reportorder ein und ueberprueft
--	das Resultat.
--
CREATE OR REPLACE FUNCTION insvalue(
	p_sid IN number,
	p_repname IN varchar,
	p_repnum IN number,
	p_key IN VARCHAR,
	p_value IN VARCHAR
)
RETURN NUMBER IS
	PRAGMA AUTONOMOUS_TRANSACTION;
	v_RESULT NUMBER;
	v_CHK NUMBER;
	v_CNT NUMBER;
BEGIN

	SELECT count(*)
	INTO v_CNT
	FROM reportorder r
	WHERE r.sid = p_sid
	AND r.repname != p_repname;

	v_RESULT:=0;

	IF v_CNT=0 THEN

		INSERT INTO reportorder (
			SID,
			REPNAME,
			REPNUM,
			KEY,
			VALUE,
			SESSION_USER,
			OS_USER,
			INS_TIMESTAMP
		)
		VALUES (
			p_sid,
			p_repname,
			p_repnum,
			p_key,
			p_value,
			sys_context('USERENV','SESSION_USER'),
			sys_context('USERENV','OS_USER'),
			SYSDATE
		);

	ELSE
		v_RESULT:=99;
		RAISE PROGRAM_ERROR;
	END IF;

	SELECT count(*)
	INTO v_CHK
	FROM dual,reportorder a
	WHERE a.sid = p_sid
	AND a.repname = p_repname
	AND NVL(a.key,'-') = NVL(key,'-')
	AND NVL(a.value,'-') = NVL(value,'-');

	IF v_CHK=0 THEN 
		RAISE PROGRAM_ERROR;
	END IF;

	COMMIT;

    RETURN v_RESULT;
END insvalue;
.
/

show errors

--	Die Schnittstellenview zu CE anlegen
--
--

--
--	Reportstart CE
--
CREATE OR REPLACE VIEW reportstart_ce (
   sid,
   repname,
   key,
   val,
   result )
AS
SELECT
	sid,
	repname,
	key,
	val,
	insvalue(sid,repname,0,key,val) AS result
FROM
(
WITH 
	alle AS 
    (
	-- Einen eindeutigen Identifier fuer diesen
	-- Reportorder herstellen
	( SELECT '_SID' AS key , TO_CHAR(getsid()) AS val FROM dual )
    UNION
    -- Den Reportnamen aus der reportlist holen
    ( SELECT '_REPNAME' AS key, repname AS val FROM reportlist )
    UNION
	( SELECT 'KDART' AS key, 'RVP' AS val FROM dual
        UNION SELECT 'KDART','RVN' FROM dual
        UNION SELECT 'KDART','›GN' FROM dual
        UNION SELECT 'KDART','›PN' FROM dual
        UNION SELECT 'KDART','GK ohne KV' FROM dual )
    UNION 
    -- Eine Liste der als Parameter verwendbaren
    -- Monate holen
	(SELECT DISTINCT
            'MONAT' AS key,
	       TO_CHAR(DATUM,'YYYY-MM') AS val
	FROM    
        dwhcore.co_zeit
    	WHERE
		datum >= SYSDATE - ( 24 * 32 )
		AND datum <= SYSDATE
	)
	-- Eine Liste der als Parameter verwendbaren
	-- Starttage holen
    UNION
	(SELECT DISTINCT
		'TAGVON' as key,
		TO_CHAR(DATUM,'YYYY-MM-DD') AS val
	FROM
		dwhcore.co_zeit
	WHERE
		datum >= SYSDATE - ( 24 * 32 )
		AND datum <= SYSDATE
	)
	UNION
	-- Eine Liste der als Parameter verwendbaren
	-- Endtage holen
	(SELECT DISTINCT
		'TAGBIS' as key,
		TO_CHAR(DATUM,'YYYY-MM-DD') AS val
	FROM
		dwhcore.co_zeit
	WHERE
		datum >= SYSDATE - ( 24 * 32 )
		AND datum <= SYSDATE
	)
    UNION 
    -- Eine Liste der als Parameter verwendbaren
    -- GK-IDs holen
	( SELECT DISTINCT 'GKID',quell_gk_id FROM dwhcore.co_gk_ref )
	UNION
    -- Region der Vertriebspartner	
    ( SELECT DISTINCT 'VPREGION',region_name FROM dwhcore.co_region
    WHERE gueltig_von <= SYSDATE AND gueltig_bis > SYSDATE )
    UNION
    -- Team der Vertriebspartner	
    ( SELECT DISTINCT 'VPTEAM',team_name FROM dwhcore.co_team
    WHERE gueltig_von <= SYSDATE AND gueltig_bis > SYSDATE )
    UNION
    -- Status der Vertriebspartner
    ( SELECT DISTINCT 'VPSTATUS', status_name FROM 
    dwhcore.co_vertriebspartner_status
    WHERE gueltig_von <= SYSDATE AND gueltig_bis > SYSDATE )
    UNION
    -- Schalter, ob Vertriebspartner zum Zeitpunkt der
    -- Aktivierung oder zum aktuellen Zeitpunkt verwendet
    -- werden sollen.
    ( SELECT 'VPSCHALTER','AKTIV' FROM dual
    UNION SELECT 'VPSCHALTER','AKTUELL' FROM dual
    )),
	-- SID und Reportname brauchen wir im 
	-- letzten Schritt eindeutig in jedem Satz
	-- deshalb jetzt hier herausholen.
    sidrep AS (
    	SELECT
    		a.val as sid,
    		b.val as repname
    	FROM
    		alle a,
    		alle b
    	WHERE
    		a.key = '_SID'
    		AND b.key = '_REPNAME'
    )
SELECT
	s.sid,
	s.repname,
	a.key,
	a.val
FROM
	sidrep s,
	alle a
);


--	reportstart CE Kunde
--
CREATE OR REPLACE VIEW reportstart_kunde_ce (
   sid,
   repname,
   key,
   val,
   result )
AS
SELECT
	sid,
	repname,
	'KUNDENR',
	val,
	insvalue(sid,repname,0,'KUNDENR',val) AS result
FROM
(
WITH 
	alle AS 
	(
	-- Einen eindeutigen Identifier fuer diesen
	-- Reportorder herstellen
	( SELECT '_SID' AS key , TO_CHAR(getsid()) AS val FROM dual )
	UNION
	-- Den Reportnamen aus der reportlist holen
	( SELECT '_REPNAME' AS key, repname AS val FROM reportlist )
	UNION 
	(SELECT 
		'KUNDENR' as key,
		TO_CHAR(kubis_kunde_id) AS val
	FROM
		dwhcorera.cr_kunden
	)),
        -- SID und Reportname brauchen wir im
        -- letzten Schritt eindeutig in jedem Satz
        -- deshalb jetzt hier herausholen.
    sidrep AS (
        SELECT
                a.val as sid,
                b.val as repname
        FROM
                alle a,
                alle b
        WHERE
                a.key = '_SID'
                AND b.key = '_REPNAME'
    )
SELECT
	s.sid,
	s.repname,
	'KUNDENR' AS key,
	TO_CHAR(cr.kubis_kunde_id) AS val
FROM
	sidrep s,
	dwhcorera.cr_kunden cr
);

--	Reportstart Blank CE
--
--
CREATE OR REPLACE VIEW reportstart_blank_ce (
   sid,
   repname,
   key,
   val,
   result )
AS
SELECT
	sid,
	repname,
	'',
	'',
	insvalue(sid,repname,0,'','') AS result
FROM
(
WITH 
	alle AS 
	(
	-- Einen eindeutigen Identifier fuer diesen
	-- Reportorder herstellen
	( SELECT '_SID' AS key , TO_CHAR(getsid()) AS val FROM dual )
	UNION
	-- Den Reportnamen aus der reportlist holen
	( SELECT '_REPNAME' AS key, repname AS val FROM reportlist )
	),
        -- SID und Reportname brauchen wir im
        -- letzten Schritt eindeutig in jedem Satz
        -- deshalb jetzt hier herausholen.
    	sidrep AS (
        SELECT
                a.val as sid,
                b.val as repname
        FROM
                alle a,
                alle b
        WHERE
                a.key = '_SID'
                AND b.key = '_REPNAME'
    )
SELECT
	s.sid,
	s.repname,
	'' AS key,
	'' AS val
FROM
	sidrep s
);


QUIT SQL.SQLCODE;
