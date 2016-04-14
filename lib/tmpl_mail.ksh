#!/bin/ksh
################################################################################
#
#	tmpl_mail
#
#	- BESCHREIBUNG
#
#	Templateskript fuer den Mailversand aus Jobketten des
#	JSS Frameworks. Dieses Script wird i.d.R. nicht direkt aufgerufen,
#	sondern nur ueber Links.
#       Neben der Templatefunktion wird auch eine Konfigurations-
#       funktion zur Verfuegung gestellt. Diese ist unter der Funktion
#       tmpl_config beschrieben.
#       Ueber den Linknamen werden die erforderlichen Konfigurations-
#       dateien ermittelt, die das weitere Vorgehen definnieren.
#       Weitere Informationen befinden sich im Header von liballg.ksh.
#
#       Parameter:
#               siehe usage Funktion
#
#       Konfigurationsparameter
#               uebergebbar ueber Kommandozeile, Konfigurationsdatei
#               auch globale Konfigurationsdatei
#               oder als uebergeordnete globale Variable.
#
#		RECIPIENTLIST	
#		MAILSUBJECT
#		MAILTEXT
#		MAILFROM
#	
#       Fehlercodes:
#               1) Einbindung liballg.ksh
#               2) Einbindung libdb.ksh
#               3) Einlesen Hauptkonfiguration
#               4) Parsen Kommandozeile
#               5) Job laeuft schon
#               6) Einbindung libjss.ksh
#               10) tmpl_mail fehlgeschlagen
#               20) Einbindung libprotokoll.ksh
#               21) initprotokoll fehlgeschlagen
#               22) finishprotokoll fehlgeschlagen
#               30) Einlesen lokale Konfiguration
#               31) Einlesen INFILE
#               99) Kein PID File bei laufendem Job
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
#		P.Fabricius	23.1.2007	Erstellung Header
#
################################################################################

################################################################################
#
#	usage
#       Gibt eine usage Meldung aus, wenn das Skript
#       mit falscher Syntax aufgerufen wurde.
#
#       Parameter:
#               keine
#
#       Fehlercodes:
#               keine
#
#       Historie:
#               P.Fabricius     23.1.2007       Erstellung Header
#
################################################################################
usage()
{
        echo "Shell-Tool ${BASENAME}"
	echo "versendet eine Mail oder legt eine Jobkonfiguration"
	echo "an."
        echo "Syntax: 	${BASENAME} [-d] [-s]"
	echo "		${BASENAME} CONFIG"
        echo
        echo "Script benoetigt eine Konfigurationsdatei ~/.jssrc"
	echo 
	echo "Optionen:"
	echo "    -d : Debugausgaben einschalten"
	echo "    -s : Konsolenausgaben einschraenken"
}

################################################################################
#
#       tmpl_config
#
#       jedes Skripttemplate soll einen eigenen Installationsmechanismus
#       haben, d.h. wenn dieses Template ohne Links mit dem Parameter
#       CONFIG aufgerufen wird, dann wird aufgrund von globalen
#       Variablen eine Konfigurationsdatei und der entsprechende Link erzeugt.
#
#       globale Variablen :
#               CFGCAT  ( default : reports ) Skriptkategorie
#               CFGIDENT Identifier des Reports ( z.B. 0011_repname )
#		MAILREC Adressatenliste
#
#	Beispiel:
#		Eine neue Konfigurationsdatei soll erzeugt
#		werden. Kategorie "reports", der Identfier ist
#		"4712_testreport"
#
#		Mit
#
#		( CFGCAT="reports" 
#		CFGIDENT="4712_testreport" 
#		export CFGCAT CFGIDENT
#		./tmpl_mail.ksh CONFIG; )
#
#		wird unter ${BASEDIR}/etc/reports 
#		eine Konfigurationsdatei 4712_testreport_mail.cfg
#		angelegt sowie unter ${BASEDIR}/bin/reports
#		ein Link 4712_testreport_mail.ksh auf tmpl_mail.ksh
#		im LIBDIR.
#		Da tmpl_mail nur eine Konfiguration und einen
#		Link braucht ist damit ein funktionsfaehiger Job
#		entstanden.
#
#	Fehlercodes:
#		201) Variable CFGIDENT nicht gesetzt
#		205) Kategorie CFGCAT nicht existent
#		206) Link existiert bereits
#
#	ToDo:
#		- alternative Variablenuebergabe
#		- Werte fuer Konfigfile aus .jssrc holen
#	
#       Historie:
#               P.Fabricius     23.1.2007       Erstellung Header
#
################################################################################
tmpl_config()
{
        typeset -i ECODE=0
        typeset FNAME

        while true ; do
                [ -z ${CFGCAT} ] && { CFGCAT="reports"; }
                [ -z ${CFGIDENT} ] && { ECODE=201; break; }

                [ ! -d ${BINDIR}/${CFGCAT} ] && { ECODE=205; break; }
                [ ! -d ${ETCDIR}/${CFGCAT} ] && { ECODE=205; break; }

                #       Link anlegen.
                #       Wenn schon eine Datei gleichen namens da
                #       ist sofort abbrechen!
                #
                [ -r ${BINDIR}/${CFGCAT}/${CFGIDENT}_mail.ksh ] && { ECODE=206; break; }
                ln -s ${LIBDIR}/tmpl_mail.ksh \
                        ${BINDIR}/${CFGCAT}/${CFGIDENT}_mail.ksh

                #       CFG Datei schreiben
                #
                FNAME=${ETCDIR}/${CFGCAT}/${CFGIDENT}_mail.cfg
		echo "RECIPIENTLIST=\"${MAILRECIPIENT}\"" > ${FNAME}
		echo "MAILSUBJECT=\"Report ${CFGIDENT}\""  >> ${FNAME}
		echo "MAILTEXT=\"Guten Tag, anbei der Report ${IDENT} MfG DWHFLEX Reportsender\"" >> ${FNAME}
		echo "MAILFROM=\"DWHFLEX Reportsender\""   >> ${FNAME}
		echo "ENCLOSURELIST=\"\${RESULTFILE}\"" >> ${FNAME}
                echo "ETLVORGANG=${EASYPLAN}" >> ${FNAME}
                echo "ETLPROTOKOLL=1" >> ${FNAME}
                echo "ETLOBJEKT=\"${CFGIDENT}, Mail\"" >> ${FNAME}
                echo "ETLSYSTEM=-" >> ${FNAME}

                break;
        done

	case ${ECODE} in 
		201) MSG="F: Variable CFGIDENT nicht gesetzt" ;;
		205) MSG="F: Kategorie CFGCAT nicht existent" ;;
		206) MSG="F: Link existiert bereits" ;;
		*) MSG="F: unbekannter Fehler" ;;
	esac

	[ ${ECODE} -ne 0 ] && { echo "${MSG}"; usage; }

        return ${ECODE}
}

################################################################################
#
#	tmpl_mail
#
################################################################################
tmpl_mail()
{
	[ ${DEBUG:-0} -eq 1 ] && set -x
	typeset -i ECODE=0
	typeset MSG=""

	log tmpl_mail "Start"

	while true ; do
                #       Mail erstellen und versenden
                #
		distrib || { ECODE=2; break; }

                #
                break
        done

        case ${ECODE} in
                0) MSG="I: ok" ;;
                2) MSG="F: Mailversendung" ;;
                *) MSG="F: unbekannter Fehler" ;;
        esac

        log tmpl_mail "${MSG}"
        log tmpl_mail "Ende mit Exitcode ${ECODE}"

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

while [ 1 -eq 1 ] ; do

	#	Basiskonfiguration einlesen
	#
	. ~/.jssrc

        #       CONFIG Modus ?
        #
        [ "X${1}" == "XCONFIG" ] && { tmpl_config; exit $?; }

	#	Allgemeine Bibliothek einbinden
	#	erst danach koennen Logeintraege geschrieben werden
	#
	. ${LIBDIR}/liballg.ksh || { EXITCODE=1; break; }
	log Main "I: liballg included"

        . ${LIBDIR}/libdb.ksh || { EXITCODE=2; break; }
        log Main "I: libdb included"

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
	parseparms "$1" "$2" "$3" "$4" "$4" "$5" "$6" "$7" "$8" "$9" "$10" "$11" "$12" || { usage; EXITCODE=4; break; }
	#parseparms $* || { usage; EXITCODE=4; break; }

        #       Darf die Verarbeitung heute laufen?
        #
        noholiday || { restoreenv; exit 42; }

        #       Wenn in der Konfiguration ein
        #       INFILE gesetzt ist, dann dieses einlesen
        #
        if [ ! -z ${INFILE} ] && [ -f ${INFILE} ] ; then
                readvarfile ${INFILE} || { EXITCODE=31; break; }
		# !!!
                #rm ${INFILE}
        fi

	runcontrol INIT || { EXITCODE=5; break; }
	tmpl_mail || { EXITCODE=10; break; }

	#
	break
done

[ ${EXITCODE} -ne 5 ] && runcontrol FINISH
finishprotokoll ${EXITCODE} || { EXITCODE=22; break; }

case ${EXITCODE} in 
	0) MSG="I: ok" ;;
	1) MSG="F: Einbindung liballg.ksh" ;;
	2) MSG="F: Einbindung libdb.ksh" ;;
	3) MSG="F: Einlesen Hauptkonfiguration" ;;
	30) MSG="F: Einlesen lokale Konfiguration" ;;
	31) MSG="F: Einlesen INFILE" ;;
	4) MSG="F: Parsen Kommandozeile" ;;
	5) MSG="F: Job laeuft schon" ;;
	6) MSG="F: Einbindung libjss.ksh" ;;
	10) MSG="F: tmpl_mail fehlgeschlagen" ;;
        20) MSG="F: Einbindung libprotokoll.ksh" ;;
        21) MSG="F: initprotokoll fehlgeschlagen" ;;
        22) MSG="F: finishprotokoll fehlgeschlagen" ;;
	99) MSG="F: Kein PID File bei laufendem Job" ;;
	*) MSG="F: unbekannter Fehler" ;;
esac

log Main "${MSG}"
[ ${NOLOG:-0} -eq 1 ] && [ ! -z ${LOGFILE} ] && [ -f ${LOGFILE} ] && rm ${LOGFILE} 2>/dev/null
exit ${EXITCODE}
