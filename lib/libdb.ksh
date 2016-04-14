#!/bin/ksh
################################################################################
#
#	libdb
#
#	- BESCHREIBUNG
#
#	Die Shellbibliothek libdb stellt im Zusammenhang mit der 
#	Bibliothek liballg Funktionen fuer die Arbeit mit
#	Datenbanken zur Verfuegung.
#
#       LIZENZ:
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
#		kann den Funktionen entnommen werden
#
################################################################################

[ -z ${LIB_LIBALLG} ] && { echo "PANIC: liballg not included"; exit 99; } 

################################################################################
#
#	runsqlfile
#
#	Die Funktione runsqlfile startet ein Datenbankfrontend um 
#	damit den Inhalt einer SQL Datei auszufuehren. Das Datenbank-
#	frontend wird anhand der globalen Variablen DBTYPE ermittelt
#	Unterstuetzte Datenbanken sind Informix, Oracle, mysql und postgres.
#
#	Parameter:
#		DBFILE	auszufuehrende Datei
#		alternativ:
#		DBTYPE	OR | IF | MY | PG | SH
#		und(!!) DBCONNECT 
#
#	globale Variablen:
#		DBTYPE 
#		DBCONNECT
#
#	Fehlercodes:
#		1)  F: Anzahl Parameter
#		2)  F: Datei DBFILE nicht vorhanden
#		3)  F: unbekannter DBTYPE
#		4)  F: Ausfuehrung CMD
#		20) F: Variable DBTYPE nicht gesetzt
#		21)  F: Variable DBCONNECT nicht gesetzt
#
#	Historie:
#		10.2.05	P.Fabricius	Erstellung
#		19.5.05 P.Fabricius	Anzahl Zeilen im Unload
#		7.3.06  P.Fabricius	WCNAME statt WNAME
#		1.4.07  P.Fabricius	dbish als Frontend 
#		13.12.07 P.Fabricius	MYDBCONNECT fuer mysql
#		10.03.08 P.Fabricius	skip-column-names fuer mysql
#
################################################################################
runsqlfile()
{
        [ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
        typeset MSG CMD MYDBTYPE MYDBCONNECT WCNAME

        log runsqlfile "I: Start"

        while true ; do
                #   Parameter setzen/pruefen
                #
                [ $# -lt 1 ] && { ECODE=1; break; }
		DBFILE=$1
		log runsqlfile "I: DBFILE=${DBFILE}"
		[ ! -f ${DBFILE} ] && { ECODE=2; break; }

		MYDBTYPE=${DBTYPE:-$2}
		[ -z ${MYDBTYPE} ] && { ECODE=20; break; }
		log runsqlfile "I: MYDBTYPE=${MYDBTYPE}"

		MYDBCONNECT=${DBCONNECT:-$3}
		[ -z "${MYDBCONNECT}" ] && { ECODE=21; break; }
		log runsqlfile "I: MYDBCONNECT=${MYDBCONNECT}"


		#	abhaengig vom DBTYPE einen Kommando-
		#	string generieren
		#
		case ${MYDBTYPE} in
			PG) CMD='psql -f ${DBFILE}'
				;;
			MY) CMD='mysql --skip-column-names ${MYDBCONNECT} <${DBFILE}'
				;;
			IF) CMD='dbaccess ${MYDBCONNECT} ${DBFILE}'
				;;
			OR) CMD="sqlplus ${MYDBCONNECT} @${DBFILE}"
				;;
			SH) CMD="dbish --batch ${MYDBCONNECT} < ${DBFILE}"
				;;
			*) ECODE=3 ;;
		esac
		[ ${ECODE} -ne 0 ] && break

		#	SQL ausfuehren
		#
		log runsqlfile "I: CMD=${CMD}"
		eval ${CMD} >>${LOGFILE:-/dev/null} 2>&1 || { ECODE=4; break; }

		#	Wenn es Unloads gab, moechte 
		#	ich wissen, in welche Datei wie viele
		#	DS entladen wurden. Erst mal nur Oracle
		#	betrachten.
		#
		if [ "X${MYDBTYPE}" == "XOR" ] ; then
			WCFILES=`grep "^SPOOL" ${DBFILE}  | grep -vi "SPOOL OFF" | cut -f2 -d' ' | xargs `
			for WCNAME in ${WCFILES} ; do
				[ -f ${WCNAME} ] && log runsqlfile "I: "`wc -l $WCNAME`
			done
		fi

		# 	... und fertig
                #
                break
        done

        case ${ECODE} in
                0)  MSG="I: ok" ;;
                1)  MSG="F: Anzahl Parameter" ;;
		2)  MSG="F: Datei DBFILE nicht vorhanden" ;;
                3)  MSG="F: unbekannter DBTYPE" ;;
                4)  MSG="F: Ausfuehrung CMD" ;;
                20)  MSG="F: Variable DBTYPE nicht gesetzt" ;;
                21)  MSG="F: Variable DBCONNECT nicht gesetzt" ;;
                *)  MSG="F: unbekannter Fehler" ;;
        esac

        log runsqlfile ${MSG}
        return ${ECODE}
}

################################################################################
#
#	runsql
#
#	Die Funktion runsql ermittelt anhand eines Identifiers der
#	als Parameter uebergeben wird und verschiedenen globalen
#	Variablen das auszufuehrende SQL Statement, ersetzt mit Hilfe
#	der Funktion exchangevars Platzhalter in der SQL Datei
#	und nutzt die Funktion runsqlfile um die Datei auszufuehren.
#
#	Beispiel:
#		Identifier ist select_all
#		DBTYPE ist OR fuer oracle
#		SQLDIR ist /home/foobar/sql
#		TMPDIR ist /home/foobar/tmp
#
#		Die Variablen in der Datei /home/foobar/sql/OR_select_all.sql
#		werden ersetzt und das Ergebnis in eine temporaere Datei
#		unter ${TMPDIR} geschrieben. Diese Datei wird mit 
#		runsqlfile ausgefuehrt und anschliessend geloescht.
#
#	Parameter:
#		DBFILEIDENT Identifier fuer die auszufuehrende Datei
#
#	globale Variablen:
#		DBTYPE 
#		DBCONNECT
#
#	Fehlercodes:
#		1) F: Anzahl Parameter
#		20)  F: Variable DBTYPE nicht gesetzt
#		21)  F: Variable DBCONNECT nicht gesetzt
#		22)  F: Variable SQLDIR nicht gesetzt
#		23)  F: SQLDIR ist kein Verzeichnis
#		24)  F: Variable TMPDIR nicht gesetzt
#		25)  F: TMPDIR ist kein Verzeichnis
#		30)  F: BASEFILE nicht vorhanden
#		31)  F: liballg nicht eingebunden
#		32)  F: exchangevars fehlgeschlagen
#		40)  F: Ausfuehrung SQL
#
#	Historie:
#		10.2.05	P.Fabricius	Erstellung
#		10.5.05 P.Fabricius	Vor dem Loeschen von RUNSQLTMPFILE
#					auf Existenz der Variable pruefen
#
################################################################################
runsql()
{
        [ ${DEBUG:-0} -eq 1 ] && set -x
        typeset -i ECODE=0
        typeset MSG=""
	typeset DBFILEIDENT BASEFILE RUNSQLTMPFILE
	typeset MYDBTYPE MYDBCONNECT

        log runsql "Start"

        while true ; do
                #       Parameter testen/setzen
                #
                [ $# -ne 1 ] && { ECODE=1; break; }
		BASEFILE=$1
		log runsqlfile "I: BASEFILE=${BASEFILE}"
		[ ! -f ${BASEFILE} ] && { ECODE=30; break; }

		MYDBTYPE=${DBTYPE:-$2}
		[ -z ${MYDBTYPE} ] && { ECODE=20; break; }
		log runsqlfile "I: MYDBTYPE=${MYDBTYPE}"

		MYDBCONNECT=${DBCONNECT:-$3}
		[ -z ${MYDBCONNECT} ] && { ECODE=21; break; }
		log runsqlfile "I: MYDBCONNECT=${MYDBCONNECT}"

		[ -z {TMPDIR} ] && { ECODE=24; break; }
		[ ! -d ${TMPDIR} ] && { ECODE=25; break; }

		RUNSQLTMPFILE=${TMPDIR}/runsql_${DBFILEIDENT}_$$.sql

		#	Variablen ersetzen
		#
		type exchangevars >/dev/null 2>&1 || { ECODE=31; break; }
		exchangevars ${BASEFILE} ${RUNSQLTMPFILE} || { ECODE=32; break; }

		cat ${RUNSQLTMPFILE} >>${LOGFILE:-/dev/null}

		#
		#
		runsqlfile ${RUNSQLTMPFILE} || { ECODE=40; break; }

                #
                break
        done

	[ ! -z ${RUNSQLTMPFILE} ] && [ -f ${RUNSQLTMPFILE} ] && rm ${RUNSQLTMPFILE}

        case ${ECODE} in 
                0) MSG="I: ok" ;;
                1) MSG="F: Anzahl Parameter" ;;
                20)  MSG="F: Variable DBTYPE nicht gesetzt" ;;
                21)  MSG="F: Variable DBCONNECT nicht gesetzt" ;;
                24)  MSG="F: Variable TMPDIR nicht gesetzt" ;;
                25)  MSG="F: TMPDIR ist kein Verzeichnis" ;;
                30)  MSG="F: BASEFILE nicht vorhanden" ;;
                31)  MSG="F: liballg nicht eingebunden" ;;
                32)  MSG="F: exchangevars fehlgeschlagen" ;;
                40)  MSG="F: Ausfuehrung SQL" ;;
                *) MSG="F: unbekannter Fehler" ;;
        esac

        log runsql "${MSG}"
        log runsql "Ende mit Exitcode ${ECODE}"

        return ${ECODE}
}

################################################################################
#
#	runsqlldr
#
#	Ruft den Oracle sqlldr auf.
#
#
#	Historie:
#		10.2.05	P.Fabricius	Erstellung
#		13.6.05	P.Fabricius	Loeschen von temp. Dateien
#		13.12.07 P.Fabricius	Quotes bei -z
#
################################################################################
runsqlldr()
{
        [ ${DEBUG:-0} -eq 1 ] && set -x
        typeset -i ECODE=0
        typeset MSG=""
        typeset DBFILEIDENT CTLFILE RUNCTLTMPFILE LOGCTLTMPFILE
        typeset MYDBCONNECT

        log runsqlldr "Start"

        while [ 1 -eq 1 ] ; do
                #       Parameter testen/setzen
                #
                [ $# -lt 1 ] && { ECODE=1; break; }
                CTLFILE=$1
		[ ! -f ${CTLFILE} ] && { ECODE=30; break; }
                log runsqlldr "I: CTLFILE=${CTLFILE}"

                MYDBCONNECT=${DBCONNECT:-$3}
                [ -z "${MYDBCONNECT}" ] && { ECODE=21; break; }
                log runsqlldr "I: MYDBCONNECT=${MYDBCONNECT}"

                [ -z {TMPDIR} ] && { ECODE=24; break; }
                [ ! -d ${TMPDIR} ] && { ECODE=25; break; }

		RUNCTLTMPFILE=${TMPDIR}/runsql_${DBFILEIDENT}_$$.ctl
		LOGCTLTMPFILE=${TMPDIR}/runsql_${DBFILEIDENT}_$$.log

                #       Variablen ersetzen
                #
                type exchangevars >/dev/null 2>&1 || { ECODE=31; break; }
                exchangevars ${CTLFILE} ${RUNCTLTMPFILE} || { ECODE=32; break; }

                cat ${RUNCTLTMPFILE} >>${LOGFILE:-/dev/null}
		log runsqlldr "I: SQLLDRPARAMS=${SQLLDRPARAMS}"

                #
                #
		sqlldr USERID=${MYDBCONNECT} CONTROL=${RUNCTLTMPFILE} LOG=${LOGCTLTMPFILE} \
			${SQLLDRPARAMS} >>${LOGFILE:-/dev/null} 2>&1
                [ $? -ne 0 ] && { ECODE=40; break; }

                #
                break
        done

	[ ! -z ${LOGCTLTMPFILE} ] && [ -f ${LOGCTLTMPFILE} ] && cat ${LOGCTLTMPFILE} >>${LOGFILE:-/dev/null} 
	[ -f ${LOGCTLTMPFILE} ] && rm ${LOGCTLTMPFILE}
        [ ! -z ${RUNCTLTMPFILE} ] && [ -f ${RUNCTLTMPFILE} ] && rm ${RUNCTLTMPFILE}

        case ${ECODE} in
                0) MSG="I: ok" ;;
                1) MSG="F: Anzahl Parameter" ;;
                21)  MSG="F: Variable DBCONNECT nicht gesetzt" ;;
                24)  MSG="F: Variable TMPDIR nicht gesetzt" ;;
                25)  MSG="F: TMPDIR ist kein Verzeichnis" ;;
                30)  MSG="F: BASEFILE nicht vorhanden" ;;
                31)  MSG="F: liballg nicht eingebunden" ;;
                32)  MSG="F: exchangevars fehlgeschlagen" ;;
                40)  MSG="F: Ausfuehrung SQL" ;;
                *) MSG="F: unbekannter Fehler" ;;
        esac

        log runsqlldr "${MSG}"
        log runsqlldr "Ende mit Exitcode ${ECODE}"

        return ${ECODE}
}

