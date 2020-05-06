#!bash


### Apache

# prep dirs

cd /srv

SRV_LIST_WP="www dev"
SRV_LIST_STATIC="archiv servo"
SRV_LIST_FULL="$SRV_LIST_WP $SRV_LIST_STATIC"
mkdir $SRV_LIST_FULL
chown www-data:www-data $SRV_LIST_WP
chown aj:www-data $SRV_LIST_STATIC
chmod 2755 $SRV_LIST_FULL
chmod 2775 $SRV_LIST_STATIC



# Wordpress

setup_wordpress () {
  sudo -u www-data -- wp "--path=$1" core download --locale=de_DE
  WP_CONFIG="wp-config_${1}.php"
  tar -xvf "$BACKUPSRVPATH" "$1/$WP_CONFIG"
  ln -s "$WP_CONFIG" "$1/wp-config.php"
  WP_HTACCESS="htaccess_${1}.conf"
  setup_copy "/srv/$1/$WP_HTACCESS" R
  #tar -xf "$BACKUPSRVPATH" "$1/$WP_HTACCESS"
  ln -s "$WP_HTACCESS" "$1/.htaccess"
  
  # these git commands have some filesystem permission issue when run as user aj...
  git -C "$1/wp-content/plugins" clone https://github.com/skgb/wordpress-plugin.git skgb-web
  sudo -u www-data -- wp "--path=$1" plugin install https://github.com/johannessen/bhcalendarchives/archive/master.zip --activate
  sudo -u www-data -- wp "--path=$1" plugin install https://littoral.michelf.ca/code/php-markdown/php-markdown-extra-1.2.8.zip --activate
  sudo -u www-data -- wp "--path=$1" plugin install parsedown-wp
  sudo -u www-data -- wp "--path=$1" plugin install classic-editor --activate
  sudo -u www-data -- wp "--path=$1" plugin install classic-editor-addon --activate
  sudo -u www-data -- wp "--path=$1" plugin install remove-generator-tag-for-wordpress
  sudo -u www-data -- wp "--path=$1" plugin install pjw-page-excerpt
  sudo -u www-data -- wp "--path=$1" plugin install wp-db-backup
  sudo -u www-data -- wp "--path=$1" plugin uninstall akismet || true
  sudo -u www-data -- wp "--path=$1" plugin uninstall hello-dolly || true
  sudo -u www-data -- wp "--path=$1" plugin uninstall hello || true
  git -C "$1/wp-content/themes" clone https://github.com/skgb/wordpress-theme-4.git skgb4
  git -C "$1/wp-content/themes" clone https://github.com/skgb/wordpress-theme-5.git skgb5
  sudo -u www-data -- wp "--path=$1" theme install twentyten
  sudo -u www-data -- wp "--path=$1" theme activate skgb5
}

echo "Installing Wordpress into /srv/www ..."
tar -xf "$BACKUPSRVPATH" www/XML www/uploads
chown -R www-data:www-data /srv/www/uploads
setup_wordpress www

echo "Installing Wordpress into /srv/dev ..."
echo
echo "(There might be lots of warnings below; these are generally harmless.)"
echo
cp -R www/XML dev/XML
cp -R www/uploads dev/uploads
setup_wordpress dev
setup_copy /srv/dev/robots.txt R
echo
echo "(There might be lots of warnings above; these are generally harmless.)"
echo

chmod -R g+w $SRV_LIST_WP
rm -f /var/www/.wp-cli/cache/core/wordpress-*.tar.gz /var/www/.wp-cli/cache/plugin/*.zip

setup_copy "$APACHE_DIR/sites-available/www.conf" R
setup_copy "$APACHE_DIR/sites-available/www.include" R
setup_copy "$APACHE_DIR/sites-available/wwwdev.include" R
a2ensite -q www



# static sites

echo "Installing /srv/archiv and /srv/servo ..."
#sudo -u aj -- git clone https://github.com/skgb/web-static.git archiv
tar -xf "$BACKUPSRVPATH" archiv servo

setup_copy "$APACHE_DIR/sites-available/archiv.conf" R
a2ensite -q archiv
setup_copy "$APACHE_DIR/sites-available/servo.conf" R
setup_copy "$APACHE_DIR/sites-available/servo.include" R
a2ensite -q servo
setup_copy "$APACHE_DIR/sites-available/skgb.conf" R
a2ensite -q skgb

setup_copy "$APACHE_DIR/sites-available/intern-eol.conf" R
a2ensite -q intern-eol



# SKGB-intern

# no longer in service

# However, we keep the legacy site (intern 1.x branch) in /srv for now
# because it contains a sizable media archive that may be useful later.
tar -xf "$BACKUPSRVPATH" legacy



# cleanup

apachectl configtest
apachectl graceful

rm "$BACKUPSRVPATH"

# TODO: make sure that the ownership is correct:
# WP selfupdate should work with GROUP www-data, but seems to in fact need OWNER www-data
# everything else needs GROUP www-data
#chgrp -R www-data /srv/Default
# (historically, skgb-web is equivalent)

