#!/bin/ksh
################################################################################
#
#	libprotokoll
#
#	- BESCHREIBUNG
#
#	Bibliothek zum Handling eines rudimentaeren 
#	Prozessprotokollhandlings
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
#		kann den Funktionen entnommen werden
#
################################################################################

[ -z ${LIB_LIBALLG} ] && { echo "PANIC: liballg not included"; exit 99; } 

################################################################################
#
#       initprotokoll
#
#	Merkt sich den Zeitpunkt des Scriptstarts in der 
#	Variablen ETLSTART, wenn ETLPROTOKOLL=1 gesetzt ist
#
#       Parameter:
#
#       globale Variablen:
#		ETLSTART
#		ETLPROTOKOLL
#
#       Fehlercodes:
#
#       Historie:
#               19.7.2005       PF      Erstellung
#
################################################################################
initprotokoll()
{
        [ ${DEBUG:-0} -eq 1 ] && set -x
        typeset -i ECODE=0
        typeset MSG 

        log initprotokoll "I: Start"

        while true ; do
		# 	Wenn Protokollmechanismus ausgeschaltet ist
		# 	sofort raus
		#
		[ -z ${ETLPROTOKOLL} ] && ETLPROTOKOLL=0
		[ ${ETLPROTOKOLL} -eq 0 ] &&  { ECODE=0; break; }

                #   Parameter setzen/pruefen
                #
		ETLSTART=`date '+%Y-%m-%d %T'`
		log initprotokoll "I: ETLSTART=${ETLSTART}"

                #       ... und fertig
                #
                break
        done

        case ${ECODE} in
                0)  MSG="I: ok" ;;
                *)  MSG="F: unbekannter Fehler" ;;
        esac

        log initprotokoll ${MSG}
        return ${ECODE}
}

################################################################################
#
#       updateprotokoll
#
#	Dummyfunktion. Fuer spaetere Verwendung, wenn die Prozesse
#	waehrend der Laufzeit Updates in der Protokolltabelle machen
#	sollten.
#
#       Parameter:
#
#       globale Variablen:
#
#       Fehlercodes:
#
#       Historie:
#               19.7.2005       PF      Erstellung
#
################################################################################
updateprotokoll()
{
        [ ${DEBUG:-0} -eq 1 ] && set -x
        typeset -i ECODE=0
        typeset MSG CMD MYDBTYPE MYDBCONNECT WCNAME

        log updateprotokoll "I: Start"

        while true ; do
                #   Parameter setzen/pruefen
                #

                #       ... und fertig
                #
                break
        done

        case ${ECODE} in
                0)  MSG="I: ok" ;;
                *)  MSG="F: unbekannter Fehler" ;;
        esac

        log updateprotokoll ${MSG}
        return ${ECODE}
}

################################################################################
#
#	finishprotokoll
#
#	Macht einen Eintrag in der Prozessprotokolltabelle
#
#	Parameter:
#		ETLERROR	: Fehlercode
#		ETLROWS		: Anzahl Rows
#
#	globale Variablen:
#		ETLVORGANG
#		ETLOBJEKT
#		ETLSYSTEM
#
#	Fehlercodes:
#
#	Historie:
#		19.7.2005	PF 	Erstellung
#		16.5.2007	PF	Force beim insprotokoll : wenn der 
#					Prozess bei Holiday laeuft, muss
#					auch der insprotokoll laufen.
#
################################################################################
finishprotokoll()
{
        [ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
        typeset MSG CMD MYDBTYPE MYDBCONNECT WCNAME

        log finishprotokoll "I: Start"

        while true ; do
		# 	Wenn Protokollmechanismus ausgeschaltet ist
		# 	sofort raus
		#
		[ -z ${ETLPROTOKOLL} ] && ETLPROTOKOLL=0
		[ ${ETLPROTOKOLL} -eq 0 ] &&  { ECODE=0; break; }

                #   Parameter setzen/pruefen
                #
		ETLERROR=${1}
		[ -z ${ETLERROR} ] && ETLERROR=0
		ETLROWS=${2}
		[ -z ${ETLROWS} ] && ETLROWS=0
		
		ETLENDE=`date '+%Y-%m-%d %T'`

		[ -z ${ETLVORGANG} ] && { ECODE=2; break; }
		[ -z ${ETLOBJEKT} ] && { ECODE=3; break; }
		[ -z ${ETLSYSTEM} ] && { ECODE=4; break; }

		[ ! -f ${BINDIR}/sys/insprotokoll.ksh ] && { ECODE=5; break; }	

		export ETLERROR ETLROWS ETLSTART ETLENDE ETLVORGANG ETLOBJEKT ETLSYSTEM
		${BINDIR}/sys/insprotokoll.ksh -n -f  || { ECODE=10; break; } 

		# 	... und fertig
                #
                break
        done

        case ${ECODE} in
                0)  MSG="I: ok" ;;
		2)  MSG="F: Variable ETLVORGANG nicht gesetzt" ;;
		3)  MSG="F: Variable ETLOBJEKT nicht gesetzt" ;;
		4)  MSG="F: Variable ETLSYSTEM nicht gesetzt" ;;
		5)  MSG="F: Insert Programm nicht vorhanden" ;;
		10)  MSG="F: Programm fehlgeschlagen" ;;
                *)  MSG="F: unbekannter Fehler" ;;
        esac

        log finishprotokoll ${MSG}
        return ${ECODE}
}

