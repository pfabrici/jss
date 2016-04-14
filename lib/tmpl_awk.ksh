#!/bin/ksh
################################################################################
#
#	tmpl_awk
#
#       Templatescript fuer die Ausfuehrung von awk Dateien
#       Dieses Script wird i.d.R. nicht direkt aufgerufen, sondern
#       nur ueber Links.
#       Ueber den Linknamen werden die erforderlichen Konfigurations-
#       dateien ermittelt, die das weitere Vorgehen definnieren.
#       Weitere Informationen befinden sich im Header von liballg.ksh.
#
#       Parameter:
#               siehe usage Funktion
#
#       Konfigurationsparameter
#               uebergebbar ueber Kommandozeile, Konfigurationsdatei
#               auch globale Konfigurationsdatei
#               oder als uebergeordnete globale Variable.
#
#		INDATE		Zu verarbeitende Ausgangsdaten
#		OUTDATA		Ergenisdatei, optional
#		CFGAWKFILE	Verweis auf das AWK Skriptfile
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
#		10) tmpl_awk fehlgeschlagen
#		15) initprotokoll fehlgeschlagen
#		16) finishprotokoll fehlgeschlagen
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
#	tmpl_config Funktionalitaet analog zu tmpl_sqlfile 
#	einbauen
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
	echo "Startet ein AWK-script"
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
#	tmpl_awk
#
#	1.8.05	P.Fabricius	Umbau auf CFGAWKFILE Mechanismus
#
################################################################################
tmpl_awk()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
	typeset MSG=""

	log tmpl_awk "Start"

	while true ; do
		#	Parameter pruefen/setzen
		#
		[ -z ${BASENAME} ] && { ECODE=1; break; }

		[ -z ${INDATA} ] && { ECODE=2; break; }
		OUTDATA=${OUTDATA:-/dev/null}

                #       auszufuehrendes SQL File ermitteln
                #       wenn in der Konfiguration keine
                #       Datei angegeben ist, wird im SQLDIR
                #       nach ${MYDBTYPE}_${BASENAME}.sql
                #       gesucht
                #
                if [ -z ${CFGAWKFILE} ] ; then
                        [ -z {SQLDIR} ] && { ECODE=22; break; }
                        [ ! -d ${SQLDIR} ] && { ECODE=23; break; }

                        CFGAWKFILE=${SQLDIR}/${BASENAME}.awk
                        log runsqlfile "I: CFGAWKFILE=${CFGAWKFILE}"
                fi

		#
		#
		#INDATA=`echo $INFILE | sed s/'\ '/'\\ '/g`

                #       Statement ausfuehren
                #
                runawk "${CFGAWKFILE}" "${INDATA}" "${OUTDATA}" || { ECODE=3; break; }

                #
                break
        done

        case ${ECODE} in
                0) MSG="I: ok" ;;
                1) MSG="F: Variable BASENAME nicht gesetzt" ;;
                2) MSG="F: Variable INDATA nicht gesetzt" ;;
                3) MSG="F: Ausfuehrung AWK-Script" ;;
                *) MSG="F: unbekannter Fehler" ;;
        esac

        log tmpl_awk "${MSG}"
        log tmpl_awk "Ende mit Exitcode ${ECODE}"

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

        . ${LIBDIR}/libprotokoll.ksh || { EXITCODE=2; break; }
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
	initprotokoll || { EXITCODE=15; break; }
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
	tmpl_awk || { EXITCODE=10; break; }

	#
	break
done

[ ${EXITCODE} -ne 5 ] && runcontrol FINISH
finishprotokoll ${EXITCODE} || { EXITCODE=16; break; }

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
	10) MSG="F: tmpl_awk fehlgeschlagen" ;;
	15) MSG="F: initprotokoll fehlgeschlagen" ;;
	16) MSG="F: finishprotokoll fehlgeschlagen" ;;
	99) MSG="F: Kein PID File bei laufendem Job" ;;
	*) MSG="F: unbekannter Fehler" ;;
esac

log Main "${MSG}"
[ ${NOLOG:-0} -eq 1 ] && [ ! -z ${LOGFILE} ] && [ -f ${LOGFILE} ] && rm ${LOGFILE} 2>/dev/null
exit ${EXITCODE}
