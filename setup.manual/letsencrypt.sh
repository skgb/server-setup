#! /bin/bash

# Obtain a CA-signed SSL certificate

echo "Do not execute this file!"
echo "Copy-paste just those lines actually required for your current needs."
exit 1



### Wildcard certificate (default)

certbot certonly --non-interactive --agree-tos --email webmaster+le@skgb.de \
--dry-run \
--preferred-challenges=dns-01 \
--manual --manual-public-ip-logging-ok \
--manual-auth-hook /usr/lib/letsencrypt-inwx/certbot-inwx-auth \
--manual-cleanup-hook /usr/lib/letsencrypt-inwx/certbot-inwx-cleanup \
--domain skgb.de \
--domain *.skgb.de



### Testing

# check the validation, but don't create new certificates
--dry-run \

# staging server; creates invalid certificates
--test-cert \

# manual test of INWX's API
letsencrypt-inwx create -c /etc/letsencrypt-inwx-cred -d _acme-challenge-test.skgb.de -v acme_token-test
letsencrypt-inwx delete -c /etc/letsencrypt-inwx-cred -d _acme-challenge-test.skgb.de



### Explicit hostnames instead of wildcard

# The wildcard certificate depends upon modifying the DNS zone. As SKGB
# uses an external DNS provider (INWX), future changes to their API might
# potentially cause wildcard certificate renewal to fail. Rather than
# trying to debug and solve such an issue, it might be preferable to switch
# back to a non-wildcard certificate that explicitly lists all hostnames
# as SANs.

# This requires that all of the DNS names listed actually point to this
# server, and that this server actually responds to all of the IPs.

# Note that simply creating such an additional certificate for the domain
# skgb.de will cause certbot to use a different name for the certificate:
# Instead of the default name 'skgb.de' (which is already taken), a name
# like 'skgb.de-0001' will be used. Because the backup scripts as well as
# Apache are configured to use the paths for 'skgb.de', you will need to
# clean this up manually if you're not careful. Probably the best way to
# avoid this is to clear /etc/letsencrypt completely before requesting the
# new certificate. That way, the paths should end up being as expected, and
# if you're switching away from the existing certificates you won't actually
# be needing any of the old files.
# The command `certbot certificates` may help you debug this situation.

certbot certonly --non-interactive --agree-tos --email webmaster+le@skgb.de \
--dry-run \
--authenticator apache \
--domain skgb.de \
--domain solent.skgb.de \
--domain intern.skgb.de,intern2.skgb.de,i.skgb.de \
--domain archiv.skgb.de,a.skgb.de \
--domain cloud.skgb.de,office.skgb.de \
--domain dev.skgb.de,d.skgb.de \
--domain ip6.skgb.de \
--domain servo.skgb.de \
--domain www.skgb.de



### TODO:

#Does this option make sense?

--must-staple \
#Adds the OCSP Must Staple extension to the
#certificate. Autoconfigures OCSP Stapling for
#supported setups (Apache version >= 2.3.3 ).

