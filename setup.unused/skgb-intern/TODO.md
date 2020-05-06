- SKGB-intern wird jetzt mit Monit gestartet, was an sich gut
  funktioniert. Allerdings ist das alte Init-Skript in dieser Form
  wohl nicht mehr nötig. Wir sollten es ersetzen durch ein besseres
  Monit-Service-File.

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

- /var/lib/neo4j darf nicht world-lesbar sein - Datenschutz...
