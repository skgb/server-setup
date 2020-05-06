TODO (SKGB-Server)
==================

- Brauchen wir wirklich einen Root-Server? Zwar wäre wenigstens das
  Wordpress leicht runterzuziehen, aber es ist tlws. abhängig von
  anderen Diensten (z. B. existieren einige `<img>`- und `<a>`-Elemente
  mit URLs von anderen, statischen SKGB-Hosts auf diesem Server).
  Es müsste zumindest mal sichergestellt sein, dass diese Dienste
  entweder mit umgezogen werden oder aber dass die Inhalte/Themes in
  Wordpress entsprechend geändert werden (kaputte interne Links sind
  *niemals* akzeptabel, egal wie alt die WP-Artikel vielleicht sind).
  Der damit verbundene Aufwand ist überschaubar, aber wahrscheinlich
  vorerst deutlich größer, als mit Hilfe dieses Skripts einfach den
  Root-Server am Laufen zu halten.

- Mailserver: `message_size_limit` überdenken. Wenn eh in der Regel
  alles über die Privatadressen des Vorstands läuft, dann brauchen
  wir hier auch kein großes Limit mehr, sondern gut 1 MiB reichen
  tatsächlich aus; bleiben hingegen die @skgb.de-Adressen als
  Hauptkommunikation erhalten, dann sollten ausnahmsweise Anhänge
  bis 2-4 MiB möglich sein. (Base64-Faktor nicht vergessen.)

- Mailserver: TLS einrichten; siehe <http://www.postfix.org/TLS_README.html>
  (bereits erledigt für `galway.johannessen.de`; Config lässt sich leicht übertragen)

- SPF (+ evtl. DKIM) implementieren und Domain-Validierung für eintreffende
  Mails aktivieren (Voraussetzung für späteres Aktivieren von IPv6 für den
  Mailserver, denn Blacklists funktionieren nicht gut mit IPv6); siehe auch:
  <https://sendgrid.com/blog/where-is-ipv6-in-email/>
  <https://labs.ripe.net/Members/mirjam/sending-and-receiving-emails-over-ipv6>

- Die Offsite-Backups übertragen täglich *alle* Daten, rund 2 GB.
  Das ließe sich sicher mit `rsync` erheblich verbessern.

- In Apache-config www: IE8/XP in HTTP-Whitelist aufnehmen (unterstützt
  weder SNI noch Wildcard-Zertifikate, von TLS 1.3 gar nicht zu reden...)

- In Apache-config TLS-Einstellungen überprüfen und modernisieren; ggf.
  weitere veraltete Clients aufgeben und in die HTTP-Whitelist aufnehmen

- apply <https://stribika.github.io/2015/01/04/secure-secure-shell.html>

- fail2ban?
(kann u. U. auf logzeilen reagieren)

- logwatch? -> nein, lieber greylog

- nextcloud: kalender, adressbuch für mitgliedervwealtung evtl.,
  dokumente live bearbeiten (collabora - braucht java) = google docs,
  dropbox-ersatz

