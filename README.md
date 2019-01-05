Rettungskonzept für den Vereinsserver
=====================================

Sollte es auf dem Vereinsserver zu einer erheblichen Störung kommen,
wird einfach der Server komplett plattgemacht, neu aufgesetzt und ein
Backup eingespielt. Das Skript `setup.sh` bringt den Server in einen
definierten Zustand. Der Server ist danach sofort einsatzbereit.

In der Praxis wird allerdings `setup.sh` zu selten eingesetzt, als dass
es sehr verlässlich funktionieren könnte. Um aktuell zu bleiben, müssen
alle Konfigurationsänderungen am Server auch im Repository in `setup.sh`
gespiegelt werden, was dann aber oft nicht sofort getestet wird.
Außerdem kommt es immer wieder durch Upstream-Änderungen in Debian oder
anderer genutzter Software zu Problemen. `setup.sh` bricht dann u. U.
mit einer Fehlermeldung ab oder richtet Blödsinn an. Die Ausgabe sollte
deshalb vorsichtshalber mit `tee` in eine Datei kopiert und sorgfältig
auf Fehler geprüft werden.

Um diese Probleme möglichst klein zu halten, ist es ratsam, den Server
gelegentlich absichtlich einzureißen und neu aufzusetzen. Probleme mit
`setup.sh` fallen dann rechtzeitig auf und können z. B. in einem
geplanten Wartungsfenster behoben werden.

Insgesamt dauert der ganze Vorgang locker eine knappe Stunde.

Alles in allem lässt die Qualität von `setup.sh` durchaus zu wünschen
übrig: „quick and dirty“ und so. Aber es scheint erst mal gut genug zu
funktionieren. Nichtsdestotrotz sind Verbesserungsvorschläge gerne
erwünscht.



Setup des Servers
=================

1.	Wartung dem Vorstand ankündigen. Soweit möglich, `setup.sh` prüfen
	und aktualisieren.

1.	Lokalen Export dieses Repositories anlegen:
	```bash
	git clone ssh://git@clyde.skgb.de/srv/git/clyde-setup.git clydesetup
	clydesetup/prep.sh
	
	```
	
	Falls der Server nicht online ist, muss auf ein Backup zurückgegriffen
	werden. Es ist empfehlenswert, eine lokale Arbeitskopie des Repositories
	immer aktuell zu haben (also regelmäßig zu `pull`en).

1.	Sicherstellen, dass ein aktuelles Offsite-Backup vorhanden ist und
	beim Setup *schnell* zur Verfügung steht (eine lokale Kopie, die
	über einen lahmen Telekom-ADSL-Upstream hochgeladen werden soll,
	ist keine Lösung). Benötigt wird folgendes:
	- `clydesetup.tar` – Export dieses Repositories
	- `setup.private` – Passwörter für Serverdienste etc.
	  (`/root/clydesetup/setup.private`)
	- `backupkey.private` – privater PGP-Schlüssel für `clydebackup.tar`
	  (`/root/.gnupg/EF330646-sec.asc`)
	- die Passphrase für diesen Schlüssel
	- `clydebackup.tar` – Backup der Datenbanken etc.
	- `clydesrv.tar.gz` – Backup von `/srv`

1.	Sicherstellen, dass gerade keine Nutzer auf dem Server arbeiten.
	Server im Control Panel stoppen (`Steuerung` → `Erzwungen abschalten`), neues
	Image aufspielen (`Medien` → `Images` → `Debian 9` → `Minimal` → `große
	Partition`).
	
	*Dauer: ca. 4 Min.*

1.	Anmelden als `root` über SSH und Passwort ändern:
	```bash
	passwd
	
	```
	
	Wenn nötig, zuvor alte Host-Keys lokal löschen:
	```bash
	ssh-keygen -R solent.skgb.de
	ssh-keygen -R 85.235.65.80
	
	```

1.	Export dieses Repositories in `/root/clydesetup` anlegen:
	```bash
	cd /root
	tar -xf clydesetup.tar --no-same-owner --no-same-permissions
	rm clydesetup.tar
	
	```
	
	Außerdem die unter 1. gelisteten weiteren Dateien nach
	`/root/clydesetup` kopieren:
	```bash
	scp clydebackup.tar root@solent.skgb.de:clydesetup
	scp clydesrv.tar.gz root@solent.skgb.de:clydesetup
	
	```

1.	Anmelden als `root` über die VNC-Konsole, um die Fingerabdrücke
	der SSH-Host-Keys ausgeben zu lassen und zu prüfen:
	```bash
	cd clydesetup
	source hostkeys.sh
	
	```
	
	Ansonsten wird die VNC-Konsole nicht benötigt.

1.	Über SSH das Setup-Skript ausführen:
	```bash
	/root/clydesetup/setup.sh 2>&1 | tee setup.log.txt
	
	```
	
	Dieser Schritt nimmt viel Zeit in Anspruch (rund 35 Min.). Nach etwa
	4 Min. sollte jedoch bis auf Perl alles erledigt sein, so dass alle
	Haupt-Dienste des Servers (www, Mail, DNS) theoretisch schon
	weitgehend laufen sollten.
	
	Das Skript erwartet nur wenige Nutzerinteraktionen:
	- `apt-get install` bestätigen *(wenige Sekunden nach Start)*
	- Passphrase des Backup-Schlüssels eingeben *(etwa 3 Min. nach Start)*
	- CPAN-Konfiguration *(etwa 18 Min. nach Start)*

1.	Server kalt neustarten (ausloggen, im Control Panel `Steuerung` →
	`poweroff` + `start`). Der kalte Neustart wird [angeblich](http://www.netcup-wiki.de/wiki/Zus%C3%A4tzliche_IP_Adresse_konfigurieren#IPv6)
	benötigt, um sicherzustellen, dass IPv6 funktioniert.

1.	Fertig.
	
	Keine Fehler aufgetreten? Puuh … dann jetzt Server neu starten
	und **gründlich testen!**

1.	Anmelden als normaler User über SSH. **SKGB-intern 2 manuell
	starten** (die Automatik funktioniert noch nicht):
	```bash
	sudo /etc/init.d/skgb-intern.sh start
	
	```



Troubleshooting
===============

Wenn unerwartete Probleme auftreten, dann gerne beim Bauen von Perl.
Dies ist absichtlich einer der letzten Schritte in `setup.sh`, damit nun
ohne allzu große Schwierigkeiten die noch fehlenden Schritte manuell aus
dem Quellcode von `setup.sh` einzeln in der Shell ausgeführt und debuggt
werden können.
