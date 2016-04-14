#!/bin/ksh
################################################################################
#
#	tmpl_sqlfile
#
#	- BESCHREIBUNG
#
#	Templatescript fuer die Ausfuehrung von SQL Dateien
#	Dieses Script wird i.d.R. nicht direkt aufgerufen, sondern 
#	nur ueber Links. 
#	Neben der Templatefunktion wird auch eine Konfigurations-
#	funktion zur Verfuegung gestellt. Diese ist unter der Funktion
#	tmpl_config beschrieben.
#	Ueber den Linknamen werden die erforderlichen Konfigurations-
#	dateien ermittelt, die das weitere Vorgehen definnieren.
#	Weitere Informationen befinden sich im Header von liballg.ksh.
#
#	Parameter:
#		siehe usage Funktion
#
#	Konfigurationsparameter
#		uebergebbar ueber Kommandozeile, Konfigurationsdatei 
#		auch globale Konfigurationsdatei
#		oder als uebergeordnete globale Variable.
#
#		DBTYPE		Pflichtangabe,
#				Auspraegungen siehe libdb->runsqlfile
#		DBCONNECT	Pflichtangabe, ausser bei 
#				DB Authentifizierung ueber Betriebssystem-
#				benutzer
#		CFGSQLFILE	Optionale Angabe, siehe Header der
#				Funktion tmpl_sqlfile
#
#	Fehlercodes:
#		1) Einbindung liballg.ksh
#		2) Einbindung libdb.ksh
#		3) Einlesen Hauptkonfiguration
#		4) Parsen Kommandozeile
#		5) Job laeuft schon
#		6) Einbindung libjss.ksh
#		10) tmpl_sqlfile fehlgeschlagen
#		20) Einbindung libprotokoll.ksh
#		21) initprotokoll fehlgeschlagen
#		22) finishprotokoll fehlgeschlagen
#		30) Einlesen lokale Konfiguration
#		31) Einlesen INFILE
#		99) Kein PID File bei laufendem Job
#
#       - LIZENZ
#
#       Copyright (C) 2005 Peter Fabricius
#
#       This program is free software; you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation; either version 2 of the License, or
#       (at your option) any later version.
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program; if not, write to the Free Software
#       Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#       - KONTAKT
#       pfabricius@gmx.de
#
#       - TODO
#
#       - HISTORIE
#
#	P.Fabricius			Erstellung
#			24.8.2006	Dokumentation
#
################################################################################

################################################################################
#
#	usage
#
#	Gibt eine usage Meldung aus, wenn das Skript 
#	mit falscher Syntax aufgerufen wurde.
#
#	Parameter:
#		keine
#
#	Fehlercodes:
#		keine
#
#	Historie:
#		P.Fabricius	24.8.2006	Erweiterung um fehlende Eintraege
#
################################################################################
usage()
{
        echo "Shell-Tool ${BASENAME}"
	echo "Fuehrt SQL Dateien aus."
        echo "Syntax: ${BASENAME} [-d] [-s] [-v KEY=VALUE [-v KEY=VALUE]] [-f]"
        echo
        echo "Script benoetigt eine Konfigurationsdatei ~/.jssrc"
	echo 
	echo "Optionen:"
	echo "    -d : Debugausgaben einschalten"
	echo "    -s : Konsolenausgaben einschraenken"
	echo "    -v : Variablen uebergeben"
	echo "    -f : force, Holidayfunktion uebergehen"
}

################################################################################
#
#	tmpl_config
#
#	jedes Skripttemplate soll einen eigenen Installationsmechanismus
#	haben, d.h. wenn dieses Template ohne Link mit dem Parameter
#	CONFIG aufgerufen wird, dann wird aufgrund von globalen 
#	Variablen eine Konfigurationsdatei und der entsprechende Link erzeugt.
#	Diese Funktion wird von mkskel.ksh verwendet.
#	Achtung : es wird noch keine Pruefung durchgefuehrt, ob auch 
#	alle der benoetigten globalen Variablen einen Wert beinhalten.
#	( nur teileweise )
#	Evtl. wird also eine Konfigurationsdatei mit KEYS ohne VALUES
#	geschrieben.
#
#	Parameter:
#		keine, nur globale Funktionen
#
#	globale Variablen :
#		CFGCAT	( default : reports ) Skriptkategorie 
#		CFGIDENT Identifier des Reports ( z.B. 0011_repname )
#		DBCONNECT
#		DBTYPE	( OR, IFX ... ) ( default OR )
#		ETLSYSTEM ( optional, default DWH )
#
#	CFGIDENT und DBCONNECT muessen gesetzt sein, sonst
#	wird mit einer Fehlermeldung abgebrochen !
#
#
#	Fehlercodes:
#		205: kein Verzeichnis ${BINDIR}/${CFGCAT} vorhanden
#		205: kein Verzeichnis ${ETCDIR}/${CFGCAT} vorhanden
#		206: Konfigurationsdatei ist schon da
#
#	Historie:
#	P.Fabricius			Erstellung
#	P.Fabricius	24.8.2006	Erweiterung Funktionsheader
#
################################################################################
tmpl_config()
{
	typeset -i ECODE=0
	typeset FNAME

	while true ; do
		[ -z ${CFGCAT} ] && CFGCAT="reports"
		[ -z ${CFGIDENT} ] && { ECODE=201; break; }
		[ -z ${DBCONNECT} ] && { ECODE=202; break; }

		[ ! -d ${BINDIR}/${CFGCAT} ] && { ECODE=205; break; }
		[ ! -d ${ETCDIR}/${CFGCAT} ] && { ECODE=205; break; }

		#	Link anlegen.
		#	Wenn schon eine Datei gleichen namens da
		#	ist sofort abbrechen!
		#
		[ -r ${BINDIR}/${CFGCAT}/${CFGIDENT}_unl.ksh ] && { ECODE=206; break; }

		ln -s ${LIBDIR}/tmpl_sqlfile.ksh \
			${BINDIR}/${CFGCAT}/${CFGIDENT}_unl.ksh 

		#	CFG Datei schreiben
		#
		FNAME=${ETCDIR}/${CFGCAT}/${CFGIDENT}_unl.cfg
		echo "DBTYPE=${DBTYPE:-OR}" > ${FNAME}
		echo "DBCONNECT=\${DWHFLEXUSER}" >> ${FNAME}
		echo "CFGSQLFILE=\${SQLDIR}/${CFGCAT}/${CFGIDENT}_unl.sql" >> $FNAME
		echo "ETLPROTOKOLL=1" >> ${FNAME}
		echo "ETLVORGANG=${EASYPLAN}" >> ${FNAME}
		echo "ETLOBJEKT=\"${CFGIDENT}, Unload\"" >> ${FNAME}
		echo "ETLSYSTEM=${ETLSYSTEM:-DWH}" >> ${FNAME}

		#	Reporttemplate kopieren
		#
		cp ${LIBDIR}/tmpl_report_unl.sql ${SQLDIR}/${CFGCAT}/${CFGIDENT}_unl.sql

		break;
	done

	return ${ECODE}
}

################################################################################
#
#	tmpl_sqlfile
#
#	prueft, ob mit der Variablen CFGSQLFILE eine Datei beschrieben
#	wird. Wenn CFGSQLFILE nicht gesetzt ist, wird ein 
#	Defaultwert generiert, der sich wie folgt zusammensetzt:
#	$SQLDIR/$DBTYPE_$BASENAME.sql
#	Mit diesem Parameter wird die Funktion runsql aus der libdb.ksh
#	aufgerufen.
#
#	Fehlercodes:
#		1) Variable BASENAME nicht gesetzt
#		2) Ausfuehrung SQL
#		20)  Variable DBTYPE nicht gesetzt
#		22)  Variable SQLDIR nicht gesetzt
#		23)  SQLDIR ist kein Verzeichnis
#
#	Historie:
#		P.Fabricius	24.8.2006	Erweiterung Header
#		P.Fabricius	03.1.2008	CFGPATH in manuellem
#						Setzen von CFGSQLFILE 
#						beruecksichtigen
#
################################################################################
tmpl_sqlfile()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
	typeset MSG=""

	log tmpl_sqlfile "Start"

	while true ; do
		#	Parameter pruefen/setzen
		#
		[ -z ${BASENAME} ] && { ECODE=1; break; }

		#	auszufuehrendes SQL File ermitteln
		#	wenn in der Konfiguration keine 
		#	Datei angegeben ist, wird im SQLDIR
		#	nach ${MYDBTYPE}_${BASENAME}.sql 
		#	gesucht
		#
		if [ -z ${CFGSQLFILE} ] ; then
			MYDBTYPE=${DBTYPE:-$2}
			[ -z ${MYDBTYPE} ] && { ECODE=20; break; }

			[ -z {SQLDIR} ] && { ECODE=22; break; }
			[ ! -d ${SQLDIR} ] && { ECODE=23; break; }

			CFGSQLFILE=${SQLDIR}/${CFGPATH}${MYDBTYPE}_${BASENAME}.sql
			log tmpl_sqlfile "I: CFGSQLFILE=${CFGSQLFILE}"
		fi

                #       Statement ausfuehren
                #
                runsql ${CFGSQLFILE} || { ECODE=2; break; }

                #
                break
        done

        case ${ECODE} in
                0) MSG="I: ok" ;;
                1) MSG="F: Variable BASENAME nicht gesetzt" ;;
                2) MSG="F: Ausfuehrung SQL" ;;
                20)  MSG="F: Variable DBTYPE nicht gesetzt" ;;
                22)  MSG="F: Variable SQLDIR nicht gesetzt" ;;
                23)  MSG="F: SQLDIR ist kein Verzeichnis" ;;
                *) MSG="F: unbekannter Fehler" ;;
        esac

        log tmpl_sqlfile "${MSG}"
        log tmpl_sqlfile "Ende mit Exitcode ${ECODE}"

        return ${ECODE}
}

################################################################################
#
#	Main
#
#	Hauptroutine. Bibliotheken einlesen, Konfiguration 
#	lesen bzw. Kommandozeilenparameter auswerten.
#	Parallellaeufe vermeiden und den Startmechanismus anwerfen.
#
#
#	Historie:
#		P.Fabricius	24.8.2006	Erweiterung Readme
#		P.Fabricius	3.1.2008	restoreenv bei noholiday
#
################################################################################
typeset -i EXITCODE=0
typeset MSG LOCALCFGFILE

while true ; do

        #       Basiskonfiguration einlesen
        #
	. ~/.jssrc

	#	CONFIG Modus ?
	#
	[ "X${1}" == "XCONFIG" ] &&  { tmpl_config; exit $?; }

	#	Allgemeine Bibliothek einbinden
	#	erst danach koennen Logeintraege geschrieben werden
	#
	. ${LIBDIR}/liballg.ksh || { EXITCODE=1; break; }
	log Main "I: liballg included"

        . ${LIBDIR}/libdb.ksh || { EXITCODE=2; break; }
        log Main "I: libdb included"

        . ${LIBDIR}/libprotokoll.ksh || { EXITCODE=20; break; }
        log Main "I: libprotokoll included"

	#	Scriptspezifische CFG-Datei einlesen
	#
	CFGPATH_ALL=`pwd`"/"${0#.\/}
	CFGPATH_PART=${CFGPATH_ALL%\/*}
	CFGPATH=${CFGPATH_PART##*\/}"/"
        [ "X${CFGPATH}" == "Xbin/" ] && CFGPATH=""

	LOCALCFGFILE=${ETCDIR}/${CFGPATH}/${BASENAME}.cfg 
	if [ -f ${LOCALCFGFILE} ] ; then
		readvarfile ${LOCALCFGFILE} || { EXITCODE=30; break; }
	fi

	#	Kommandozeilenparameter ueberschreiben
	#	Inhalt der Konfigurationsdatei
	#
        initprotokoll || { EXITCODE=21; break; }
	#parseparms "$1" "$2" "$3" "$4" "$4" "$5" "$6" "$7" "$8" "$9" "$10" "$11" "$12" || { usage; EXITCODE=4; break; }
	parseparms $* || { usage; EXITCODE=4; break; }

        #       Darf die Verarbeitung heute laufen?
        #
        noholiday || { restoreenv; exit 42; }

        #       Wenn in der Konfiguration ein
        #       INFILE gesetzt ist, dann dieses einlesen
        #
        if [ ! -z ${INFILE} ] && [ -f ${INFILE} ] ; then
                readvarfile ${INFILE} || { EXITCODE=31; break; }
                #rm ${INFILE}
        fi

	runcontrol INIT || { EXITCODE=5; break; }
	tmpl_sqlfile || { EXITCODE=10; break; }

	#
	break
done

[ ${EXITCODE} -ne 5 ] && runcontrol FINISH
finishprotokoll ${EXITCODE} || { EXITCODE=22; break; }

case ${EXITCODE} in 
	0) MSG="I: ok" ;;
	1) MSG="F: Einbindung liballg.ksh" ;;
	2) MSG="F: Einbindung libdb.ksh" ;;
	3) MSG="F: Einlesen Hauptkonfiguration" ;;
	4) MSG="F: Parsen Kommandozeile" ;;
	5) MSG="F: Job laeuft schon" ;;
	6) MSG="F: Einbindung libjss.ksh" ;;
	10) MSG="F: tmpl_sqlfile fehlgeschlagen" ;;
        20) MSG="F: Einbindung libprotokoll.ksh" ;;
        21) MSG="F: initprotokoll fehlgeschlagen" ;;
        22) MSG="F: finishprotokoll fehlgeschlagen" ;;
	30) MSG="F: Einlesen lokale Konfiguration" ;;
	31) MSG="F: Einlesen INFILE" ;;
	99) MSG="F: Kein PID File bei laufendem Job" ;;
	*) MSG="F: unbekannter Fehler" ;;
esac

log Main "${MSG}"
[ ${NOLOG:-0} -eq 1 ] && [ ! -z ${LOGFILE} ] && [ -f ${LOGFILE} ] && rm ${LOGFILE} 2>/dev/null
exit ${EXITCODE}
