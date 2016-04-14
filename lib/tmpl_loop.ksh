#!/bin/ksh
################################################################################
#
#	tmpl_loop
#
#	- BESCHREIBUNG
#
#	Programm in einer Schleife abhaengig von den Eintraegen
#	in einer Datei starten.
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
#	tmpl_loop
#
#	Ein externes Programm CFGLOOPCMD so oft ausfuehren, wie es 
#	Eintraege in der Datei CFGLOOPFILE gibt.
#	Die durch CFGLOOPSEP getrennten Daten in dieser
#	Datei werden in Variablen mit den Bezeichungen
#	aus CFGLOOPHEADER gespeichert und dem externen Programm
#	zur Verfuegung gestellt.
#	Das externe Programm CFGLOOPCMD muss unter BINDIR oder
#	in seinen Unterverzeichnissen abgelegt sein.
#
#
#
#	Historie:
#	15.6.2005	PF	Erstellung
#	14.3.2006	PF	Ausgabe des echo vor grep unterdrueckt
#
################################################################################
tmpl_loop()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
	typeset -i LOOPCNT=0
	typeset -i LOOPMARKER=0
	typeset MSG=""
	typeset LOOPLINE OLDIFS CMD CMDTS
	typeset LOOPMARKERFILE

	log tmpl_loop "Start"

	while true ; do
		#	Parameter pruefen/setzen
		#
		[ -z ${BASENAME} ] && { ECODE=1; break; }

		[ -z ${CFGLOOPFILE} ] && { ECODE=3; break; }
		[ ! -f ${CFGLOOPFILE} ] && { ECODE=4; break; }
		# bei leerem Loopfile abbrechen
		#
		[ ! -s ${CFGLOOPFILE} ] && { ECODE=0; break; }


		[ -z ${CFGLOOPCMD} ] && { ECODE=5; break; }
		[ -z ${CFGLOOPHEADER} ] && { ECODE=6; break; }
		[ -z ${CFGLOOPSEP} ] && { ECODE=7; break; }

		CMDTS="typeset -x $CFGLOOPHEADER"
		eval $CMDTS

		LOOPMARKERFILE=${TMPDIR}/${BASENAME}.loop
		[ -f ${LOOPMARKERFILE} ] && LOOPMARKER=`cat ${LOOPMARKERFILE}`

		while read LOOPLINE ; do
			log tmpl_loop "I: LOOPLINE = ${LOOPLINE}"

			#	Zaehler beruecksichtigen
			#	Wenn Teilschritt schon ausgefuehrt
			#	wurde wird er uebersprungen
			#
			LOOPCNT=$(( LOOPCNT + 1 ))
			if [ ${LOOPCNT} -le ${LOOPMARKER} ] ; then
				log tmpl_loop "I: Skip"
				continue
			fi

			#	Daten aus dem Loopfile
			#	in Variablen schreiben
			#	
			IFS=${CFGLOOPSEP}

			# 	Wenn Loopline eine variable
			# 	enthaelt, dann single quotes verwenden
			#	sonst double quotes
			echo "${LOOPLINE}" | grep '\$' >/dev/null 2>&1
			if [ $? -eq 0 ] ; then
				CMD="echo '$LOOPLINE' | read ${CFGLOOPHEADER}"
			else
				CMD="echo \"$LOOPLINE\" | read ${CFGLOOPHEADER}"
			fi

			log tmpl_loop "I: CMD = ${CMD} "
			eval "$CMD" || { IFS=$OLDIFS; ECODE=10; break; }
			IFS=${OLDIFS}

			#	externes Programm ausfuehren
			#
			log tmpl_loop "I: CMD=${BINDIR}/${CFGLOOPCMD}"
			( ksh ${BINDIR}/${CFGLOOPCMD} ) || { ECODE=33; break; }

			#	wenn alles ok ist, LOOPMARKER
			#	hochsetzen
			#
			echo ${LOOPCNT} > ${LOOPMARKERFILE}

		done < ${CFGLOOPFILE}

                #
                break
        done
		
	( [ ${ECODE} -eq 0 ] && [ ! -z ${LOOPMARKERFILE} ] ) && rm ${LOOPMARKERFILE} 2>/dev/null

        case ${ECODE} in
                0) MSG="I: ok" ;;
                1) MSG="F: Variable BASENAME nicht gesetzt" ;;
                3) MSG="F: Variable CFGLOOPFILE nicht gesetzt" ;;
                4) MSG="F: Datei CFGLOOPFILE nicht vorhanden" ;;
                5) MSG="F: Variable CFGLOOPCMD nicht gesetzt" ;;
                6) MSG="F: Variable CFGLOOPHEADER nicht gesetzt" ;;
                7) MSG="F: Variable CFGLOOPSEP nicht gesetzt" ;;
                10) MSG="F: Eval fehlgeschlagen" ;;
                33) MSG="F: Fehler bei Loopausfuehrung" ;;
                *) MSG="F: unbekannter Fehler" ;;
        esac

        log tmpl_loop "${MSG}"
        log tmpl_loop "Ende mit Exitcode ${ECODE}"

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
	if [ -f ${LOCALCFGFILE} ] ; then
		readvarfile ${LOCALCFGFILE} || { EXITCODE=30; break; }
	fi

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
	tmpl_loop || { EXITCODE=10; break; }

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
	8) MSG="F: timerinit" ;;
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
