setup.sh
========


Problem
-------

Server Aufsetzen ist zeitaufwändig und fehleranfällig.


Ausgangslage
------------

- Dienste der SKGB lagen bisher u. a. auf manuell administrierten
  Debian-Servern.

- Dieselben server dienen teils auch anderen, privaten Zwecken und
  es wird immer wieder mal gebastelt und gefummelt.

- Testserver und Liveserver scharf zu trennen war und ist kostenmäßig
  nicht attraktiv.

- Die config-Dateien können schlecht alle in ein offenes Repository
  gelegt werden, weil sie Passwörter u. ä. enthalten.


Konflikte
---------

- Container-Lösungen erscheinen wie Overkill, benötigen Einarbeitung
  und erzeugen neue Abhängigkeiten und womöglich gar Vendor–Lock-in.

- Ein eigenes Skript zum Aufsetzen der Serverumgebung erscheint
  zerbrechlich und birgt Risiken durch NIH.

- Eigenes Skript ist möglicherweise agiler in Bezug auf OS-Updates,
  weil die Konfiguration sich näher am Distro-Default orientieren
  kann, was gerade dann vorteilhaft sein kann, wenn man z. B. für
  Mojo eher neue Software-Versionen braucht; andererseits ist die
  Konfiguration weniger deterministisch und damit fragiler, wenn
  mehr Defaults übernommen werden.

- Manuelle Änderungen am Server auf Zuruf (z. B. E-Mail in
  `/etc/aliases` ändern o. ä.) müssen immer auch im Repository für
  das eigene Skript vollzogen werden. Weil dieses Skript aber für
  diese Änderungen nicht nötig ist, wird das leicht vergessen.

- Passwörter u. ä. müssen so oder so auf eine Art und Weise abgelegt
  werden, in der sie kontrolliert werden können, sollten also wohl
  „irgendwie“ extern geladen werden.

- Transiente Daten wie Datenbanken oder Uploads liegen so oder so
  nicht in einem Repository. Ließe sich deren Einspielen aus einem
  Backup über Docker o. ä. automatisieren, oder braucht man auf
  jeden Fall ein eigenes Setup-Skript dafür?


Vorschlag
---------

- Eigenes Skript, das config-Dateien aus einem (evtl. privaten)
  Repository kopiert.

- Passwörter sollten möglichst aus einer externen Datei eingelesen
  oder neu erzeugt werden.

- Server-Dienste werden vom Skript automatisch aufgesetzt,
  insbesondere auch Dateien unter `/srv` kopiert.

- Backups der Datenbanken usw. werden vom Skript automatisch
  eingespielt.

- Notfall-Strategie: (1) System plattmachen, (2) `setup.sh` laufen
  lassen, (3) fertig.

- Wir brauchen keine 100 % Uptime, und `setup.sh` stellt mit guten
  Backups einen definierten Zustand her.
