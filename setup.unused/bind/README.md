Hinweise zum DNS
================

- <https://www.denic.de/fileadmin/public/documentation/DENIC-23p.pdf>

- <https://www.denic.de/service/tools/nast/>

- Bei einigen ISPs müssen <a href=http://de.wikipedia.org/wiki/NS_Resource_Record#Zonendelegation>Glue-Records</a> manuell eingerichtet werden (da diese ja nicht im Zone File definiert werden), andere ISPs machen das automatisch im Zusammenhang mit der Festlegung des externen Nameservers.



TTL-Überlegungen
----------------

(Zielvorstellung; im Moment ist noch Bastelphase)

`$TTL 24h` diese Zone ist im Allgemeinen stabil (außer natürlich bei Änderungen), folglich sind die TTL auch eher lang

`@ 6h IN SOA`  
`6h ; slave refresh` stabile Zone, aber Slave Refresh nicht zu selten, um im Falle von Änderungen nicht *zu* lange warten zu müssen; dank AXFR *sollte* dieser Wert aber eigentlich sowieso nicht relevant sein

`80m ; slave retry` sollte laut DENIC 1/8 bis 1/3 von `refresh` betragen, damit "die Umschaltlogik überhaupt zu einem nennenswerten Vorteil führen kann"

`40d ; slave expire` extrem lang, damit kein Zeitdruck bei der Problemlösung besteht, falls ich den Primary aus irgendeinem Grund ernsthaft rotte und nicht wieder in Gang bekommen sollte

`45m ; minimum TTL for failed lookups` für diese stabile Zone eigentlich recht kurz, aber dummerweise neige ich dazu, vor dem Hinzufügen neuer Records diese noch vor dem Eintragen in die Zone lokal abzufragen und mir so den DNS-Cache mit NXDOMAIN zu vergiften

`@ 2d NS`  
`@ 2d MX`  
`clyde 2d A` besonders lang für einige der wichtigsten Records (NB: einige Bind-Versionen scheinen ein Maximum von `2d` zu erlauben)
