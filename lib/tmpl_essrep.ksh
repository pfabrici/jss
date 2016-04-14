#!/bin/ksh
################################################################################
#
#	tmpl_essrep
#
#	- BESCHREIBUNG
#
#	Template Skript fuer die Benutzung der Funktion 
#	runessrep aus der libolap Bibliothek.
#
#       Parameter:
#               siehe usage Funktion
#
#       Konfigurationsparameter
#               uebergebbar ueber Kommandozeile, Konfigurationsdatei
#               auch globale Konfigurationsdatei
#               oder als uebergeordnete globale Variable.
#
#		CFGESSREPFILE
#		ESSDATAFILE
#
#       Fehlercodes:
#		1) Einbindung liballg.ksh
#		2) Einbindung libolap.ksh
#		30) Einlesen lokale Konfiguration
#		31) Einlesen INFILE
#		4) Parsen Kommandozeile
#		5) Job laeuft schon
#		10) tmpl_essrep fehlgeschlagen
#		20) Einbindung libprotokoll.ksh
#		21) initprotokoll fehlgeschlagen
#		22) finishprotokoll fehlgeschlagen
#
#       - TODO
#
#       - HISTORIE
#
#		P.Fabricius	23.10.2006	Erstellung
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
	echo "fuehrt ESSBASE Report-Skripte aus"
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
#	tmpl_essrep
#
################################################################################
tmpl_essrep()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
	typeset MSG=""

	log tmpl_essrep "Start"

	while true ; do
		#
		#
		[ -z ${CFGESSREPFILE} ] && { ECODE=5; break; }
		[ -z ${ESSDATAFILE} ] && { ECODE=6; break; }

                #       ausfuehren
                #
		runessrep ${CFGESSREPFILE} ${ESSDATAFILE} || { ECODE=20; break; }

                #
                break
        done

        case ${ECODE} in
                0) MSG="I: ok" ;;
                5) MSG="F: CFGESSREPFILE nicht gesetzt" ;;
                6) MSG="F: ESSDATAFILE nicht gesetzt" ;;
                20) MSG="F: ESSCMD Ausfuehrung" ;;
                *) MSG="F: unbekannter Fehler" ;;
        esac

        log tmpl_essrep "${MSG}"
        log tmpl_essrep "Ende mit Exitcode ${ECODE}"

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
	tmpl_essrep || { EXITCODE=10; break; }

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
	10) MSG="F: tmpl_essrep fehlgeschlagen" ;;
        20) MSG="F: Einbindung libprotokoll.ksh" ;;
        21) MSG="F: initprotokoll fehlgeschlagen" ;;
        22) MSG="F: finishprotokoll fehlgeschlagen" ;;
	*) MSG="F: unbekannter Fehler" ;;
esac

log Main "${MSG}"
[ ${NOLOG:-0} -eq 1 ] && [ ! -z ${LOGFILE} ] && [ -f ${LOGFILE} ] && rm ${LOGFILE} 2>/dev/null
exit ${EXITCODE}
