#!bash


### Set up databases

# passwords are sourced from the credentials.private file
. "$SETUPPATH/credentials.private"

mysql mysql --user=root <<EOF
CREATE USER 'skgb-web'@'localhost' IDENTIFIED BY '$MYSQL_WP_WWW_PASSWORD';
GRANT ALL PRIVILEGES ON \`skgb_web\`.* TO 'skgb-web'@'localhost';
CREATE USER 'skgb-dev'@'localhost' IDENTIFIED BY '$MYSQL_WP_DEV_PASSWORD';
GRANT ALL PRIVILEGES ON \`skgb_dev\`.* TO 'skgb-dev'@'localhost';
FLUSH PRIVILEGES;
EOF

