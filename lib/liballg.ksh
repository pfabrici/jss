#!/bin/ksh
################################################################################
#
#	liballg
#
#	- BESCHREIBUNG
#
#	Bibliothek mit allgemeinen Shellscriptfunktionen.
#	Bislang implementiert sind Funktionen fuer 
#
#		o Jobkontrolle
#			- Vermeidung von Parallellaeufen eines Jobs
#			- Aufteilung von Jobs in Jobketten mit
#			  mit erweiterten Restartfaehigkeiten
#			  ( z.B. Vermeidung von Wiederholungen von
#			  fehlerfrei gelaufenen Teilen der Jobkette )
#			- Logging
#		o Variablenbehandlung
#			- Parsen der Kommandozeilenparameter
#			- Lesen von Konfigurationsdateien
#			- Ersetzen von Variablen in Quelldateien
#		o Ausfuehren von Subscripten
#			- Shellscripte
#			- AWK Scripte
#			- ( SQL Scripte in libdb.ksh )
#			- ( SQLLDR Scripte in libdb.ksh )
#		o Allgemeine Funktionen
#			- Mailversand
#		o Zeitsteuerung
#			- Abbruch von Jobs nach definierter Zeit
#			( libtimer )
#		o dies und das ...
#
#	Die Bibliothek soll wenn moeglich nicht direkt verwendet werden 
#	sonder ueber Funktionstemplates. Diese Funktionstemplates
#	stellen jeweils einen der im DWH Umfeld haeufig vorkommenen
#	Funktionstypen dar und beinhalten die vollstaendige Implementierung
#	eines entsprechenden Scripts. 
#	In der praktischen Nutzung reicht ein
#	Link auf ein Funktionstemplate und evtl. eine Konfigurations-
#	datei sowie eine Funktionsdatei um einen Job zu erstellen.
#	Verfuegbar sind die folgenden Templates:
#
#		tmpl_sqlfile.ksh:	Erlaubt die Ausfuehrung eines
#					SQL Statements auf verschiedenen
#					Datenbanktypen. Benoetigt wird
#					ein Link auf das Template, eine
#					Konfigurationsdatei, die z.B.
#					den erfordelichen Datenbankconnect
#					enthaelt und eine Datei, die das
#					auszufuehrende SQL enthaelt.
#		tmpl_sqlldr.ksh:	Ausfuehrung des SQLLDR. Benoetigt
#					wird ein Link auf das Template,
#					Konfigurationsdatei ( s.o. )
#					und ein Controlfile.
#		tmpl_awk.ksh:		Ausfuehrung eines AWK Scripts
#		tmpl_ksh.ksh:		Erlaubt die Ausfuehrung eines 
#					Shellscripts in einer definierten
#					Umgebung ( Logfilehandling, Parameter 
#					etc. )
#					Erforderlich : Link, CFG Datei,
#					Shellscript
#		tmpl_perl.ksh:		Ausfuehrung eines Perl Skripts
#		tmpl_mail.ksh:		Mailversand
#		tmpl_chain.ksh:		Buendelung mehrerer Jobs zu
#					einer Kette
#		
#	Ablageorte:
#
#	Konfigurationsdateien 		./etc
#	Scriptdateien			./scr</...>
#	Links auf Templates		./bin</...>
#
#	- LIZENZ
#	
#	Copyright (C) 2005 Peter Fabricius
#
#	This program is free software; you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation; either version 2 of the License, or
#	(at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program; if not, write to the Free Software
#	Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#	- KONTAKT
#	pfabricius@gmx.de
#
#       - TODO
#
#       - HISTORIE
#
#		kann den jeweiligen Funktionen entnommen werden
#
################################################################################

################################################################################
#
#       isnull
#
#       Funktion ermittelt, ob eines der uebergebenen Argumente leer ist
#       und gibt als Resultat die Positionsnummer des ersten leeren
#       Arguments aus.
#       Bei einem Systemfehler der Funktion ( falsche Anzahl Parameter <1,
#       zu viele Parameter max 25 ) wird der Returncode 255 ausgeben.
#       Returncode 0, wenn alles ok, d.h. kein Wert ist leer.
#
#	Parameter:
#		* max 25 Parameter
#
#	Fehlercodes:
#		255 : Anzahl Parameter falsch
#		1 - 24 : Parameter mit der Nummer 1-24 ist leer
#		0 : ok
#
#	Historie:
#       	17.11.05        P.Fabricius     Erstellung
#
#
################################################################################
isnull()
{
        [ $# -lt 1 ] || [ $# -gt 25 ] && return 255
        typeset -i LOOP=1 RESULT=0
        while [ ${LOOP} -le ${#} ] ; do
                eval " [ -z \$${LOOP} ] && { RESULT=${LOOP}; break; } "
                LOOP=$(( LOOP + 1 ))
        done
        return ${RESULT}
}


################################################################################
#
#	isnumber
#
#	prueft, ob das uebergebene Argument eine Zahl ist oder nicht
#	indem versucht wird mit dem Wert zu rechnen. 
#
#	Parameter
#		Argument
#		
#	Fehlercodes
#		0 :	Argument ist Zahl
#		!0:	Argument ist keine Zahl
#
#	Historie:
#		20.6.06	P.Fabricius	Erstellung
#
################################################################################
isnumber() {
        typeset RES

        RES=`expr ${1} + 1 2>/dev/null `
        return $?
}

################################################################################
#
#	parseparms
#
#	Die Funktion parseparms wertet die Kommandozeilenparameter
#	aus und setzt die entsprechenden Shellvariablen zur Weiter-
#	verwendung im Skript.
#	Bislang werden die Parameter
#		-d ( DEBUG an/aus )
#		-s ( SILENT an/aus )
#		-n ( NOLOG an/aus )
#		-f ( FORCE an/aus )
#	unterstuetzt.
#
#	Parameter:
#		* unbegrenzte Anzahl Parameter der Form -n [wert]
#
#	Fehlercodes:
#		1	getopt fehlgeschlagen
#
#	Historie:
#		3.3.04	P.Fabricius	Erstellung
#		1.9.05	P.Fabricius	NOLOG eingefuehrt
#		15.11.05 P.Fabricius	INFILE Mechanismus 
#		10.1.06	P.Fabricius	xargs aus INFILEMech raus.
#		7.2.06	P.Fabricius	getopts statt getopt wg. 
#					Blanks in Parametern
#		20.4.06	P.Fabricius	FORCE eingefuehrt
#
################################################################################
parseparms()
{
        [ ${DEBUG:-0} -eq 1 ] && set -x
        typeset -i ECODE=0
        typeset MSG OPTARG OPTIND

        log parseparms "I: Start"

        while true ; do
                #       Keine Parameter -> Abbruch ok
                #
                [ $# -eq 0 ] && { ECODE=0; break; }

                log parseparms "I: $*"

                [ -f ${TMPDIR}/jss_${BASENAME}.infile ] && rm ${TMPDIR}/jss_${BASENAME}.infile
		INFILE=${TMPDIR}/jss_${BASENAME}.infile

		while getopts dsnfv: i ; do
			log parseparms "I: $i ${OPTARG}"
                        case $i in
                                d) DEBUG=1 ;;
                                s) SILENT=1 ;;
                                n) NOLOG=1 ;;
				f) FORCE=1 ;;
                                v) echo "${OPTARG}" >> ${INFILE} ;;
                        esac
                done

		[ ! -z ${OPTIND} ] && shift `expr ${OPTIND} - 1` >/dev/null 2>&1

                #
                break
        done

        case ${ECODE} in
                0) MSG="I: ok" ;;
                1) MSG="F: getopt fehlgeschlagen" ;;
                *) MSG="F: unbekannter Fehler" ;;
        esac

        log parseparms ${MSG}
        return ${ECODE}
}


################################################################################
#
#	runcontrol
#
#	Mit der Funktion runcontrol kann gesteuert werden, wie sich
#	ein Script verhaelt, wenn es bereits laeuft. Mit Hilfe einer 
#	PID Datei wird signalisiert, dass der Prozess schon laeuft.
#	Der Prozess kann dann nicht noch einmal gestartet werden.
#	Wird eine PID Datei erkannt wird zunaechst mit ps geprueft, 
#	ob der Prozess noch laueft.
#
#	Parameter:
#		MODE	Moegliche Werte sind INIT und FINISH
#			INIT wird zum setzen/pruefen der PID Datei
#			verwendet, FINISH zum Zuruecksetzen 
#
#	globale Variablen:
#		SYSTMPDIR
#	
#	Fehlercodes:
#		1)      F: Anzahl Parameter
#		2)      F: SYSTMPFILE nicht gesetzt
#		3)      F: Modus MODE unbekannt
#		4)      F: Prozess laeuft schon bei INIT
#		5)      F: kein PIDFILE bei FINISH
#
#	Comments:
#	
#	Wenn PID file da ist, pruefen
#	ob es einen Prozess mit dieser PID
#	gibt. Wenn ja beenden mit Fehler 4
#	sonst neues PIDfile erstellen und
#	weitermachen
#
#	Historie:
#		8.4.04	P.Fabricius	Erstellung
#		11.9.08	P.Fabricius	Umlenkung bei grepcat nach dev/null
#					da sonst die Prozess-ID des schon/noch
#					laufenden Job auf die Konsole ausgegeben
#					wird.
#
################################################################################
runcontrol()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
	typeset MSG PIDFILE MODE 

	log runcontrol "I: Start"

	while true ; do
		#	Ist Option NORUNCONTROL an ?
		# 	default ist die Verwendung von runcontrol
		#
		[ ! -z ${NORUNCONTROL} ] && { ECODE=0; break; }

		#	Parameter pruefen
		#
		[ $# -ne 1 ] && { ECODE=1; break; }
		MODE=$1
		log runcontrol "I: MODE=${MODE}"

		[ -z ${TMPDIR} ] && { ECODE=2; break; }

		PIDFILE=${TMPDIR}/jss_${BASENAME}.pid
		log runcontrol "I: PIDFILE=${PIDFILE}"

		case ${MODE} in 
			"INIT")
				[[ -f ${PIDFILE} ]] && {
					ps -ef -o pid | grep -v grep | \
						grep `cat ${PIDFILE}` >/dev/null 2>&1
					[ $? -eq 0 ] && { ECODE=4; break; }
				}
				echo $$ > ${PIDFILE}
				;;
			"FINISH")
				[ ! -f ${PIDFILE} ] && { ECODE=5; break; }
				rm ${PIDFILE}
				;;
			*)	ECODE=3 ;;
		esac

		#
		break
	done

	case ${ECODE} in
		0)      MSG="I: ok" ;;
		1)      MSG="F: Anzahl Parameter" ;;
		2)      MSG="F: SYSTMPDIR nicht gesetzt" ;;
		3)      MSG="F: Modus MODE unbekannt" ;;
		4)      MSG="F: Prozess laeuft schon bei INIT" ;;
		5)      MSG="F: kein PIDFILE bei FINISH" ;;
		*)      MSG="F: unbekannter Fehler" ;;
	esac

	log runcontrol ${MSG}
	return ${ECODE}
}

################################################################################
#
#	backupenv
#
#	Die Shell kennt nur globale Variablen. Werden durch die 
#	Schachtelung von Funktionen/Skripten Variablen ueberschrieben,
#	kann nicht mehr auf die urspruenglichen Werte zurueckge-
#	griffen werden.
#	Damit ist in dieser Umgebung die Schachtelung von Chains, 
#	Loops etc. eigentlich nicht moeglich.
#	Die Funktion backupenv sichert die Umgebung in eine
#	Datei, restoreenv liest sie wieder ein, so dass der 
#	Ausgangszustand wiederhergestellt werden kann.
#	Damit werden lokale Variablen innerhalb eines
#	Framework Jobs simuliert
#	
#	Historie:
#		27.9.2005	P.Fabricius	Erstellung
#		09.1.2008	P.Fabricius	Damit das neue readvarfile
#						funktioniert muessen hier
#						die Values in Quotes 
#						abgelegt werden.
#		25.9.2008	P.Fabricius	-r bei read, environment
#						soll ja nicht veraendert werden.
#						Ist noch nicht der Weisheit letzter
#						Schluss
#		26.9.2008	P.Fabricius	Mehrzeilige Variableninhalte
#						passieren die while read
#						Schleife nicht - es wird
#						bei jeder zeile des Variablen-
#						inhalts versucht eine neue
#						Zuweisung in das ENVFILE
#						zu schreiben. Das fuehrt beim
#						restoreenv dann zu Fehlern-
#						Der if im while verlaengert
#						nun den VAL, wenn keine 
#						neue Zuordnung erscheint.
#
################################################################################
backupenv()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
	typeset MSG ENVFILE MODE 

	log backupenv "I: Start"

	while true ; do
		#	
		ENVFILE=${TMPDIR}/jss_${BASENAME}_$$.env

		[ -f ${ENVFILE} ] && rm ${ENVFILE}

		env | while read -r LINE ; do
			# ist die aktuelle Zeile eine Zuordnung ?
			#
			echo "${LINE}" | grep "=" >/dev/null  2>&1
			if [ $? -eq 0 ] ; then
				# ja, ist eine Zuordnung.
				# Wenn noch eine alte Zuordnung 
				# aus dem letzten Schleifendurchlauf im Puffer ist
				# wird die erstmal ausgegeben
				# Nur echte Zuweisungen mit KEY!=NULL
				# EXITCODE wird durchgereicht !!!
				#
				[ "X${KEY}" != "XEXITCODE" -a "X${KEY}" != "X" ] && \
					echo "${KEY}=\"${VAL%%\"}\"" >> ${ENVFILE}

				# Nun die neue Zuordnung bearbeiten
				# nur Zeile 1 ist interessant fuer den KEY
				#
				KEY=`echo $LINE | head -1 | cut -f1 -d'='`
				VAL=`echo $LINE | cut -f2-1000 -d'='`

				# eine evtl. Quotierung entfernen ( hinten )
				# da sie bei der Ausgabe wieder hinzugefuegt wird.
				# So bekommen auch die unquotierten Zuordnungen
				# eine Quotierung - alles klar ?
				# aus A=12 wird A="12"
				# und A="12" bleibt A="12"
				#
				VAL=${VAL##\"}
			fi

		done

		# den Puffer noch rausschreiben, dabei die vordere
		# Quotierung beachten.
		#
		[ "X${KEY}" != "XEXITCODE" -a "X${KEY}" != "X" ] && \
                        echo "${KEY}=\"${VAL%%\"}\"" >> ${ENVFILE}

		#
		break
	done

	case ${ECODE} in
		0)      MSG="I: ok" ;;
		*)      MSG="F: unbekannter Fehler" ;;
	esac

	log backupenv ${MSG}
}

################################################################################
#
#	restoreenv
#
#	Die Shell kennt nur globale Variablen. Werden durch die 
#	Schachtelung von Funktionen/Skripten Variablen ueberschrieben,
#	kann nicht mehr auf die urspruenglichen Werte zurueckge-
#	griffen werden.
#	Damit ist in dieser Umgebung die Schachtelung von Chains, 
#	Loops etc. eigentlich nicht moeglich.
#	Die Funktion backupenv sichert die Umgebung in eine
#	Datei, restoreenv liest sie wieder ein, so dass der 
#	Ausgangszustand wiederhergestellt werden kann.
#	
#	Historie:
#		27.9.2005	P.Fabricius	Erstellung
#
################################################################################
restoreenv()
{
        [ ${DEBUG:-0} -eq 1 ] && set -x
        typeset -i ECODE=0
        typeset MSG ENVFILE MODE

        log restoreenv "I: Start"

        while true ; do
			#	
			readvarfile ${TMPDIR}/jss_${BASENAME}_$$.env || { ECODE=1; break; }
			rm ${TMPDIR}/jss_${BASENAME}_$$.env

			#
			break
        done

        case ${ECODE} in
			0) MSG="I: ok" ;;
			1) MSG="F: Fehler bei readvarfile" ;;
			*) MSG="F: unbekannter Fehler" ;;
        esac

        log restoreenv ${MSG}
}

################################################################################
#
#	log
#
#	Die Funktion log stellt ein erweitertes Logfilehandling zur Verfuegung
#	Ist kein Logfilename in der Variablen LOGFILE gesetzt, wird
#	wird zunaechst eine temporaere Datei angelegt, in der die
#	Logfileeintraege gespeichert werden. Wird im Verlauf des Scripts 
#	ein Logfilename gesetzt, wird der Inhalt des Tempfiles in das
#	Logfile mit dem korrekten Namen kopiert und die temporaere Datei
#	geloescht.
#	Existierende Logfiles mit gleichem Namen werden nicht ueberschrieben
#	sondern in eine Datei mit dem Namen des Logfiles um eine
#	laufende Nummer ergaenzt umkopiert.
#
#	Parameter:
#		MODULE	Name der aufrufenden Funktion
#		MSG	Logtext
#
#	globale Variablen:
#		LOGFILE
#		SILENT
#	
#	Fehlercodes:
#
#	Comments:
#	Wenn kein Logfile angegeben ist ein temporaeres anlegen.
#	Wird spaeter ein anderer Logfilename gesetzt,
#	Inhalt von TMPLOGFILE ins Logfile umkopieren und
#	temporaeres Logfile loeschen
#	evtl. bestehendes altes Logfile unter anderem Namen sichern
#	Wenn temp. Logfile vorhanden ist Inhalt nach
#	Logfile kopieren und temp. Logfile loeschen
#
#	Der "ksh -n " Syntax Error bei "* 1" scheint keine Auswirkung
#	auf das Laufzeitverhalten zu haben ...
#
#	Historie:
#		8.4.04	P.Fabricius	Erstellung
#		12.5.05	PF		Spaghetticode wg. Tuning
#		11.8.05 PF		LOGOK eingefuehrt
#		6.3.07  PF		Ergebnis vom mv nach /dev/null schicken
#
################################################################################
log()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset MODULE MSG 

	MODULE=$1
	shift
	MSG=$*

	[ ${NOLOG:-0} -eq 1 ] && return 0

	[ ${LOGOK} -eq 1 ] && {
		[ ${SILENT:-0} -eq 0 ] && echo `date '+%Y-%m-%d %T'`" [${MODULE}] ${MSG}" | tee -a ${LOGFILE} || date "+%Y-%m-%d %T [${MODULE}] ${MSG}" >> ${LOGFILE}
		return 0
	}

	[ -z ${LOGFILE} ] && {
		LOGFILE=/tmp/tmp-${BASENAME}-$$.log
		TMPLOGFILE=${LOGFILE}
	} || {
		[ "X${TMPLOGFILE}" != "X${LOGFILE}" ] && {
			[[ -f ${LOGFILE} ]] && \
			mv ${LOGFILE} ${LOGFILE}_$(( `ls -1 ${LOGFILE}* 2>/dev/null | wc -l` * 1 )) 2>/dev/null
	
			[ ! -z ${TMPLOGFILE} ] && [ -f ${TMPLOGFILE} ] && \
				cat ${TMPLOGFILE} > ${LOGFILE} && rm ${TMPLOGFILE}
				TMPLOGFILE=${LOGFILE}
		}
		LOGOK=1
	}

	[ ${SILENT:-0} -eq 0 ] && echo `date '+%Y-%m-%d %T'`" [${MODULE}] ${MSG}" | tee -a ${LOGFILE} || date "+%Y-%m-%d %T [${MODULE}] ${MSG}" >> ${LOGFILE}

	return 0
}

################################################################################
#
#	readvarfile
#
#	Die Funktion liest eine Konfigurationsdatei zeilenweise aus
#	und stellt dem Skript die Wertezuweisungen in Form von
#	Shellvariablen zur Verfuegung.
#	Es werden nur Zuweisungen der Form KEY=VALUE beruecksichtigt.
#	Kommentare in der Datei sind zulaessig, wenn sie in der
#	ersten Spalte einer Zeile ein # Zeichen haben.
#	Leerzeilen werden ignoriert.
#	Beinhaltet die Konfigurationsdatei Eintraege der Form
#	include <DATEI>
#	werden die entsprechenden Dateien ebenfalls eingelesen.
#	Diese Funktionalitaet ist vorgesehen, um z.B. eine fixe
#	Konfiguration zur ermoeglichen, die durch eine variable
#	Datei an anderer Stelle ( z.B. durch einen anderen Job erzeugt )
#	ergaenzt wird.
#
#	Neues Vorgehen : zuvor war es so, dass erst alle Zuweisungen
#	einer Datei ausgewertet wurden und danach die includes
#	abgearbeitet wurden. Die Konfigurationsdatei ist also 
#	nicht in der richtigen Reihenfolge verarbeitet worden.
#	Das ist nun anders. Es wird eine Zeile nach der anderen
#	verarbeitet und auch die includes werden an der richtigen
#	Stelle eingeschoben. Dazu ist allerdings eine rekursive
#	Abarbeitung notwendig. Die Funktion kann dabei nicht mehr
#	ganz so uebersichtich gestaltet bleiben.
#	
#	Parameter:
#		VARFILE	Pfad zur auszuwertenden Datei
#
#	globale Variablen:
#	
#	Fehlercodes:
#		1)      F: Anzahl Parameter
#		2)      F: VARFILE nicht lesbar
#		3)      F: eval fehlgeschlagen
#
#	Historie:
#		8.4.04	P.Fabricius	Erstellung
#		22.8.05	P.Fabricius	VARFILELIST
#		30.8.05 P.Fabricius	Reihenfolge der Abarbeitung
#					von INCLUDE Files veraendert
#					Jetzt : includes zuerst
#		27.9.05 P.Fabricius	VALUE immer in Anfuehrungs-
#					zeichen
#		26.9.06	P.Fabricius	include kann nun inline
#					Funktionen beinhalten.
#		11.12.07 P.Fabricius	rekursives Handling
#		03.01.08 P.Fabricius	Vorgehen mit temp. Datei
#					eingefuehrt
#		09.01.08 P.Fabricius	-r Option bei while, damit
#					keine Steuerungszeichen verloren gehen
#		24.01.08 P.Fabricius	double Quotes um Values drumherum
#					machen
#
#
################################################################################
readvarfile()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i DEPTH=$2
	typeset LOCALFILE=$1
	typeset -i MAXDEPTH=10
	typeset LINE CMD LOCFNAME CHKFNAME
	typeset -i ECODE=0

	[ $# -lt 1 ] && { log readvarfile "F: Anzahl Parameter"; return 1; }

	# Dieser IF Block ist beim Aufruf von aussen relevant.
	# Die Teile weiter unten werden nur beim rekursiven Aufruf
	# verwendet
	#
	if [ ${DEPTH:-0} -eq 0 ] ; then
		log readvarfile "I:Start, lese ${LOCALFILE}"

		while true ; do
			# temporaere Datei anlegen und Rekusion starten
			READVARTMPFILE=${TMPDIR}/readvar_$$.tmp
			> ${READVARTMPFILE}
			readvarfile ${LOCALFILE} 1 ${READVARTMPFILE} || \
				{ ECODE=$?; break; }

			# Ergebnis der rekursiven Befuellung des Tempfiles
			# auswerten
			while read -r PIPELINE ; do
				eval "${PIPELINE}" || { ECODE=3; break; }
			done < ${READVARTMPFILE}

			# Tempfile aufraeumen
			[ ! -z ${READVARTMPFILE} ] && [ -f ${READVARTMPFILE} ] && \
				rm ${READVARTMPFILE}
			#
			break
		done
	else
		READVARTMPFILE=$3
		while true ; do
			[ ${DEPTH} -gt ${MAXDEPTH} ] && { ECODE=4; break; }
			[ ! -f ${LOCALFILE} ] && \
				{ log readvarfile "F: ${LOCALFILE}"; ECODE=2; break; }

			while read -r LINE ; do
				# leer und Kommentarzeilen ignorieren, nur
				# Zuweisungen beruecksichtigen
				echo $LINE | egrep "^#|^ |^     " >/dev/null 2>&1 && continue

				# habe ich einen include - Befehl ?
				# Wenn ja, gleich den Dateinamen ermitteln
				#
				LOCFNAME=`echo $LINE | \
					grep "^include" | \
					sed s/'^include[      ]*'// `

				if [ ! -z ${LOCFNAME} ] ; then
					# wenn es ein include Befehl ist muss
					# die naechste Rekusion gestartet werden
					CHKFNAME=`eval "echo ${LOCFNAME}"`
					[ -z ${CHKFNAME} ] && return 5
					readvarfile ${CHKFNAME} \
						$(( DEPTH + 1 )) \
						${READVARTMPFILE} || return $?
				else
					# es werden nur Zuweisungen behandelt !
					echo $LINE | grep "=" >/dev/null 2>&1 || continue

					# Wenn es sich um eine gueltige
					# Zuweisung ( KEY ist nicht leer ) 
					# handelt wird die Zeile in die tempDatei
					# ausgegeben
					[ -z `echo $LINE | cut -f 1 -d '='` ] && continue
					# Wenn der VALUE nicht in doublequotes
					# steht mache ich welche drumherum !
					printf "%s" "${LINE}" | grep "\"" >/dev/null 2>&1 || {
					LINE=`echo $LINE | cut -f 1 -d '='`"=\""`echo $LINE | cut -f 2 -d '='`"\""
					}
					log readvarfile "I: $LINE"
					printf "export %s\n" "${LINE}" >> ${READVARTMPFILE}
				fi

				done < ${LOCALFILE}
			#
			break
		done

	fi

	case ${ECODE} in
		0) MSG="I: ok" ;;
		2) MSG="F: Konfiguration nicht lesbar" ;;
		3) MSG="F: eval fehlgeschlagen" ;;
		4) MSG="F: maximale include Tiefe ueberschritten" ;;
		5) MSG="F: eval auf include Filenamenausdruck liefert nichts" ;;
		*) MSG="F: unbekannter Fehler" ;;
	esac

	[ ${DEPTH} -eq 0 ] && log readvarfile "${MSG}"

	return ${ECODE}
}

################################################################################
#
#	exchangevars
#
#	Die Funktion exchangevars ersetzt Strings der Form __VARNAME__ aus
#	der Ursprungsdatei durch die entsprechenden Werte ${VARNAME}
#	und schreibt das Ergebnis in die Datei TGT.
#
#	TODO:
#		Pruefung, ob alle Werte ersetzt wurden
#	
#	Parameter:
#		SRC	Ursprungsdatei
#		TGT	Zieldatei
#
#	globale Variablen:
#	
#	Fehlercodes:
#		1)      F: Anzahl Parameter
#		2)      F: Datei SRC nicht vorhanen
#		3)      F: Herstellung  CMD
#		4)      F: eval
#
#	Historie:
#		14.2.03	P.Fabricius	Erstellung
#		10.3.05	P.Fabricius	Integration liballg
#
################################################################################
exchangevars() {
        [ ${DEBUG:-0} -eq 1 ] && set -x
        typeset -i ECODE=0
        typeset MSG CMD DELIM A B
        typeset DELIM="§"

        log exchangevars "I: Start"

        while true ; do
                #      Parameter pruefen und setzen
                #
                log exchangevars "I: Parameter pruefen"
                [ $# -ne 2 ] && { ECODE=1; break; }
                SRC=$1
		log exchangevars "I: SRC=${SRC}"
                TGT=$2
		log exchangevars "I: TGT=${TGT}"

                [ ! -f ${SRC} ] && { ECODE=2; break; }

		#	muss ueberhaupt etwas ersetzt werden ?
		# 	wenn nicht, dann Funktion abbrechen
		#
		grep "__.*__" ${SRC} >/dev/null 2>&1 || { cat ${SRC} > ${TGT}; break; } 

		#	das benoetigte sed Kommando dynamisch
		#	erstellen
		#
                log exchangevars "I: CMD erstellen"

		A=`sed  "s/\(__\)\([^_]*\)\(__\)/${DELIM} s\!__\2__\!\$\{\2\}\!g ${DELIM}\n/g" $SRC | tr "${DELIM}" '\n' | grep "__.*__" | sort -u`

		log exchangevars "I: A=${A}"
		B=`eval 'echo ${A}"' | sed s/\!g\ s\!/\!g\;\ s\!/g`
		CMD="sed -e \"${B}\" ${SRC}"

		echo "${CMD}" >>${LOGFILE} 2>/dev/null

                log exchangevars "I: CMD ausfuehren"
                eval "${CMD}" > ${TGT} || { ECODE=4; break; }

                #       und Schleife beenden
                #
                break;
        done

        case ${ECODE} in
		0)      MSG="I: ok"                          ;;
		1)      MSG="F: Anzahl Parameter"          ;;
		2)      MSG="F: Datei SRC nicht vorhanen " ;;
		3)      MSG="F: Herstellung  CMD "         ;;
		4)      MSG="F: eval "                     ;;
		*)      MSG="F: unbekannter Fehler"        ;;
        esac

        log exchangevars ${MSG}
        return ${ECODE}
}

################################################################################
#
#	runshellscript
#
#	Die Funktion fuehrt ein Shellscript aus. Zuvor werden
#	Platzhalter der Form __VAR__ im Source des Scripts 
#	durch die Werte in den entsprechenden
#	Variablen ersetzt.
#	Diese Funktion wird vom Funktionstemplate tmpl_ksh.ksh
#	verwendet.
#	
#	Parameter:
#		SRC	Quelle des auszufuehrenden Shellscripts
#
#	globale Variablen:
#	
#	Fehlercodes:
#		0)      ok
#		1)      Anzahl Parameter
#		24)  	Variable TMPDIR nicht gesetzt
#		25)  	TMPDIR ist kein Verzeichnis
#		30)	SRC nicht vorhanden
#		31)  	liballg nicht eingebunden
#		32)  	exchangevars fehlgeschlagen
#		40)	Ausfuehrung fehlgeschlagen
#
#	Historie:
#		28.6.04	P.Fabricius	Erstellung
#
#
################################################################################
runshellscript()
{
        [ ${DEBUG:-0} -eq 1 ] && set -x
        typeset -i ECODE=0
        typeset MSG SCRIPTIDENT RUNSCRIPTTMPFILE TGT

        log runshellscript "I: Start"

        while true ; do
                #      Parameter pruefen und setzen
                #
		[ $# -ne 1 ] && { ECODE=1; break; }
		SRC=$1
		[ ! -f ${SRC} ] && { ECODE=30; break; }
		log runshellscript "I: SRC=${SRC}"
	
                [ -z {TMPDIR} ] && { ECODE=24; break; }
                [ ! -d ${TMPDIR} ] && { ECODE=25; break; }

                RUNSCRIPTTMPFILE=${TMPDIR}/runscr_${SCRIPTIDENT}_$$.ksh

                #       Variablen ersetzen
                #
                type exchangevars >/dev/null 2>&1 || { ECODE=31; break; }
                exchangevars ${SRC} ${RUNSCRIPTTMPFILE} || { ECODE=32; break; }

                cat ${RUNSCRIPTTMPFILE} >>${LOGFILE:-/dev/null}

		log runshellscript "I: Skript nun starten"	
		#	und ausfuehren
		#
		( ksh ${RUNSCRIPTTMPFILE} ) >>${LOGFILE:-/dev/null} 2>&1
		[ $? -ne 0 ] && { ECODE=40; break; }

                #       und Schleife beenden
                #
                break;
        done

	[ ! -z ${RUNSCRIPTTMPFILE} ] && [ -f ${RUNSCRIPTTMPFILE} ] && rm ${RUNSCRIPTTMPFILE}

        case ${ECODE} in
                0)      MSG="I: ok"                          ;;
                1)      MSG="F: Anzahl Parameter"          ;;
                24)  	MSG="F: Variable TMPDIR nicht gesetzt" ;;
                25)  	MSG="F: TMPDIR ist kein Verzeichnis" ;;
		30)	MSG="F: SRC nicht vorhanden" ;;
                31)  	MSG="F: liballg nicht eingebunden" ;;
                32)  	MSG="F: exchangevars fehlgeschlagen" ;;
		40)	MSG="F: Ausfuehrung fehlgeschlagen" ;;
                *)      MSG="F: unbekannter Fehler"        ;;
        esac

        log runshellscript ${MSG}
        return ${ECODE}
}

################################################################################
#
#	runawk
#
#	Die Funktion fuehrt ein awk-Script aus. Zuvor werden
#	Platzhalter der Form __VAR__ durch die Werte in den entsprechenden
#	Variablen ersetzt.
#	Diese Funktion wird vom Funktionstemplate tmpl_awk.ksh verwendet.
#
#	Parameter:
#		SCRIPTIDENT	Scriptfilebezeichner
#		INDATA		mit awk zu bearbeitende Datendatei
#		OUTDATA		( optional ) Ausgabedatei des awk
#
#	globale Variablen:
#	
#	Fehlercodes:
#		0)      ok
#		22)  	Variable SQLDIR nicht gesetzt
#		23)  	SQLDIR ist kein Verzeichnis
#		24)  	Variable TMPDIR nicht gesetzt
#		25)  	TMPDIR ist kein Verzeichnis
#		30)	SRC nicht vorhanden
#		31)  	liballg nicht eingebunden
#		32)  	exchangevars fehlgeschlagen
#		40)	Ausfuehrung awk fehlgeschlagen
#
#	Historie:
#		6.2.05	P.Fabricius	Erstellung
#		1.8.05	P.Fabricius	Name der awk- Datei wird
#					nicht mehr erstellt sondern aus
#					Umgebung uebernommen
#		21.8.06 P.Fabricius	Doublequotes um INDATA
#					bei Generierung des AWK-CMD
#
################################################################################
runawk()
{
        [ ${DEBUG:-0} -eq 1 ] && set -x
        typeset -i ECODE=0
        typeset MSG SCRIPTIDENT RUNSCRIPTTMPFILE SRC INDATA OUTDATA
	typeset BASEFILE

        log runawk "I: Start"

        while true ; do
                #      Parameter pruefen und setzen
                #
		[ $# -lt 2  ] && { ECODE=1; break; }
		BASEFILE=$1
		log runawk "I: BASEFILE=${BASEFILE}"
		INDATA=$2
		log runawk "I: INDATA=${INDATA}"
		OUTDATA=${3:-/dev/null}
		log runawk "I: OUTDATA=${OUTDATA}"
	
                [ -z {SQLDIR} ] && { ECODE=22; break; }
                [ ! -d ${SQLDIR} ] && { ECODE=23; break; }

                [ -z {TMPDIR} ] && { ECODE=24; break; }
                [ ! -d ${TMPDIR} ] && { ECODE=25; break; }

                RUNSCRIPTTMPFILE=${TMPDIR}/runawk_${SCRIPTIDENT}_$$.awk

                #       Variablen ersetzen
                #
                type exchangevars >/dev/null 2>&1 || { ECODE=31; break; }
                exchangevars ${BASEFILE} ${RUNSCRIPTTMPFILE} || { ECODE=32; break; }

                cat ${RUNSCRIPTTMPFILE} >>${LOGFILE:-/dev/null}
	
		#	und ausfuehren
		#
		CMD="awk -f ${RUNSCRIPTTMPFILE} \"${INDATA}\" >${OUTDATA}"
		log runawk "I: CMD=${CMD}"
		eval ${CMD} 2>>${LOGFILE:-/dev/null} || { ECODE=40; break; }

                #
                break;
        done

	[ ! -z ${RUNSCRIPTTMPFILE} ] && [ -f ${RUNSCRIPTTMPFILE} ] && rm ${RUNSCRIPTTMPFILE}

        case ${ECODE} in
                0)      MSG="I: ok"                          ;;
                22)  	MSG="F: Variable SQLDIR nicht gesetzt" ;;
                23)  	MSG="F: SQLDIR ist kein Verzeichnis" ;;
                24)  	MSG="F: Variable TMPDIR nicht gesetzt" ;;
                25)  	MSG="F: TMPDIR ist kein Verzeichnis" ;;
		30)	MSG="F: SRC nicht vorhanden" ;;
                31)  	MSG="F: liballg nicht eingebunden" ;;
                32)  	MSG="F: runawk fehlgeschlagen" ;;
		40)	MSG="F: Ausfuehrung awk fehlgeschlagen" ;;
                *)      MSG="F: unbekannter Fehler"        ;;
        esac

        log runawk ${MSG}
        return ${ECODE}
}

################################################################################
#
#	runperl
#
#	Die Funktion fuehrt ein perl-Script aus. Zuvor werden
#	Platzhalter der Form __VAR__ durch die Werte in den entsprechenden
#	Variablen ersetzt.
#	Diese Funktion wird vom Funktionstemplate tmpl_perl.ksh verwendet.
#
#	Parameter:
#		SCRIPTIDENT	Scriptfilebezeichner
#		INDATA		mit awk zu bearbeitende Datendatei
#		OUTDATA		( optional ) Ausgabedatei des awk
#
#	globale Variablen:
#	
#	Fehlercodes:
#		0)      ok
#		22)  	Variable SQLDIR nicht gesetzt
#		23)  	SQLDIR ist kein Verzeichnis
#		24)  	Variable TMPDIR nicht gesetzt
#		25)  	TMPDIR ist kein Verzeichnis
#		30)	SRC nicht vorhanden
#		31)  	liballg nicht eingebunden
#		32)  	exchangevars fehlgeschlagen
#		40)	Ausfuehrung awk fehlgeschlagen
#
#	Historie:
#		10.7.06P.Fabricius	Erstellung
#
################################################################################
runperl()
{
        [ ${DEBUG:-0} -eq 1 ] && set -x
        typeset -i ECODE=0
        typeset MSG SCRIPTIDENT RUNSCRIPTTMPFILE SRC INDATA OUTDATA
	typeset BASEFILE

        log runperl "I: Start"

        while true ; do
                #      Parameter pruefen und setzen
                #
		[ $# -lt 2  ] && { ECODE=1; break; }
		BASEFILE=$1
		log runperl "I: BASEFILE=${BASEFILE}"
		INDATA=$2
		log runperl "I: INDATA=${INDATA}"
		OUTDATA=${3:-/dev/null}
		log runperl "I: OUTDATA=${OUTDATA}"
	
                [ -z {SQLDIR} ] && { ECODE=22; break; }
                [ ! -d ${SQLDIR} ] && { ECODE=23; break; }

                [ -z {TMPDIR} ] && { ECODE=24; break; }
                [ ! -d ${TMPDIR} ] && { ECODE=25; break; }

                RUNSCRIPTTMPFILE=${TMPDIR}/runperl_${SCRIPTIDENT}_$$.pl

                #       Variablen ersetzen
                #
                type exchangevars >/dev/null 2>&1 || { ECODE=31; break; }
                exchangevars ${BASEFILE} ${RUNSCRIPTTMPFILE} || { ECODE=32; break; }

                cat ${RUNSCRIPTTMPFILE} >>${LOGFILE:-/dev/null}
	
		#	und ausfuehren
		#
		CMD="perl -I${PERLINC} ${RUNSCRIPTTMPFILE} ${INDATA} >${OUTDATA}"
		log runperl "I: CMD=${CMD}"
		eval ${CMD} 2>>${LOGFILE:-/dev/null} || { ECODE=40; break; }

                #
                break;
        done

	[ ! -z ${RUNSCRIPTTMPFILE} ] && [ -f ${RUNSCRIPTTMPFILE} ] && rm ${RUNSCRIPTTMPFILE}

        case ${ECODE} in
                0)      MSG="I: ok"                          ;;
                22)  	MSG="F: Variable SQLDIR nicht gesetzt" ;;
                23)  	MSG="F: SQLDIR ist kein Verzeichnis" ;;
                24)  	MSG="F: Variable TMPDIR nicht gesetzt" ;;
                25)  	MSG="F: TMPDIR ist kein Verzeichnis" ;;
		30)	MSG="F: SRC nicht vorhanden" ;;
                31)  	MSG="F: liballg nicht eingebunden" ;;
                32)  	MSG="F: exchangevars fehlgeschlagen" ;;
		40)	MSG="F: Ausfuehrung awk fehlgeschlagen" ;;
                *)      MSG="F: unbekannter Fehler"        ;;
        esac

        log runperl ${MSG}
        return ${ECODE}
}
################################################################################
#
#	distrib
#
#	distrib stellt anhand von globalen Variablen, die in einer cfg
#	Datei gesetzt werden muessen eine Mail zusammen und schickt sie
#	mit mailx auf die Reise. Es koennen Anhaenge integriert werden.
#	Diese Funktion wird vom Funktionstemplate tmpl_mail.ksh
#	verwendet.
#	Anhaenge koennen auch gezippt und mit DOS Zeilenenden
#	versendet werden.
#
#	1.8.05	P.Fabricius	Variable MAILZIP eingefuehrt
#				-> auf Wunsch koennen Dateianhaenge auch
#				gezippt versendet werden.
#	8.11.05	P.Fabricius	zusaetzicher break, siehe 
#				Kommentar
#	23.2.07 P.Fabricius	Signatur aus Datei holen und einfuegen
#	12.4.07 P.Fabricius	Linuxfaehigkeit
#	20.11.08 P.Fabricius	Signature vor den Anhaengen in den 
#				Mailtext einfuegen
#	05.03.09 P.Fabricius	MAILZIP=2 verwendet zip statt gzip
#	18.7.11  P.Fabricius	GPG eingebaut
#
################################################################################
distrib()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
	typeset MSG RECIPIENT ENCLOSURE MAILTMPFILE DOSCMD
	typeset OSTYPE 

	log distrib "I: Start"

	while true ; do
		#      Parameter pruefen und setzen
		#
		[ $# -ne 0 ] && { ECODE=1; break; }

		[ -z ${RECIPIENTLIST} ] && { ECODE=2; break; }
		[ -z ${MAILSUBJECT} ] && { ECODE=3; break; }
		[ -z ${MAILTEXT} ] && { ECODE=4; break; }
		[ -z ${MAILFROM} ] && { ECODE=6; break; }
		[ -z ${MAILZIP} ] && MAILZIP=0
		[ -z ${DOSFMT} ] && DOSFMT=0
		[ -z ${DOGPG} ] && DOGPG=0

		OSTYPE=`uname`


		#	Maildatei erstellen
		#
		MAILTMPFILE=${TMPDIR}/distrib_$$.tmp

		if [ "X${OSTYPE}" == "XLinux" ] ; then
                	touch ${MAILTMPFILE}
        	else
			echo "From:${MAILFROM}" > ${MAILTMPFILE}
			for RECIPIENT in ${RECIPIENTLIST} ; do
				log distrib "I: Empfaenger ${RECIPIENT} ergaenzt"
				echo "To:${RECIPIENT}" >> ${MAILTMPFILE}
			done
			echo "Subject:${MAILSUBJECT}" >>${MAILTMPFILE}
		fi

		echo "${MAILTEXT}" >> ${MAILTMPFILE}

		# Eine Signatur anhaengen
		#
		# PF 20.11.2008	Signature vor den Anhaengen
		#
		if [ ${NOSIGNATURE:-0} -eq 0 ] ; then
			log distrib "I: Signature anhaengen"
			[ ! -f ${ETCDIR}/signature ] && { ECODE=22; break; }
			cat ${ETCDIR}/signature >> ${MAILTMPFILE}
		fi


		if [ ! -z ${ENCLOSURELIST} ] ; then
			for ENCLOSURE in ${ENCLOSURELIST} ; do
				log distrib "I: Haenge ${ENCLOSURE} an"
				[ ! -f ${ENCLOSURE} ] && { ECODE=10; break; }

				#   Zwei Optionen bzgl. Anhaenge :
				#   MAILZIP : Anhang wird gezippt
				#   DOSFMT  : DOS Zeilenenden einfuegen
				#   DOGPG  : GPG Verschluesselung
				#   die Optionen koennen bei MAILZIP=1 kombiniert werden.
				#
				DOSCMD="cat ${ENCLOSURE} " 
				[ ${DOSFMT} -eq 1 ] && DOSCMD="${DOSCMD} | unix2dos "

				if [ ${DOGPG:-0} -eq 1 ] ; then
					DOSCMD="${DOSCMD} | gpg --yes --passphrase ${GPGPASS} -c"
				fi

				if [ ${MAILZIP} -eq 1 ] ; then  
					DOSCMD="${DOSCMD} | gzip -c "
					DOSCMD="${DOSCMD} | uuencode `basename ${ENCLOSURE}`.gz"
				elif [ ${MAILZIP} -eq 2 ] ; then
					DOSCMD="zip - ${ENCLOSURE} | uuencode `basename ${ENCLOSURE}`.zip"
				else
					DOSCMD="${DOSCMD} | uuencode `basename ${ENCLOSURE}`"
				fi

				log distrib "I: ${DOSCMD}"
				eval "${DOSCMD}" >> ${MAILTMPFILE} || { ECODE=11; break; }

			done
		fi

		# Wenn in der for- Schleife ein Fehler 
		# aufgetreten ist soll keine Mail verschickt 
		# werden
		# PF 8.11.2005
		[ ${ECODE} -ne 0 ] && break; 

		#	Mail losschicken
		#
		if [ "X${OSTYPE}" == "XLinux" ] ; then
                	cat ${MAILTMPFILE} | mail -s "${MAILSUBJECT}" ${RECIPIENTLIST} || { EXITCODE=4; break; }
		else
			cat ${MAILTMPFILE} | mailx -t
		fi

		[ $? -ne 0 ] && { ECODE=20; break; }

		break;
	done

	[ ! -z ${MAILTMPFILE} ] && [ -f ${MAILTMPFILE} ] && rm ${MAILTMPFILE}

	case ${ECODE} in
                0)      MSG="I: ok" ;;
                1)      MSG="F: Anzahl Parameter" ;;
                2)      MSG="F: Variable RECIPIENTLIST ist leer" ;;
                3)      MSG="F: Variable MAILSUBJECT ist leer" ;;
                4)      MSG="F: Variable MAILTEXT ist leer" ;;
                5)      MSG="F: Variable ENCLOSURELIST ist leer" ;;
                6)      MSG="F: Variable MAILFROM ist leer" ;;
                10)      MSG="F: Enclosure nicht vorhanden" ;;
                11)      MSG="F: Enclosure einfuegen" ;;
                20)      MSG="F: Mailversand fehlgeschlagen" ;;
                *)      MSG="F: unbekannter Fehler" ;;
	esac

	log distrib ${MSG}
	return ${ECODE}
}

################################################################################
#
#	runchain
#
#	runchain fuehrt mehrere Scripte nacheinander aus.
#	Dabei wird fuer jeden Teilschritt protokolliert, ob
#	er bereits gelaufen ist, solange die Variable NOSKIP= 0 oder 
#	nicht gesetzt ist. Im Fall eines Reruns der Kette 
# 	wird bei jedem Schritt dann geprueft, ob er noch einmal
#	laufen muss. Nach Abschluss der Kette wird die Protokoll-
#	datei geloescht, so dass dann bei einem Neustart wieder 
#	die ganze Kette ausgefuehrt wird.
#
#	Parameter:
#
#	globale Variablen:
#		CHAINJOBLIST: 	Liste aller auszufuehrenden
#				Teiljobs
#		TMPDIR
#		BASENAME
#		NOSKIP		0: Skipmechanismus an
#				1: Skipmechanismus aus
#
#	Fehlercodes:
#		0)      ok
#		1)      Anzahl Parameter
#		2)      Variable CHAINJOBLIST ist leer
#		3)      Variable TMPDIR ist leer
#		4)      Variable BASENAME ist leer
#		5)      CHAINJOB nicht ausfuehrbar
#		10)      Ausfuehrung CHAINJOB
#
#	Historie:
#		25.4.05	P.Fabricius	Erstellung
#		19.5.05 P.Fabricius	CHAINPARAMS
#		9.1.06	P.Fabricius	Variable NOSKIP zum Abschalten
#					des Skipverhaltens eingefuehrt.
#		14.8.08 P.Fabricius	Infomail-Mechanismus 
#
################################################################################
runchain()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
	typeset MSG CHAINJOB CHAINPARAMS

	log runchain "I: Start"

	while true ; do
		#      Parameter pruefen und setzen
		#
		[ $# -ne 0 ] && { ECODE=1; break; }

		[ -z ${CHAINJOBLIST} ] && { ECODE=2; break; }

		[ -z ${TMPDIR} ] && { ECODE=3; break; }
		[ -z ${BASENAME} ] && { ECODE=4; break; }

		RERUNFILE=${TMPDIR}/${BASENAME}.rerun

		[ ! -z ${DEBUG} ] && [ ${DEBUG} -eq 1 ] && CHAINPARAMS=" -d"
		[ ! -z ${FORCE} ] && [ ${FORCE} -eq 1 ] && CHAINPARAMS=" -f"
		[ ! -z ${SILENT} ] && [ ${SILENT} -eq 1 ] && CHAINPARAMS="${CHAINPARAMS} -s"


		for CHAINJOB in ${CHAINJOBLIST} ; do
			grep "${CHAINJOB}" ${RERUNFILE} >/dev/null 2>&1
			if [ $? -eq 0 ] ; then 
				log runchain "I: Skip ${CHAINJOB}"
				continue
			fi

			log runchain "I: Starte ${BINDIR}/${CHAINJOB}.ksh"
			[ ! -x ${BINDIR}/${CHAINJOB}.ksh ] && { ECODE=5; break; }
			log runchain "I: Starte ${CHAINJOB}"
			log runchain "I: Mehr Infos im Logfile von ${CHAINJOB}"

			( ksh ${BINDIR}/${CHAINJOB}.ksh ${CHAINPARAMS} ) 
			[ $? -ne 0 ] && { ECODE=10; break; }

			[ ${NOSKIP:-0} -eq 0 ] &&  echo "${CHAINJOB}" >> ${RERUNFILE}
		done
		[ ${ECODE} -ne 0 ] && break

		[ ! -z ${RERUNFILE} ] && [ -f ${RERUNFILE} ] && rm ${RERUNFILE}

		break;
	done

	#	Im Fehlerfall ggfls. eine Infomail
	#	verschicken
	#
	[ ! -z ${INFOMAIL} ] && [ ${INFOMAIL} -eq 1  ] && \
		[ ${ECODE} -ne 0 ] && {

		log runchain "I: Infomail verschicken !"

		[ -z ${INFORECIPIENTS} ] &&  { ECODE=6; break; }
		[ -z ${INFOTEXT} ] &&  { ECODE=7; break; }

		( ${BINDIR}/sys/info_message.ksh \
			-v "RECIPIENTLIST=${INFORECIPIENTS}" \
			-v "MAILSUBJECT=${INFOTEXT}" )
		[ $? -ne 0 ] && { ECODE=11; break; }

	}

	case ${ECODE} in
		0)      MSG="I: ok"                          ;;
		1)      MSG="F: Anzahl Parameter"          ;;
		2)      MSG="F: Variable CHAINJOBLIST ist leer"          ;;
		3)      MSG="F: Variable TMPDIR ist leer"          ;;
		4)      MSG="F: Variable BASENAME ist leer"          ;;
		5)      MSG="F: CHAINJOB nicht ausfuehrbar"          ;;
		6)      MSG="F: Variable INFORECIPIENTS ist leer"         ;;
		7)      MSG="F: Variable INFOTEXT ist leer"         ;;
		10)      MSG="F: Ausfuehrung CHAINJOB"          ;;
		*)      MSG="F: unbekannter Fehler"        ;;
	esac



	log runchain ${MSG}
	return ${ECODE}
}

################################################################################
#
#       noholiday
#
#	Die Funktion noholiday untersucht eine Konfigurationsdatei
#	Ist darin ein String mit dem aktuellen Datum enthalten
#	liegt ein Urlaubstag vor, und es wird ein Fehlercode
#	zurueckgegeben.
#	Der Name des bearbeiteten Jobs wird in eine Datei im 
#	TMPDIR geschrieben, damit nachvollzogen werden kann,
#	welche Jobs ausgefallen sind.
#
#       Parameter:
#
#       globale Variablen:
#               BASEDIR
#
#       Fehlercodes:
#               0)      ok
#		1)	Variable ETCDIR nicht gesetzt
#		5)	Urlaubstag !
#
#       Historie:
#		19.4.2006	P.Fabricius	Erstellung
#		20.4.2006	P.Fabricius	Force zum skippen
#		15.1.2007	P.Fabricius	ausgefallene Jobs in eine
#						Datei packen.
#
################################################################################
noholiday()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
	typeset MSG HOLIDAYFILE

	log noholiday "I: Start"

	while true ; do
		if [ ${FORCE:-0} -eq 1 ] ; then 
			log noholiday "I: noholiday uebersprungen"
			ECODE=0
			break
		fi

		[ -z ${ETCDIR} ] && { ECODE=1; break; }

		HOLIDAYFILE=${ETCDIR}/holiday.cfg
		[ ! -f ${HOLIDAYFILE} ] && { ECODE=0; break; }

		grep "^"`date '+%Y-%m-%d'` ${HOLIDAYFILE} >/dev/null 2>&1 && { 
			echo "${BASENAME}" >> ${TMPDIR}/holidayjobs_`date '+%Y%m%d'`.csv
			ECODE=5; 
		}

		break;
	done

	case ${ECODE} in
		0)      MSG="I: ok"                          	;;
		5)	MSG="F: URLAUBSTAG, ABBRUCH!"		;;
		*)      MSG="F: unbekannter Fehler"        	;;
	esac

	log noholiday ${MSG}
	return ${ECODE}
}

export LOGOK=0
export FORCE=0
export LIB_LIBALLG=1
