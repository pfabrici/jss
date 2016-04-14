
DROP TABLE IF EXISTS dummy;
DROP TABLE IF EXISTS reportverzeichnis;
DROP TABLE IF EXISTS reporttyp;
DROP TABLE IF EXISTS reportlist;
DROP TABLE IF EXISTS reportcontent;
DROP TABLE IF EXISTS reportorder;
DROP TABLE IF EXISTS reportparams;
DROP TABLE IF EXISTS reportctrl;
DROP TABLE IF EXISTS reporttmp;
DROP TABLE IF EXISTS reportlog;

-- Tabelle dual --------------------------------------------------------------
CREATE TABLE dummy (
	dummy	CHAR(1)
);

INSERT INTO dummy VALUES ('X');

-- Tabelle reportverzeichnis ---------------------------------------------------
CREATE TABLE reportverzeichnis (
        verzeichnis     INTEGER,
        titel           varchar(100) NOT NULL,
	PRIMARY KEY (verzeichnis )
);

-- Tabelle reporttyp ---------------------------------------------------------
CREATE TABLE reporttyp (
        reptyp          INTEGER,
        beschr          VARCHAR(80)    NOT NULL,
	PRIMARY KEY ( reptyp )
);

INSERT INTO reporttyp VALUES ( 1, 'UNIX Skript');
INSERT INTO reporttyp VALUES ( 2, 'UNIX Skript mit Crystal-Enterprise -Frontend');
INSERT INTO reporttyp VALUES ( 3, 'Crystal-Enterprise Report');

-- Tabelle reportlist ---------------------------------------------------------

CREATE TABLE reportlist (
        repname         VARCHAR(100) NOT NULL,
        repnum          INTEGER,
        repbinary       VARCHAR(255)   NOT NULL,
        anzkeys         INTEGER		DEFAULT 0 NOT NULL,
        easyplan        INTEGER,
        verzeichnis     INTEGER          NOT NULL REFERENCES reportverzeichnis,
        unixuser        VARCHAR(8),
        active          VARCHAR(1),
        reptyp          INTEGER          NOT NULL REFERENCES reporttyp,
        beschr          TINYTEXT,
	PRIMARY KEY ( repnum )
);

CREATE UNIQUE INDEX reportlist_name ON reportlist(repname);

-- Tabelle reportcontent  -----------------------------------------------------
CREATE TABLE reportcontent (
        repnum          INTEGER NOT NULL REFERENCES reportlist,
        repsub          SMALLINT DEFAULT 1 NOT NULL,
        attrib_num      SMALLINT NOT NULL,
        attrib          VARCHAR(128),
        attrib_desc     VARCHAR(255)
);

-- Tabelle reportorder --------------------------------------------------------
CREATE TABLE reportorder (
        SID             INTEGER NOT NULL,
        REPNAME         VARCHAR(100) NOT NULL,
        REPNUM          INTEGER NOT NULL,
        KEYX             VARCHAR(40),
        VALUE          VARCHAR(128),
        SESSION_USER    VARCHAR(30),
        OS_USER         VARCHAR(30),
        INS_TIMESTAMP   DATETIME
);

-- Tabelle reportparams --------------------------------------------------------
CREATE TABLE reportparams (
        repnum          INTEGER NOT NULL REFERENCES reportlist,
        keyorder        INTEGER NOT NULL,
        keyx             VARCHAR(80),
        keytype         VARCHAR(1),
        value           TINYTEXT
);

-- Tabelle reportctrl ---------------------------------------------------------
-- kein Defaultwert fuer due DATETIME - Spalten ins_timestamp
-- und last_update
--
CREATE TABLE reportctrl (
        sid             INTEGER,
        repbinary       VARCHAR(255),
        str             TINYTEXT,
        status          VARCHAR(50),
        starttime       DATETIME,
        endtime         DATETIME,
        ecode           SMALLINT,
        ins_timestamp   DATETIME NOT NULL,
        last_update     DATETIME NOT NULL
);

-- Tabelle reporttmp ---------------------------------------------------------

--      Tabelle reporttmp
--      eine Hilfstabelle, die bei der Transformation
--      der Daten von reportorder nach reportctrl
--      benoetigt wird.
--      - sid           : Identifier der Bearbeitung
--      - repname       : Reportname
--      - str           : Parameterstring
--
CREATE TABLE reporttmp (
        sid             INTEGER,
        repname         VARCHAR(100),
        str             TINYTEXT
);

-- Tabelle reportlog ---------------------------------------------------------
CREATE TABLE reportlog (
        ID              INTEGER NOT NULL,
        TMSTMP          DATETIME NOT NULL,
        VORGANG_ID      INTEGER,
        OBJEKTNAME      VARCHAR(100),
        ERRORLOG        VARCHAR(200),
        TECHDELTA       VARCHAR(10),
        FACHDELTA       VARCHAR(20),
        PROZESS_NR      INTEGER,
        STATUS_OK       SMALLINT,
        QUELLSYSTEM     VARCHAR(20)
);
