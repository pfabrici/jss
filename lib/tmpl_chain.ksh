#!/bin/ksh
################################################################################
#
#	tmpl_chain
#
#	- BESCHREIBUNG
#
#	Dieses Template erlaubt es, mehrere Jobs dieser Scriptumgebung
#	in einem zusammenzufassen.
#
#	Parameter:
#		siehe usage Funktion
#
#       Konfigurationsparameter
#               uebergebbar ueber Kommandozeile, Konfigurationsdatei
#               auch globale Konfigurationsdatei
#               oder als uebergeordnete globale Variable.
#
#		CHAINDATE
#		CHAINJOBLIST	Enthaelt die Teiljobs
#		USEDBPARAMS	Schalter, ob Parameter aus der 
#				Datenbank geholt werden sollen
#				Wenn 1, dann wird in reportparams
#				nach Parametern gesucht
#
#	Fehlercodes:
#		1) Einbindung liballg.ksh
#		2) Einbindung libdb.ksh
#		3) Einlesen Hauptkonfiguration
#		30) Einlesen lokale Konfiguration
#		31) Einlesen INFILE
#		4) Parsen Kommandozeile
#		5) Job laeuft schon
#		6) Einbindung libjss.ksh
#		10) tmpl_chain fehlgeschlagen
#		20) Einbindung libprotokoll.ksh
#		21) initprotokoll fehlgeschlagen
#		22) finishprotokoll fehlgeschlagen
#		50) backupenv fehlgeschlagen
#		51) restoreenv fehlgeschlagen
#		99) Kein PID File bei laufendem Job
#		100) Abbruch wegen Urlaubstag
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
#		P.Fabricius	Erstellung
#		2007-11-29	P.Fabricius	restoreenv bei Holiday- Abbruch
#						eingefuegt
#		2008-08-14	P.Fabricius	INFOMAIL-Parameter in tmpl_config
#
################################################################################

################################################################################
#
#	usage
#
################################################################################
usage()
{
        echo "Shell-Tool ${BASENAME}"
	echo "versendet eine Mail"
        echo "Syntax: ${BASENAME} [-d] [-s]"
        echo
        echo "Script benoetigt eine Konfigurationsdatei ~/.jssrc"
	echo 
	echo "Optionen:"
	echo "    -d : Debugausgaben einschalten"
	echo "    -s : Konsolenausgaben einschraenken"
}

################################################################################
#
#       tmpl_config
#
#       jedes Skripttemplate soll einen eigenen Installationsmechanismus
#       haben, d.h. wenn dieses Template ohne Links mit dem Parameter
#       CONFIG aufgerufen wird, dann wird aufgrund von globalen
#       Variablen eine Konfigurationsdatei und der entsprechende Link erzeugt.
#
#       globale Variablen :
#		CFGCAT : Kategorie ( reports )
#		CFGIDENT :
#
#       CFGIDENT und DBCONNECT muessen gesetzt sein, sonst
#       wird mit einer Fehlermeldung abgebrochen !
#
################################################################################
tmpl_config()
{
        typeset -i ECODE=0
        typeset FNAME

        while true ; do
                [ -z ${CFGCAT} ] && { CFGCAT="reports"; }
                [ -z ${CFGIDENT} ] && { ECODE=201; break; }

                #       Link anlegen.
                #       Wenn schon eine Datei gleichen namens da
                #       ist sofort abbrechen!
                #
                [ -r ${BINDIR}/${CFGIDENT}.ksh ] && { ECODE=206; break; }
                ln -s ${LIBDIR}/tmpl_chain.ksh \
                        ${BINDIR}/${CFGIDENT}.ksh

                #       CFG Datei schreiben
                #
                FNAME=${ETCDIR}/${CFGIDENT}.cfg
		echo "CHAINDATE=\`date '+%Y%m%d'\`" > ${FNAME}
		echo "CHAINJOBLIST=\"${CFGCAT}/${CFGIDENT}_unl ${CFGCAT}/${CFGIDENT}_mail\"" >> ${FNAME}
		echo "RESULTFILE=\${DATADIR}/${CFGIDENT}_\${CHAINDATE}_\${SID}.csv" >> $FNAME
		echo "NOLOG=0" >> ${FNAME}
		echo "INFOMAIL=0" >> ${FNAME}
		echo "INFORECIPIENTS=\"\"" >> ${FNAME}
		echo "INFOTEXT=\"F: Der Job ${CFGCAT} ist fehlgeschlagen\"" >> ${FNAME}

                break;
        done

        return ${ECODE}
}

################################################################################
#
#	tmpl_chain
#
################################################################################
tmpl_chain()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
	typeset MSG=""

	log tmpl_chain "Start"

	while [ 1 -eq 1 ] ; do
                #       Mail erstellen und versenden
                #
		runchain
                [ $? -ne 0 ] && { ECODE=2; break; }

                #
                break
        done

        case ${ECODE} in
                0) MSG="I: ok" ;;
                2) MSG="F: Fehler in einem Kettenjob" ;;
                *) MSG="F: unbekannter Fehler" ;;
        esac

        log tmpl_chain "${MSG}"
        log tmpl_chain "Ende mit Exitcode ${ECODE}"

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
#	2007-11-29	P.Fabricius	restoreenv bei holiday Abbruch
#					aufrufen
#
################################################################################
typeset -i EXITCODE=0
#typeset -i NOLOG=0
typeset MSG LOCALCFGFILE

while [ 1 -eq 1 ] ; do

        #       Basiskonfiguration einlesen
        #
	.  ~/.jssrc

        #       CONFIG Modus ?
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

	#	Umgebung sichern
	#
	backupenv || { EXITCODE=50; break; }

	#	Basiskonfiguration einlesen
	#
	# readvarfile ~/.jssrc
	# [ $? -ne 0 ] && { EXITCODE=3; break; }

	#	Scriptspezifische CFG-Datei einlesen
	#
        CFGPATH_ALL=`pwd`"/"${0#.\/}
        CFGPATH_PART=${CFGPATH_ALL%\/*}
        CFGPATH=${CFGPATH_PART##*\/}"/"
	[ "X${CFGPATH}" == "Xbin/" ] && CFGPATH=""

        LOCALCFGFILE=${ETCDIR}/${CFGPATH}${BASENAME}.cfg
	log Main "I: LOCALCFGFILE = ${LOCALCFGFILE}"
	if [ -f ${LOCALCFGFILE} ] ; then
		readvarfile ${LOCALCFGFILE}
		[ $? -ne 0 ] && { EXITCODE=30; break; }
	fi

	#	Evtl. noch Parameter aus der DB
	#	holen
	#
	if [ ${USEDBPARAMS:-0} -eq 1 ] ; then
		log Main "I: Hole DB Params"
		TMPDBPARAMFILE=${TMPDIR}/${BASENAME}_$$.dbparam
		log Main "I: ${BINDIR}/sys/getdbparams.ksh -v \"MYPARAMFILE=${TMPDBPARAMFILE}\" -v \"MYBINARY=${0}\" "
		${BINDIR}/sys/getdbparams.ksh -v "MYPARAMFILE=${TMPDBPARAMFILE}" -v "MYBINARY=${BINDIR}/${CFGPATH}${BASENAME}.ksh"
		[ $? -ne 0 ] && { EXITCODE=40; break; }

		readvarfile ${TMPDBPARAMFILE} || { EXITCODE=41; break; }
		[ -f ${TMPDBPARAMFILE} ] && rm ${TMPDBPARAMFILE} 
	else
		log Main "I: Keine DB Params"
	fi

	#	Kommandozeilenparameter ueberschreiben
	#	Inhalt der Konfigurationsdatei
	#
	initprotokoll || { EXITCODE=21; break; }
	parseparms "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "$10" "$11" "$12" || { usage; EXITCODE=4; break; }
	#parseparms $* || { usage; EXITCODE=4; break; }

        #       Darf die Verarbeitung heute laufen?
        #
        noholiday || { restoreenv; exit 42; }

        #       Wenn in der Konfiguration ein
        #       INFILE gesetzt ist, dann dieses einlesen
        #
        if [ ! -z ${INFILE} ] && [ -f ${INFILE} ] ; then
                readvarfile ${INFILE} || { EXITCODE=31; break; }
                [ -f ${INFILE} ] && rm ${INFILE}
        fi

	runcontrol INIT || { EXITCODE=5; break; }
	tmpl_chain || { EXITCODE=10; break; }

	#
	break
done

[ ${EXITCODE} -ne 5 ] && runcontrol FINISH
finishprotokoll ${EXITCODE} || { EXITCODE=22; break; }

log Main "Exitcode =${EXITCODE} "
restoreenv || { EXITCODE=51; break; }
log Main "Exitcode =${EXITCODE} "

case ${EXITCODE} in 
	0) MSG="I: ok" ;;
	1) MSG="F: Einbindung liballg.ksh" ;;
	2) MSG="F: Einbindung libdb.ksh" ;;
	3) MSG="F: Einlesen Hauptkonfiguration" ;;
	30) MSG="F: Einlesen lokale Konfiguration" ;;
	31) MSG="F: Einlesen INFILE" ;;
	4) MSG="F: Parsen Kommandozeile" ;;
	5) MSG="F: Job laeuft schon" ;;
	6) MSG="F: Einbindung libjss.ksh" ;;
	10) MSG="F: tmpl_chain fehlgeschlagen" ;;
	20) MSG="F: Einbindung libprotokoll.ksh" ;;
	21) MSG="F: initprotokoll fehlgeschlagen" ;;
	22) MSG="F: finishprotokoll fehlgeschlagen" ;;
	40) MSG="F: DB Params holen fehlgeschlagen" ;;
	41) MSG="F: readvar DB Params fehlgeschlagen" ;;
	51) MSG="F: restoreenv fehlgeschlagen" ;;
	99) MSG="F: Kein PID File bei laufendem Job" ;;
	100) MSG="F: Abbruch wegen Urlaubstag" ;;
	*) MSG="F: unbekannter Fehler" ;;
esac

log Main "${MSG}"
log Main "${NOLOG} ${LOGFILE}"
[ ${NOLOG:-0} -eq 1 ] && [ ! -z ${LOGFILE} ] && [ -f ${LOGFILE} ] && rm ${LOGFILE} 2>/dev/null
exit ${EXITCODE}
