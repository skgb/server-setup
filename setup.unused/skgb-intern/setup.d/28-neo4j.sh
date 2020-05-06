#!bash


# make Neo4j available in apt sources
apt-get -y install gnupg wget  # these should be installed by default, making this a no-op
wget -O - https://debian.neo4j.org/neotechnology.gpg.key | apt-key add -  # Import Neo4j signing key
setup_copy /etc/apt/sources.list.d/neo4j.list R
apt-get update
apt-get -y install neo4j
#apt-get install neo4j=2.3.6
#apt-mark hold neo4j
setup_copy /etc/security/limits.d/neo4j R
setup_copy /root/neo4j-import.sh X
service neo4j stop
# see <http://github.com/neo4j-contrib/neo4j-apoc-procedures/releases>
(cd /var/lib/neo4j/plugins ; wget -nv http://github.com/neo4j-contrib/neo4j-apoc-procedures/releases/download/3.5.0.1/apoc-3.5.0.1-all.jar)
setup_patch /etc/neo4j/neo4j.conf
service neo4j start
systemctl enable neo4j.service


# passwords are sourced from the credentials.private file
. "$SETUPPATH/credentials.private"

curl -iH "Content-Type: application/json" -X POST -d "{\"password\":\"$NEO4J_PASSWORD\"}" -u neo4j:neo4j http://localhost:7474/user/neo4j/password

