#!/bin/ksh
################################################################################
#
#	tmpl_daemon
#
#	- BESCHREIBUNG
#
#	Ueber den Linknamen werden die erforderlichen Konfigurations
#	dateien ermittelt, die das weitere Vorgehen definnieren.
#	Weitere Informationen befinden sich im Header von liballg.ksh.
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
#		P.Fabricius 	Erstellung
#
################################################################################

################################################################################
#
#	usage
#
#	Gibt eine usage Meldung aus, wenn das Skript 
#	mit falscher Syntax aufgerufen wurde.
#
################################################################################
usage()
{
        echo "Shell-Tool ${BASENAME}"
	echo "Regelmaessige Wiederholung von Tasks"
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
#	tmpl_daemon
#
################################################################################
tmpl_daemon()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
	typeset MSG=""
	typeset SCRIPT RCNT

	log tmpl_daemon "Start"

	while true ; do
		#	Parameter pruefen/setzen
		#
		[ -z ${BASENAME} ] && { ECODE=1; break; }
		[ -z ${SLEEPTIME} ] && { ECODE=5; break; }
		[ -z ${SCRIPTLIST} ] && { ECODE=6; break; }
		[ -z ${BINDIR} ] && { ECODE=7; break; }
		[ -z ${MAXRUN} ] && { ECODE=8; break; }

		#	Nun die Daemonschleife
		#
		RCNT=0
		while true ; do
			RCNT=$(( RCNT + 1 ))
			log tmpl_daemon "I: Durchlauf ${RCNT}"			

			[ ${RCNT} -eq ${MAXRUN} ] && break;

			for SCRIPT in ${SCRIPTLIST} ; do 
				[ ! -x ${BINDIR}/${SCRIPT}.ksh ] && 
					{ ECODE=22; break; }
				log tmpl_daemon "I: Starte ${SCRIPT}"
				nohup ${BINDIR}/${SCRIPT}.ksh &
			done

			log tmpl_daemon "I: Schlafe jetzt ... "
			sleep ${SLEEPTIME}
		done

                #
                break
        done

        case ${ECODE} in
                0) MSG="I: ok" ;;
                1) MSG="F: Variable BASENAME nicht gesetzt" ;;
                5) MSG="F: Variable SLEEPTIME nicht gesetzt" ;;
                6) MSG="F: Variable SCRIPTLIST nicht gesetzt" ;;
                7) MSG="F: Variable BINDIR nicht gesetzt" ;;
                8) MSG="F: Variable MAXRUN nicht gesetzt" ;;
                22) MSG="F: Script nicht ausfuehrbar" ;;
                *) MSG="F: unbekannter Fehler" ;;
        esac

        log tmpl_daemon "${MSG}"
        log tmpl_daemon "Ende mit Exitcode ${ECODE}"

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

        #       Basiskonfiguration einlesen
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
	tmpl_daemon || { EXITCODE=10; break; }

	#
	break
done

[ ${EXITCODE} -ne 5 ] && runcontrol FINISH
finishprotokoll ${EXITCODE} || { EXITCODE=22; break; }

case ${EXITCODE} in 
	0) MSG="I: ok" ;;
	1) MSG="F: Einbindung liballg.ksh" ;;
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
