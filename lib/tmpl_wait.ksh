#!/bin/ksh
################################################################################
#
#	tmpl_wait
#
#	- BESCHREIBUNG 
#
#	Ueber den Linknamen werden die erforderlichen Konfigurations
#	dateien ermittelt, die das weitere Vorgehen definnieren.
#	Weitere Informationen befinden sich im Header von liballg.ksh.
#
#       - TODO
#
#       - HISTORIE
#		T.Butenop	Erstellung
#	02.02.2010	P.Fabricius	siehe tmpl_wait	
#
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
	echo "Warten auf die erfolgreiche Beendigung eines Skripts"
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
#	tmpl_wait
#
#	Hinweis, PF 30.11.2007 :
#	Wenn MAXHOUR = 25, dann laeuft die Schleife endlos !
#	Das kann man verwenden, wenn mehr als ein Tag gewartet werden soll.
#	PF, 8.3.2010 : muss natuerlich 2500 sein
#
#	2.2.2010 	PF	Skript Output auch ausgeben,
#				wenn die Pruefung ok war. Dazu
#				die Variable RCODE eingefuehrt
#
################################################################################
tmpl_wait()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
	typeset MSG=""
	typeset RCNT RCODE

	log tmpl_wait "Start"

	while true ; do
		#	Parameter pruefen/setzen
		#
		[ -z ${BASENAME} ] && { ECODE=1; break; }
		[ -z ${SLEEPTIME} ] && { ECODE=5; break; }
		[ -z ${SCRIPT} ] && { ECODE=6; break; }
		[ -z ${MAXHOUR} ] && { ECODE=8; break; }

		#	Nun die Warteschleife
		#
		RCNT=0
		while true ; do
			RCNT=$(( RCNT + 1 ))
			log tmpl_wait "I: Durchlauf ${RCNT}"			

			[ `date '+%H%M'` -gt ${MAXHOUR} ] && { ECODE=9; break; }

			[ ! -x ${SCRIPT} ] && { ECODE=22; break; }
			RET=`${SCRIPT}`
			RCODE=$?

			log tmpl_wait "I: Skript-Output: ${RET}"
			[ ${RCODE} -eq 0 ] && break;

			log tmpl_wait "I: Schlafe jetzt ... "
			sleep ${SLEEPTIME}
		done

                #
                break
        done

        case ${ECODE} in
                0) MSG="I: ok" ;;
                1) MSG="F: Variable BASENAME nicht gesetzt" ;;
                5) MSG="F: Variable SLEEPTIME nicht gesetzt" ;;
                6) MSG="F: Variable SCRIPT nicht gesetzt" ;;
                8) MSG="F: Variable MAXHOUR nicht gesetzt" ;;
                9) MSG="F: Zeit ist abgelaufen "`date '+%H'` ;;
                22) MSG="F: Script nicht ausfuehrbar" ;;
                *) MSG="F: unbekannter Fehler" ;;
        esac

        log tmpl_wait "${MSG}"
        log tmpl_wait "Ende mit Exitcode ${ECODE}"

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
	tmpl_wait || { EXITCODE=10; break; }

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
