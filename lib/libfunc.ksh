#!/bin/ksh
################################################################################
#
#	libfunc
#
#	- BESCHREIBUNG
#
#	Es wurde vorgeschlagen Funktionen vorzudefinieren, die
#	in den Konfigurationsdateien verwendet werden koennen.
#	Ein Beispiel fuer eine solche Funktion ist getpremon,
#	welche den Vormonat ermittelt. Damit ist man in der Lage
#	z.B. einem Dateinamen den Monat des Inhalts beizubringen.
#
#	Bibliothek ist in Entwicklung, Machbarkeit wird noch
#	untersucht.
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
#	- Kontakt
#
#	pfabricius@gmx.de
#
#       - TODO
#
#       - HISTORIE
#
#	P.Fabricius	24.8.2006	Erstellung
#
################################################################################

################################################################################
#
#	getpremon
#
#	Funktion getrepmon ermittelt den Vormonat.
#	Die Funktion an sich funktioniert, die Verwendung in 
#	den Konfigurationsdateien ist noch nicht klar/machbar.
#
#	Historie:
#	P.Fabricius	24.8.2006	Erstellung
#
################################################################################
getpremon()
{
        [[ ${DEBUG:-0} -eq 1 ]] && set -x
        typeset -i ECODE=0
	typeset WERT

	log getpremon "I:Start"

	while true ; do
		#
		#
		eval `sqlplus -s ${DEFAULTDBUSER} <<! | grep "WERT"
        		SET HEADING OFF
        		SELECT
                		'WERT=' || TO_CHAR(
					ADD_MONTHS(TRUNC(SYSDATE,'Month'),-1),
					'YYYY-MM')
        		FROM
				dual;
!
`
		[ $? -ne 0 ] && { ECODE=1; break; }
		echo "${WERT}"

		break;
	done

	log getpremon "I:Ende WERT=${WERT}"

	return ${ECODE}
}


export LOGOK=0
export FORCE=0
export LIB_LIBFUNC=1
