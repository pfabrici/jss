#!/bin/ksh
################################################################################
#
#	tmpl_case
#
#	- BESCHREIBUNG
#
#	Das Template erlaubt die Verwendung einer Fallunterscheidung
#	innerhalb einer Jobkette.
#
#	Das Template tmpl_case.ksh liest eine Datei, deren Name in der 
#	zugehoerigen Konfigurationsdatei steht. In der Datei darf 
#	entweder das Wort TRUE oder FALSE stehen. In der Konfigurationsdatei 
#	gibt es dann einen Folgejob fuer TRUE und einen Folgejob fuer FALSE, 
#	der dann entsprechend ausgefuehrt wird.
#	Soll kein Folgejob ausgefuehrt werden, so gibt es dafuer 
#	auch eine Option.
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
#	P.Fabricius	19.12.2006	Erstellung
#	A.Kother	07.03.2008	aendern: Errorcase10: tmpl_ksh -> tmpl_case
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
	echo "Startet ein Shellscript"
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
#	tmpl_case
#
################################################################################
tmpl_case()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
	typeset MSG=""
	typeset CASECONTENT CASEJOB CASEJOBPARAMS 

	log tmpl_case "Start"

	while true ; do
		#	Parameter pruefen/setzen
		#
		[ -z ${JSSCASEFILE} ] && { ECODE=1; break; }
		[ -z ${JSSCASEJOBFALSE} ] && { ECODE=2; break; }
		[ -z ${JSSCASEJOBTRUE} ] && { ECODE=3; break; }
		[ -z ${BINDIR} ] && { ECODE=4; break; }
		[ -z ${ETCDIR} ] && { ECODE=5; break; }

		#
		[ ! -f ${JSSCASEFILE} ] && { ECODE=6; break; }

                # Im Casefile darf nur TRUE oder FALSE stehen
                #
		CASECONTENT=`cat ${JSSCASEFILE}`

		log tmpl_case "I: CASECONTENT = ${CASECONTENT}"

		case ${CASECONTENT} in 
			TRUE) CASEJOB=${JSSCASEJOBTRUE} ;;
			FALSE) CASEJOB=${JSSCASEJOBFALSE} ;;
			*) { ECODE=7; break;} ;;
		esac

		log tmpl_case "I: CASEJOB=${CASEJOB}"

		# Ein Jobeintrag = CASE_ENDE fuehrt zum 
		# Abbruch mit Exitcode 0
		#
		[ "X${CASEJOB}" = "XCASE_ENDE" ] && { ECODE=0; break; }

		# 
		#
		log tmpl_case "I: Ist ${BINDIR}/${CASEJOB} ausfuehrbar" 
		[ ! -x ${BINDIR}/${CASEJOB} ] && { ECODE=8; break; }

		( ksh ${BINDIR}/${CASEJOB} ${CASEJOBPARAMS} )
		[ $? -ne 0 ] && { ECODE=10; break; }

                #
                break
        done

        case ${ECODE} in
                0) MSG="I: ok" ;;
		1) MSG="F: Variable JSSCASEFILE nicht gesetzt" ;;
		2) MSG="F: Variable JSSCASEJOBFALSE nicht gesetzt" ;; 
		3) MSG="F: Variable JSSCASEJOBTRUE nicht gesetzt" ;; 
		4) MSG="F: Variable BINDIR nicht gesetzt" ;; 
		5) MSG="F: Variable ETCDIR nicht gesetzt" ;; 
		6) MSG="F: JSSCASEFILE ${JSSCASEFILE} nicht vorhanden" ;; 
		7) MSG="F: CASECONTENT nicht TRUE oder FALSE" ;;
		8) MSG="F: CASEJOB ${CASEJOB} nicht ausfuehrbar" ;; 
		10) MSG="F: Fehler beim Ausfuehren von CASEJOB ${CASEJOB}" ;;
                *) MSG="F: unbekannter Fehler" ;;
        esac

        log tmpl_case "${MSG}"
        log tmpl_case "Ende mit Exitcode ${ECODE}"

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
################################################################################
typeset -i EXITCODE=0
typeset MSG LOCALCFGFILE

while true ; do

	#	Basiskonfiguration einlesen
	#
	. ~/.jssrc

	#	Allgemeine Bibliothek einbinden
	#	erst danach koennen Logeintraege geschrieben werden
	#
	. ${LIBDIR}/liballg.ksh || { EXITCODE=1; break; }
	log Main "I: liballg included"

        . ${LIBDIR}/libprotokoll.ksh || { EXITCODE=20; break; }
        log Main "I: libprotokoll included"

	#	Scriptspezifische CFG-Datei einlesen
	#
        CFGPATH_ALL=`pwd`"/"${0#.\/}
        CFGPATH_PART=${CFGPATH_ALL%\/*}
        CFGPATH=${CFGPATH_PART##*\/}"/"
        [ "X${CFGPATH}" == "Xbin/" ] && CFGPATH=""

        LOCALCFGFILE=${ETCDIR}/${CFGPATH}/${BASENAME}.cfg
	[[ -f ${LOCALCFGFILE} ]] && {
		readvarfile ${LOCALCFGFILE} || { EXITCODE=30; break; }
	}

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
                [ -f ${INFILE} ] && rm ${INFILE}
        fi

	runcontrol INIT || { EXITCODE=5; break; }
	tmpl_case || { EXITCODE=10; break; }

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
	7) MSG="F: Einbindung libtimer.ksh" ;;
	8) MSG="F:  timerinit" ;;
	10) MSG="F: tmpl_case fehlgeschlagen" ;;
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
