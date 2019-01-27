- startup script skgb-intern: funktioniert nicht zuverlässig, weil neo4j nicht sofort startet
-> monit machen lassen

- ssl-zertifikat mit ins backup, um expiration-Warnungen zu vermeiden.

- backups des providers?
-> ideal, um *schnell* wieder an den start zu gehen: automatische tägliche snapshots zusätzlich, als havarieschutz

* offsite backups

* Backups reparieren (neuer Schlüssel)

- firewall: eigentlich nicht noetig (würde nicht schaden, aber...)

- port 3000 sperren -> kann Mojo statt auf 0.0.0.0 auf 127.0.0.1 gebunden werden?
<https://www.google.de/search?q=bind+mojolicious+to+ip>

- joe: /etc/joe/joerc

- email -> möglichst extern, zb Mailbox.org als MX

- fail2ban
(kann u. U. auf logzeilen reagieren)

- monitoring

- logwatch -> nein, lieber greylog

- Ethernet-Treiber stellt sich immer wieder von selbst auf "virtio", aber "e1000" ist "empfohlen". Warum und wieso? (Anscheinend war virtio früher empfohlen.)

- Prüfen, ob das im README beschriebene Verfahren so geändert werden kann, dass die aktuelle Version von setup.sh direkt aus dem Repository gelesen wird statt manuell mit `prep.sh` erzeugt werden zu müssen.

- brauchen wir wirklich einen root-server? wenigstens das wordpress wäre leicht runterzuziehen

- nextcloud: kalender, adressbuch für mitgliedervwealtung evtl., dokuemnte live bearbeiten (collabora - braucht java) = google docs, dropbox-ersatz

- mögliche Alternativen zu `setup.sh`: Ansible oder Chef; siehe auch:
<https://downloads.chef.io/chefdk>
<https://github.com/mattstratton/sa2017-app>
<https://sysadvent.blogspot.com/2017/12/day-2-shifting-left-securely-with-inspec.html>

- Ulf: backports sind nicht schlimm, kein grund schnell zu wechseln, gerne paar monate warten, oder auch länger

- Git-Repo: könnte bei Bedarf via <https://gogs.io/> zugänglich gemacht werden
