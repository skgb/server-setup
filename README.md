Rettungskonzept für den Vereinsserver
=====================================

Sollte es auf dem Vereinsserver zu einer erheblichen Störung kommen,
wird einfach der Server komplett plattgemacht, neu aufgesetzt und ein
Backup eingespielt. Das Skript `setup.sh` bringt den Server in einen
definierten Zustand. Der Server ist danach sofort einsatzbereit.

Um aktuell zu bleiben, müssen alle Konfigurationsänderungen am Server
auch im Repository gespiegelt werden.

Nach zwischenzeitlichen Änderungen der eingesetzten Software
(insbesondere Major Updates der OS-Distribution) kann es Ärger geben.
Es ist deshalb ratsam, dieses Skript gelegentlich zu testen,
vorzugsweise auf einem anderen VPS. Hilfsweise ließe sich der Server
gelegentlich absichtlich einreißen und neu aufsetzen. Probleme mit
`setup.sh` fallen dann rechtzeitig auf und können z. B. in einem
geplanten Wartungsfenster behoben werden.


Setup des Servers
=================

Konzeptuell sind die folgenden Schritte notwendig:

1.	Wartung dem Vorstand ankündigen. Soweit möglich, `setup.sh` prüfen,
	testen und aktualisieren.

2.	Sicherstellen, dass ein aktuelles Offsite-Backup vorhanden ist und
	beim Setup *schnell* zur Verfügung steht (eine lokale Kopie, die
	über einen lahmen Telekom-ADSL-Upstream hochgeladen werden soll,
	ist keine Lösung). Benötigt wird folgendes:
	- `setup.tar` – Export dieses Repositories (via `prep.sh`)
	- `credentials.private` – Passwörter für Serverdienste etc.
	- `backup.tar` – Backup der Datenbanken etc.
	- `srv.tar` – Backup der Server-Files von `/srv`

3.	Sicherstellen, dass gerade keine Nutzer auf dem Server arbeiten.
	Server im [Control Panel][] stoppen (`Steuerung` → `Erzwungen
	abschalten`), neues Image aufspielen (`Medien` → `Images` →
	`Debian 10` → `Minimal` → `große Partition`).
	
	*Keine* E-Mail bestellen (sie enthielte das `root`-Passwort).
	Das evtl. geforderte "SCP Login Passwort" ist das vom Server
	Control Panel und *nicht* das SSH-`root`-Passwort.

4.	Fingerabdrücke des SSH-Host-Keys prüfen. Falls diese nicht direkt
	im Control Panel angezeigt werden, kann das Skript `hostkeys.sh`
	in der VNC-Konsole ausgeführt werden.

4.	`setup.sh` ausführen. Dies nimmt nur noch wenig Zeit in Anspruch,
	da inzwischen perlbrew entfällt. Nach gut 3 Min. sollte also alles
	erledigt sein.

5.	Server kalt neustarten (ausloggen, im [Control Panel][] `Steuerung`
	→ `Erzwungen abschalten` + `Starten`). Der kalte Neustart wird
	[angeblich](http://www.netcup-wiki.de/wiki/Zus%C3%A4tzliche_IP_Adresse_konfigurieren#IPv6)
	für manche Server-Typen benötigt, um sicherzustellen, dass IPv6
	funktioniert.

6.	Gründlich testen, Offsite-Backups einrichten, Aufräumen nach Bedarf.

Nach der Neuinstallation ist das Wordpress erst mal im Wartungsmodus.
Um den zu beenden, einfach in `/srv/www/htaccess_www.conf` die 503er
Redirects auskommentieren.


Beispiel eines Setup-Laufs
--------------------------

Das folgende Beispiel zeigt, wie eine Terminal-Sitzung für `setup.sh`
für `solent.skgb.de` aussehen könnte. Genau diese Befehle mögen
sich für einen konkreten Einsatzfall eignen oder auch nicht.

````bash
ssh-keygen -R solent.skgb.de
ssh-keygen -R 85.235.65.80
ssh-keygen -R 2a03:4000:32:15d::5c6b
scp ~/.ssh/id_rsa.pub root@solent.skgb.de:/root/.ssh/authorized_keys

setup.global/prep.sh .
scp setup.tar root@solent.skgb.de:
scp credentials.private root@solent.skgb.de:
scp backup.tar root@solent.skgb.de:
ssh root@solent.skgb.de

# auf dem Server:

tar -xf setup.tar --no-same-owner --no-same-permissions
mv credentials.private setup
mv backup.tar setup
wget http://backupsource.example/srv.tar -O setup/srv.tar

nohup setup/setup.sh 2>&1 | tee setup.log.txt
# Die Nutzung von nohup ist nur möglich, weil während setup.sh
# keine Backup-Passwörter o. ä. mehr eingegeben werden müssen.

reboot
````


Manuelles Ausführen
-------------------

Das manuelle Ausführen einzelner Skripte in `setup.d` ist möglich.
Dazu müssen im Allgemeinen die im Folgenden genannten Variablen und
Werkzeuge in der Umgebung bereitgestellt werden. Hinzu kommen ggf.
weitere Variablen, welche das jeweilige Skript erwartet.

````bash
HOSTNAME_VPS=solent.skgb.de
SETUP_DNS_A=85.235.65.80
SETUP_DNS_AAAA=2a03:4000:32:15d::5c6b
. /root/setup/setup.global/setup.tools
SETUPPATH=/root/setup
````


Weiterverwendung
----------------

Dieses Repository enthält zwar keine Passwörter o. ä., aber allerlei
Besonderheiten für den SKGB-Server. Es ist daher nicht zur
Weiterverwendung geeignet.

[setup.sh][] wurde von Arne Johannessen geschrieben und darf ohne
Restriktionen weiterverwendet werden.


[Control Panel]: https://www.servercontrolpanel.de/
[setup.sh]: https://github.com/johannessen/setup.sh
