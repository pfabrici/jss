#!/bin/ksh
################################################################################
#
#	libdialog.ksh
#
#	- BESCSCHREIBUNG
#
#	Bibliothek enthaelt Funktionen fuer Skriptfrontends
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

################################################################################
#
#	substr
#
#	Funktion zum Ausschneiden von Teilen aus Strings
#	mit rudimentaerer Fehlerbehandlung.
#
#	Parameter : 
#		1: String
#		2: Anfang
#		3: Laenge
#
#	Historie:
#		30.8.05	P.Fabricius	Erstellung
#
#
################################################################################
substr() {
	[ $# -ne 3 ] || [ ${#1} -lt $(( $2 + $3 ))  ] && return -1
	echo $1 $2 $3 | awk ' { printf("%s", substr($1,$2,$3)); }'
}

################################################################################
#
#	getinput
#
#	Eingabefunktion. Holt eine Benutzereingabe von der Tastatur
#	ab und schreibt das Ergebnis in eine definierbare 
#	Variable.
#
#	Parameter:
#		VARNAME : Name der Variablen, in der das 
#			Ergebnis gespeichert werden soll.
#		PROMPT	: Text, der als Frage erscheinen soll.
#			Default ist "-->"
#
#	Fehlercodes:
#		Bei einem Fehler wird immer 2 zurueckgegeben
#
#	Historie:
#		28.8.05	P.Fabricius	Erstellung
#
################################################################################
getinput() {
        [ ${DEBUG:-0} -eq 1 ] && set -x
        typeset ECODE=0
        typeset PROMPT VARNAME ANSWER CMD

        [ $# -lt 1 ] && { ECODE=1; break; }

        VARNAME=$1
        PROMPT=${2:-"-->"}
        ANSWER=""

        while true ; do
                read ANSWER?"Neuer Wert fuer ${PROMPT} : "
		[ $? -ne 0 ] && { ECODE=2; break; }

                if [ ! -z "${ANSWER}" ] ; then
                        eval $VARNAME="$ANSWER"
			[ $? -ne 0 ] && { ECODE=2; break; }
			CMD="export ${VARNAME}"
			eval $CMD
			[ $? -ne 0 ] && { ECODE=2; break; }
                        break
                fi
        done

        return ${ECODE}
}

################################################################################
#
#	runform
#
#	zeigt und betreibt ein Formular, welches ueber
#	Kommentarzeilen im Skript definiert wird.
#	Verwendet die Funktion getinput.
#	Beispiele fuer Formulardefinitionen sind am Ende
#	der Bibliothek.
#	
#	Historie:
#		28.8.05	P.Fabricius	Erstellung
#		27.5.09 P.Fabricius	XZCMD eingefuehrt
#
################################################################################
runform() {
	[ ${DEBUG} -eq 1 ] && set -x
	typeset DIALOGCMD DIALOGCMD2 CASECMD XYCMD

	FORMNAME=$1
	DIALOGENDE=0
	clear
	echo "\n--------------------------------------------------------------"
	echo "${FORMNAME}"
	echo "--------------------------------------------------------------\n\n"
	
	DIALOGCMD="grep -n \"[STARTFORM|ENDFORM] ${FORMNAME}\" $0 | \
		awk -F':' ' { print \$1; } ' | xargs | \
		awk ' { printf(\"head -%s $0  | tail -%s\n\",\$2-1,\$2-\$1-1); } '"

	#	In einer Schleife ueber
	#	alle Zeilen der Form gehen
	eval `eval ${DIALOGCMD}` | while read LINE ; do
		DIALOGCMD2=`echo $LINE | awk -F':' ' { printf("DIALOGIDENT=\"%s\"; DIALOGSTRING=\"%s\"; DIALOGSHRTCUT=\"%s\"; DIALOGVAR=\"%s\";\n",$1,$2,$3,$4); } '`
		eval "${DIALOGCMD2}"

		case ${DIALOGIDENT} in
			"#HEADER"|"#FOOTER"|"#TEXT")	echo ${DIALOGSTRING} | tr '§' ' ';;
			"#VARLINE")	XZCMD="echo \$${DIALOGVAR}"
					echo "${DIALOGSTRING} (${DIALOGSHRTCUT}) : "`eval ${XZCMD}`
					CASECMD="${CASECMD} ${DIALOGSHRTCUT}) getinput ${DIALOGVAR} \"${DIALOGSTRING}\" ;;"
					;;
			"#MENUITEM")	echo "${DIALOGSTRING} (${DIALOGSHRTCUT})"
					CASECMD="${CASECMD} ${DIALOGSHRTCUT}) FORMNAME=${DIALOGVAR} ;;"
					;;
                        "#MENUFKT")     echo "${DIALOGSTRING} (${DIALOGSHRTCUT})"
                                        CASECMD="${CASECMD} ${DIALOGSHRTCUT}) ${DIALOGVAR} ;;"
                                        ;;
		esac
	done

	echo "\n\n--------------------------------------------------------------"
	echo " q: Formularende  <key>: Parameter aendern"
	echo "--------------------------------------------------------------"
	read INPUT?"-> "

	XYCMD='case $INPUT in \nq) ECODE=0; DIALOGENDE=1 ;;\n'
	XYCMD="${XYCMD}${CASECMD}"
	XYCMD=${XYCMD}"\nesac"
	
	eval `echo $XYCMD `

	[ ${DIALOGENDE} -eq 1 ] && return	
	runform ${FORMNAME}
}




#
#	Beispiele fuer Formulardefinitionen :
#


##STARTFORM erste
#HEADER:BEISPIELFORMULAR
#HEADER:
#HEADER:In diesem Formular gibt es zwei Parameter, die man
#HEADER:aendern kann.
#HEADER:
#COMMENT:Zeile 2
#VARLINE:X:x:VARX:
#VARLINE:Y:y:VARY:
#TEXT:
#MENUITEM:Weiter:w:zwei
##ENDFORM erste

##STARTFORM zwei
#HEADER:BEISPIELFORMULAR
#HEADER:
#HEADER:Und hier gibt es auch zwei Parameter, die man
#HEADER:aendern kann.
#HEADER:
#COMMENT:Zeile 2
#VARLINE:X:x:VARX:
#VARLINE:Y:y:VARY:
#TEXT:
#MENUITEM:Zurueck:z:erste
##ENDFORM zwei

