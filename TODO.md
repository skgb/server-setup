- startup script skgb-intern: funktioniert nicht zuverlässig, weil neo4j nicht sofort startet

- ssl-zertifikat mit ins backup, um expiration-Warnungen zu vermeiden.

- offsite backups

- firewall (u. a. port 3000 sperren)

- fail2ban

- monitoring

- logwatch

- Ethernet-Treiber stellt sich immer wieder von selbst auf "virtio", aber "e1000" ist "empfohlen". Warum und wieso? (Anscheinend war virtio früher empfohlen.)

- Prüfen, ob das im README beschriebene Verfahren so geändert werden kann, dass die aktuelle Version von setup.sh direkt aus dem Repository gelesen wird statt manuell mit `prep.sh` erzeugt werden zu müssen.
