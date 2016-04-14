#!/bin/ksh
################################################################################
#
#	libmail
#
#       - BESCHREIBUNG
#
#	Libmail stellt Funktionen fuer das Handling eines 
#	automatisierten Mailversands zur Verfuegung.
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
#
#       pfabricius@gmx.de
#
#       - TODO
#
#       - HISTORIE
#
#	P.Fabricius	25.7.2006	Erstellung
#
################################################################################

################################################################################
#
#	getmailadress
#
#	Zuordnung zwischen UNIX Benutzernamen und Mailaccount
#	herstellen.
#
################################################################################
getmailadress() {
	typeset -i ECODE=0
	typeset GMATMPFILE
	[ ${DEBUG:-0} -eq 1 ] && set -x

	while [ 1 -eq 1 ]  ; do

		if [ "X${OSTYPE}" == "XLinux" ] ; then
			WERBINICH=`ps --pid $$ -o user --no-headings`
		else
			MYTTY=`tty | sed s/'\/dev\/'//`
			WERBINICH=`who | grep "${MYTTY} " | awk ' { print $1 } '`
		fi

		[ -z ${TMPDIR} ] && { ECODE=4; break; }
		GMATMPFILE=${TMPDIR}/libgma_$$.tmp

        	DATACMD="grep -n \"[STARTDATA|ENDDATA] recipients\" $0 | \
                	awk -F':' ' { print \$1; } ' | xargs | \
                	awk ' { printf(\"head -%s $0  | tail -%s\n\",\$2-1,\$2-\$1-1); } '"

		eval `eval $DATACMD` > ${GMATMPFILE}

		while read LINE ; do
			DATACMD2=`echo $LINE | awk -F':' ' { printf("DATAIDENT=\"%s\"; DATASTRING=\"%s\";DATAVAR=\"%s\";\n",$1,$2,$3); } '`
			eval ${DATACMD2}

			case ${DATAIDENT} in 
				"#RECIPIENT")	[ "X${DATASTRING}" == "X${WERBINICH}" ] && MAILRECIPIENT=${DATAVAR} ;;
			esac
			
		done < ${GMATMPFILE}

		[ -z ${MAILRECIPIENT} ] && ECODE=2

		#
		break
	done
	
	[ -f ${GMATMPFILE} ] && rm ${GMATMPFILE}

	return ${ECODE}
}

export LIB_LIBMAIL=1

