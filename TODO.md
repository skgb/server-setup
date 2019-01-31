- SKGB-intern wird jetzt mit Monit gestartet, was an sich gut
  funktioniert. Allerdings ist das alte Init-Skript in dieser Form
  wohl nicht mehr nötig. Wir sollten es ersetzen durch ein besseres
  Monit-Service-File.

- Die Offsite-Backups übertragen täglich *alle* Daten, rund 2 GB.
  Das ließe sich sicher mit `rsync` erheblich verbessern.

- firewall: eigentlich nicht noetig (würde nicht schaden, aber...)

- apply <https://stribika.github.io/2015/01/04/secure-secure-shell.html>

- email -> möglichst extern, zb Mailbox.org als MX

- fail2ban
(kann u. U. auf logzeilen reagieren)

- monitoring

- logwatch -> nein, lieber greylog

- Prüfen, ob das im README beschriebene Verfahren so geändert werden kann, dass die aktuelle Version von setup.sh direkt aus dem Repository gelesen wird statt manuell mit `prep.sh` erzeugt werden zu müssen.

- brauchen wir wirklich einen root-server? wenigstens das wordpress wäre leicht runterzuziehen

- nextcloud: kalender, adressbuch für mitgliedervwealtung evtl., dokuemnte live bearbeiten (collabora - braucht java) = google docs, dropbox-ersatz

- mögliche Alternativen zu `setup.sh`: Ansible oder Chef; siehe auch:
<https://downloads.chef.io/chefdk>
<https://github.com/mattstratton/sa2017-app>
<https://sysadvent.blogspot.com/2017/12/day-2-shifting-left-securely-with-inspec.html>

- Ulf: backports sind nicht schlimm, kein grund schnell zu wechseln, gerne paar monate warten, oder auch länger

- Git-Repo: könnte bei Bedarf via <https://gogs.io/> zugänglich gemacht werden

- Service script `skgb-intern.sh` braucht hart gecodete Perl-Version.
  Um dies zu umgehen, die fuer SKGB-intern zu verwendende Perl-Version
  in eine eigene Datei schreiben (z. B. `/opt/perlbrew/skgb-intern`)
  und dann diese Datei als Quelle sowohl in `setup.sh` als auch in
  `skgb-intern.sh` verwenden. Es waere dann auch moeglich, die
  Perl-Installation aus `setup.sh` in ein eigenes Skript auszulagern,
  um so Updates machen zu koennen. Bis dahin koennte als Workaround
  evtl. `/root/.perlbrew/init` von `skgb-intern.sh` eingelesen werden.
  (Langfristig sollte evtl. auch `root` nicht dasselbe Perl nutzen wie
  SKGB-intern...?)

- Das Reverse-Proxy-Setup für SKGB-intern erzeugt komische 502-Fehler,
  wenn innerhalb von Mojolicious bestimmte Fehler auftreten. Beispiel:
  in `neo4j.get_persons` Aufruf von `$c->neo4j->run_graph` ändern in
  `$c->run_graph` (was nicht existiert). An dieser konkreten Stelle
  wird der Fehler nur über HTTPS getriggert, weil man dazu eingeloggt
  sein muss. Baut man dagegen den Aufruf einer nicht existierenden
  Methode in `execute_memory` ein, kommt die erwartete individuelle
  500er Seite. Sieht irgendwie nach einem Problem in Mojolicious aus...

- In Apache-config www: IE8/XP in HTTP-Whitelist aufnehmen (unterstützt
  weder SNI noch Wildcard-Zertifikate, von TLS 1.3 gar nicht zu reden...)

