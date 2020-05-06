#!bash


# Install SKGB-intern

setup_copy /etc/init.d/skgb-intern.sh X

echo "Installing SKGB-intern into /srv/intern and /srv/legacy ..."
sudo -u aj -- git clone https://github.com/skgb/intern.git
sudo -u aj -- git clone https://github.com/skgb/regeln.git intern/public/regeln
sudo -u aj -- ln -s src/Stander.svg intern/public/regeln/Stander.svg
sudo -u aj -- ln -s src/regeln2html.xsl intern/public/regeln/regeln2html.xsl
tar -xf "$BACKUPSRVPATH" intern/skgb-intern.production.conf
mv intern/templates/content/stegdienstliste.html.ep intern/templates/content/stegdienstliste.html.development.ep
tar -xf "$BACKUPSRVPATH" intern/templates/content/stegdienstliste.html.ep
tar -xf "$BACKUPSRVPATH" intern/public/Merkblatt\ Datenschutz.pdf
tar -xf "$BACKUPSRVPATH" intern/public/lib
# see https://github.com/oetiker/mojolicious-plugin-reverseproxy/issues/5
tar -xvf "$BACKUPSRVPATH" intern/lib/Mojolicious/Plugin/ReverseProxy.pm

tar -xf "$BACKUPSRVPATH" Lib
tar -xf "$BACKUPSRVPATH" legacy
rm "$BACKUPSRVPATH"

setup_copy "$APACHE_DIR/sites-available/intern.conf" R
a2ensite intern
setup_copy "$APACHE_DIR/sites-available/intern1.conf" R
a2ensite intern1

apachectl configtest
apachectl graceful



### Monit
setup_copy /etc/monit/conf-available/neo4j 0600
setup_copy /etc/monit/conf-available/skgb-intern 0600
ln -s ../conf-available/neo4j /etc/monit/conf-enabled/neo4j
ln -s ../conf-available/skgb-intern /etc/monit/conf-enabled/skgb-intern
systemctl restart monit.service

# Enable LOMS
#update-rc.d skgb-intern.sh defaults
setup_copy /etc/cron.d/skgb-intern R

