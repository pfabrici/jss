#!/bin/ksh
################################################################################
#
#	tmpl_ksh
#
#	- BESCHREIBUNG
#       Templatescript fuer die Ausfuehrung von KSH Dateien
#       Dieses Script wird i.d.R. nicht direkt aufgerufen, sondern
#       nur ueber Links.
#       Ueber den Linknamen werden die erforderlichen Konfigurations-
#       dateien ermittelt, die das weitere Vorgehen definnieren.
#       Weitere Informationen befinden sich im Header von liballg.ksh.
#
#       Parameter:
#               siehe usage Funktion
#
#       Konfigurationsparameter:
#               uebergebbar ueber Kommandozeile, Konfigurationsdatei
#               auch globale Konfigurationsdatei
#               oder als uebergeordnete globale Variable.
#
#		CFGKSHFILE	auszufuehrendes KSH Skript
#
#	Fehlercodes:
#		1) Einbindung liballg.ksh
#		2) Einbindung libdb.ksh
#		3) Einlesen Hauptkonfiguration
#		4) Parsen Kommandozeile
#		5) Job laeuft schon
#		6) Einbindung libjss.ksh
#		7) Einbindung libtimer.ksh
#		8)  timerinit
#		10) tmpl_ksh fehlgeschlagen
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
#		P.Fabricius	Erstellung
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
#	tmpl_ksh
#
################################################################################
tmpl_ksh()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
	typeset MSG=""

	log tmpl_ksh "Start"

	while true ; do
		#	Parameter pruefen/setzen
		#
		[ -z ${BASENAME} ] && { ECODE=1; break; }

                #       auszufuehrendes SQL File ermitteln
                #       wenn in der Konfiguration keine
                #       Datei angegeben ist, wird im SQLDIR
                #       nach ${MYDBTYPE}_${BASENAME}.sql
                #       gesucht
                #
                [[ -z ${CFGKSHFILE} ]] && {
                        [ -z {SQLDIR} ] && { ECODE=22; break; }
                        [ ! -d ${SQLDIR} ] && { ECODE=23; break; }

                        CFGKSHFILE=${SQLDIR}/${BASENAME}.ksh
                        log runsqlfile "I: CFGKSHFILE=${CFGKSHFILE}"
		}

                #       Statement ausfuehren
                #
                runshellscript ${CFGKSHFILE}
                [ $? -ne 0 ] && { ECODE=2; break; }

                #
                break
        done

        case ${ECODE} in
                0) MSG="I: ok" ;;
                1) MSG="F: Variable BASENAME nicht gesetzt" ;;
                2) MSG="F: Ausfuehrung Shellscript" ;;
                20)  MSG="F: Variable DBTYPE nicht gesetzt" ;;
                22)  MSG="F: Variable SQLDIR nicht gesetzt" ;;
                *) MSG="F: unbekannter Fehler" ;;
        esac

        log tmpl_ksh "${MSG}"
        log tmpl_ksh "Ende mit Exitcode ${ECODE}"

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

        . ${LIBDIR}/libdb.ksh || { EXITCODE=2; break; }
        log Main "I: libdb included"

        . ${LIBDIR}/libtimer.ksh || { EXITCODE=7; break; }
        log Main "I: libtimer included"

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

	#	Evtl. einen Timer aufziehen
	#
	timerinit || { ECODE=8; break; }

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
	tmpl_ksh || { EXITCODE=10; break; }

	#
	break
done

[ ${EXITCODE} -ne 5 ] && runcontrol FINISH
timerstop
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
	10) MSG="F: tmpl_ksh fehlgeschlagen" ;;
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
