#!bash


# apt-cache policy certbot
# apt-get install python-setuptools=20.10.1-1.1~bpo8+1 python-pkg-resources=20.10.1-1.1~bpo8+1


# passwords are sourced from the credentials.private file
. "$SETUPPATH/credentials.private"

# Let's Encrypt wildcard certs require DNS validation
curl -LO "https://github.com/kegato/letsencrypt-inwx/releases/download/2.0.2/letsencrypt-inwx-x86_64-linux.deb"
DEBIAN_FRONTEND= \
dpkg -i letsencrypt-inwx-x86_64-linux.deb
rm -f letsencrypt-inwx-x86_64-linux.deb
setup_copy /etc/letsencrypt-inwx.json 600
sed -e "s/password\": null/password\": \"$SKGB_INWX_PASSWORD\"/" -i /etc/letsencrypt-inwx.json

# If we ever need an alternative to the above solution, check out:
# https://github.com/oGGy990/certbot-dns-inwx
# or maybe acme.sh?
# or we could go back to hosting the primary NS ourselves using BIND, see clydesetup
# or we could go back to explicit hostnames in the cert, see setup.manual/letsencrypt.sh


setup_copy /etc/apache2/sites-available/ssl-wildcard.include R


echo "Preparing SSL (with self-signed certificate) ..."
setup_copy /etc/ssl/skgb/dummy-config R
openssl req -config /etc/ssl/skgb/dummy-config -x509 -newkey rsa -days 1 -nodes -out /etc/ssl/skgb/dummy-cert.pem
ln -s dummy-cert.pem /etc/ssl/skgb/fullchain.pem
ln -s dummy-key.pem /etc/ssl/skgb/privkey.pem

# Actually, the self-signed certificate is no longer really necessary,
# as we'll restore our existing CA-signed certificate from backup
# before starting Apache.

