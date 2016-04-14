#!/bin/ksh
################################################################################
#
#	tmpl_esscmd
#
#	- BESCHREIBUNG
#
#	Templateskript fuer die Ausfuehrung von ESSBASE Skripten
#	mit Hilfe des Kommandozeilenfrontends ESSCMD.
#	Dieses Skript wird i.d.R. nicht direkt aufgerufen sondern
#	nur ueber Links.
#	Bislang ist keine Konfigurationsfunktion integriert
#	worden, wie sie z.B. bei tmpl_sqlfile vorhanden ost.
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
#		ESSPWD		Passwort ESSBASE Server
#		ESSUSER		Username ESSBASE Server
#		ESSDB		ESSBASE Datenbank
#		ESSAPP		ESSBASE Applikation
#		CFGESSFILE	ESSBASE Skript
#
#       Fehlercodes:
#               1) Einbindung liballg.ksh
#               2) Einbindung libdb.ksh
#               4) Parsen Kommandozeile
#               5) Job laeuft schon
#               10) tmpl_sqlfile fehlgeschlagen
#               20) Einbindung libprotokoll.ksh
#               21) initprotokoll fehlgeschlagen
#               22) finishprotokoll fehlgeschlagen
#               30) Einlesen lokale Konfiguration
#               31) Einlesen INFILE
#               99) Kein PID File bei laufendem Job
#
#       Autor:
#       Peter Fabricus, pfabricius@gmx.de
#
#       - TODO
#
#       - HISTORIE
#
#		P.Fabricius	18.10.2006	Erstellung
#
################################################################################

################################################################################
#
#	usage
#
#       Gibt eine usage Meldung aus, wenn das Skript
#       mit falscher Syntax aufgerufen wurde.
#
#       Parameter:
#               keine
#
#       Fehlercodes:
#               keine
#
#       Historie:
#               P.Fabricius     18.10.2006	Erstellung
#
################################################################################
usage()
{
        echo "Shell-Tool ${BASENAME}"
	echo "fuehrt ESSBASE ESSCMD Skripte aus"
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
#	tmpl_esscmd
#
#	Prueft, ob die Variable CFGESSFILE vorhanden ist und auf 
#	eine Datei verweist. Wenn alles ok ist wird die 
#	Funktion runesscmd der Biblitohek libolap aufgerufen.
#
#	Fehlercodes:
#		5) CFGESSFILE nicht gesetzt
#		7) CFGESSFILE nicht gefunden
#		20) ESSCMD Ausfuehrung
#
#	Historie:
#		P.Fabricius	18.10.2006	Erstellung
#
################################################################################
tmpl_esscmd()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
	typeset MSG=""

	log tmpl_esscmd "Start"

	while true ; do
		#
		#
		[ -z ${CFGESSFILE} ] && { ECODE=5; break; }
		[ ! -f ${CFGESSFILE} ] && { ECODE=7; break; }

                #       ausfuehren
                #
		runesscmd ${CFGESSFILE} || { ECODE=20; break; }

                #
                break
        done

        case ${ECODE} in
                0) MSG="I: ok" ;;
                5) MSG="F: CFGESSFILE nicht gesetzt" ;;
                7) MSG="F: CFGESSFILE nicht gefunden" ;;
                20) MSG="F: ESSCMD Ausfuehrung" ;;
                *) MSG="F: unbekannter Fehler" ;;
        esac

        log tmpl_esscmd "${MSG}"
        log tmpl_esscmd "Ende mit Exitcode ${ECODE}"

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

while [ 1 -eq 1 ] ; do

	#	Basiskonfiguration einlesen
	#
	. ~/.jssrc

	#	Allgemeine Bibliothek einbinden
	#	erst danach koennen Logeintraege geschrieben werden
	#
	. ${LIBDIR}/liballg.ksh || { EXITCODE=1; break; }
	log Main "I: liballg included"

        . ${LIBDIR}/libolap.ksh || { EXITCODE=2; break; }
        log Main "I: libolap included"

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
                [ -f ${INFILE} ] && rm ${INFILE}
        fi

	runcontrol INIT || { EXITCODE=5; break; }
	tmpl_esscmd || { EXITCODE=10; break; }

	#
	break
done

[ ${EXITCODE} -ne 5 ] && runcontrol FINISH
finishprotokoll ${EXITCODE} || { EXITCODE=22; break; }

case ${EXITCODE} in 
	0) MSG="I: ok" ;;
	1) MSG="F: Einbindung liballg.ksh" ;;
	2) MSG="F: Einbindung libolap.ksh" ;;
	30) MSG="F: Einlesen lokale Konfiguration" ;;
	31) MSG="F: Einlesen INFILE" ;;
	4) MSG="F: Parsen Kommandozeile" ;;
	5) MSG="F: Job laeuft schon" ;;
	10) MSG="F: tmpl_ftpcmd fehlgeschlagen" ;;
        20) MSG="F: Einbindung libprotokoll.ksh" ;;
        21) MSG="F: initprotokoll fehlgeschlagen" ;;
        22) MSG="F: finishprotokoll fehlgeschlagen" ;;
	*) MSG="F: unbekannter Fehler" ;;
esac

log Main "${MSG}"
[ ${NOLOG:-0} -eq 1 ] && [ ! -z ${LOGFILE} ] && [ -f ${LOGFILE} ] && rm ${LOGFILE} 2>/dev/null
exit ${EXITCODE}
