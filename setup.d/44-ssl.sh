#!bash


### SSL

if [ -f /etc/letsencrypt/live/skgb.de/fullchain.pem ] ; then
  echo "Let's Encrypt is available; switching out certificate links ..."
  rm -f /etc/ssl/skgb/fullchain.pem /etc/ssl/skgb/privkey.pem
  ln -vs /etc/letsencrypt/live/skgb.de/fullchain.pem /etc/ssl/skgb/fullchain.pem
  ln -vs /etc/letsencrypt/live/skgb.de/privkey.pem /etc/ssl/skgb/privkey.pem
else
  echo "Error with Let's Encrypt."
  echo "*** Using self-signed certificate! ***"
  SETUPFAIL=443
fi

