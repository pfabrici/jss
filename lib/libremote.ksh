#!/bin/ksh
################################################################################
#
#	libremote
#
#	- BESCHREIBUNG
#
#	Bibliothek mit Funktionen zum Datenransfer zwischen
#	verschiedenen Maschinen
#
#       Konfigurationsdateien           ./etc
#       Scriptdateien                   ./scr</...>
#       Links auf Templates             ./bin</...>
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
#		kann den jeweiligen Funktionen entnommen werden
#
################################################################################

################################################################################
#
#	ftpscript
#
#	Funktion zum kopieren von Dateien via ftp.
#	Es sind nur put/get Funktionen nutzbar, die 
#	mit einem Filepattern aufgerufen werden
#
#	Parameter:
#
#	globale Variablen:
#
#	Fehlercodes:
#		1) Anzahl Parameter
#		2) Variable FTPTGTSERVER ist leer
#		3) Variable FTPUSER ist leer
#		4) Variable FTPPWD ist leer
#		5) Variable FTPLOCALDIR ist leer
#		6) Variable FTPDIR ist leer
#		7) Variable FTPCMD ist leer
#		8) Variable FTPFILEPATTERN ist leer
#
#	Historie:
#		xx.yy.zzzz	P.Fabricius	Erstellung
#		05.01.2010	P.Fabricius	FTPDOCHMOD
#
################################################################################
ftpscript()
{
        [ ${DEBUG:-0} -eq 1 ] && set -x
        typeset -i ECODE=0
        typeset MSG FTPTMPFILE

        log ftpscript "I: Start"

        while true ; do
                #      Parameter pruefen und setzen
                #
		[ $# -ne 0 ] && { ECODE=1; break; }

		[ -z ${FTPTGTSERVER} ] && { ECODE=2; break; }
		[ -z ${FTPUSER} ] && { ECODE=3; break; }
		[ -z ${FTPPWD} ] && { ECODE=4; break; }
		[ -z ${FTPLOCALDIR} ] && { ECODE=5; break; }
		[ -z ${FTPDIR} ] && { ECODE=6; break; }
		[ -z ${FTPCMD} ] && { ECODE=7; break; }
		[ -z ${FTPFILEPATTERN} ] && { ECODE=8; break; }
		[ -z ${FTPDOCHMOD} ] &&  FTPDOCHMOD=1

		FTPTMPFILE=${TMPDIR}/${BASENAME}.ftp
		

		echo "open ${FTPTGTSERVER}" > ${FTPTMPFILE}
		echo "user ${FTPUSER} ${FTPPWD}" >>${FTPTMPFILE}
		echo "lcd ${FTPLOCALDIR}" >>${FTPTMPFILE}
		echo "cd ${FTPDIR}" >>${FTPTMPFILE}
		echo "${FTPCMD} ${FTPFILEPATTERN}" >> ${FTPTMPFILE}
		[ ${FTPDOCHMOD} -eq 1 ] && echo "chmod 777 ${FTPFILEPATTERN}" >> ${FTPTMPFILE}
		echo "close"	>> ${FTPTMPFILE}
		echo "bye"	>> ${FTPTMPFILE}

		cat ${FTPTMPFILE} >>${LOGFILE:-/dev/null}

		#	FTP ausfuehren
		#
		cat ${FTPTMPFILE} | ftp -n -v -i >>${LOGFILE:-/dev/null}
		[ $? -ne 0 ] && { ECODE=20; break; }

		break;
	done

	[ ! -z ${FTPTMPFILE} ] && [ -f ${FTPTMPFILE} ] && rm ${FTPTMPFILE}

	case ${ECODE} in
                0)      MSG="I: ok"                          ;;
                1)      MSG="F: Anzahl Parameter"          ;;
                2)      MSG="F: Variable FTPTGTSERVER ist leer"          ;;
                3)      MSG="F: Variable FTPUSER ist leer"          ;;
                4)      MSG="F: Variable FTPPWD ist leer"          ;;
                5)      MSG="F: Variable FTPLOCALDIR ist leer"          ;;
                6)      MSG="F: Variable FTPDIR ist leer"          ;;
                7)      MSG="F: Variable FTPCMD ist leer"          ;;
                8)      MSG="F: Variable FTPFILEPATTERN ist leer"          ;;
                *)      MSG="F: unbekannter Fehler"        ;;
	esac

	log ftpscript ${MSG}
	return ${ECODE}
}

################################################################################
#
#	ftpscriptcmd
#
#	Funktion zum Ausfuehren eines FTP Skripts
#
#	Parameter:
#
#	globale Variablen:
#
#	Fehlercodes:
#		1) Anzahl Parameter
#		2) Variable FTPCMDFILE ist leer
#
#	Historie:
#		15.10.2006	T.Butenop	Erstellung
#
################################################################################
ftpscriptcmd()
{
        [ ${DEBUG:-0} -eq 1 ] && set -x
        typeset -i ECODE=0
        typeset MSG FTPTMPFILE

        log ftpscriptcmd "I: Start"

        while true ; do
                #      Parameter pruefen und setzen
                #
		[ $# -ne 0 ] && { ECODE=1; break; }

		[ -z ${FTPCMDFILE} ] && { ECODE=2; break; }

		FTPTMPFILE=${TMPDIR}/${BASENAME}.ftp
		cat /dev/null > ${FTPTMPFILE}

		[ -n "${FTPTGTSERVER}" ] && {
			echo "open ${FTPTGTSERVER}" >> ${FTPTMPFILE}
			[ -n "${FTPUSER}" -a -n "${FTPPWD}" ] && {
				echo "user ${FTPUSER} ${FTPPWD}" >>${FTPTMPFILE}
				[ -n "${FTPDIR}" ] && {
					echo "cd ${FTPDIR}" >>${FTPTMPFILE}
				}
			}
		}
		[ -n "${FTPLOCALDIR}" ] && {
			echo "lcd ${FTPLOCALDIR}" >>${FTPTMPFILE}
		}
		cat ${FTPCMDFILE} >> ${FTPTMPFILE}

		cat ${FTPTMPFILE} >>${LOGFILE:-/dev/null}

		#	FTP ausfuehren
		#
		cat ${FTPTMPFILE} | ftp -n -v -i >>${LOGFILE:-/dev/null}
		[ $? -ne 0 ] && { ECODE=20; break; }

		break;
	done

	[ ! -z ${FTPTMPFILE} ] && [ -f ${FTPTMPFILE} ] && rm ${FTPTMPFILE}

	case ${ECODE} in
                0)      MSG="I: ok"                          ;;
                1)      MSG="F: Anzahl Parameter"          ;;
                2)      MSG="F: Variable FTPCMDFILE ist leer"          ;;
                *)      MSG="F: unbekannter Fehler"        ;;
	esac

	log ftpscriptcmd ${MSG}
	return ${ECODE}
}

export LIB_LIBREMOTE=1
