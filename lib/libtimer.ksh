#!/bin/ksh
################################################################################
#
#	libtimer.ksh
#
#	- BESCHREIBUNG
#
#	Es gibt Prozesse, die unabhaengig von dem Grad der 
#	Fertigstellung nach einer bestimmten Zeit abgeborchen 
#	werden sollen. Diese Biblithek stellt Funktionen zur
#	Realisierung zur Verfuegung.
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
#	P.Fabricius	23.1.2007	Erstellung Header, CVS
#
################################################################################

[ -z ${LIB_LIBALLG} ] && { echo "PANIC: liballg not included"; exit 99; } 

################################################################################
#
#	timerstart
#
#	Funktion wartet TIMERSECS Sekunden.
#	Im Anschluss wird der uebergeordnete Prozess gekillt.
#
#
################################################################################
timerstart()
{
	log timerstart "I: Wecker auf ${TIMERSECS} Sekunden stellen"
	sleep ${TIMERSECS}
	log timerstart "I: Wecker klingelt"
	timerstop
	[ ! -z ${TIMERMAINPID} ] && kill ${TIMERMAINPID}
}

################################################################################
#
#	timerstop
#
#	Beendet den Hintergrundprozess, der den Wecker beinhaltet
#
#
################################################################################
timerstop()
{
	[ -z ${TIMERTHREADPID} ] && return 
	log timerstop "I: Wecker ausschalten"
	kill ${TIMERTHREADPID}
}

################################################################################
#
#
#
################################################################################
progexit()
{
	timerstop
	exit 512
}

################################################################################
#
#
#
################################################################################
timerinit()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
	typeset MSG TIMERMAINPID

	log timerinit "I: Start"

	while [ 1 -eq 1 ] ; do
		#	Wenn TIMERSECS nicht 
		#	gesetzt ist wird die Funktion
		#	nicht genutzt
		#
		[ -z ${TIMERSECS} ] && { ECODE=0; break; }

		TIMERMAINPID=$$
		log timerinit "I: ${TIMERMAINPID}"
		timerstart &
		TIMERTHREADPID=$!

		trap progexit 2

		#
		break
	done

	case ${ECODE} in 
		0) MSG="I: ok" ;;
		*) MSG="F: unbekannter Fehler" ;;
	esac

	log timerinit "${MSG}"
	return ${ECODE}
}

export LIB_LIBTIMER=1
