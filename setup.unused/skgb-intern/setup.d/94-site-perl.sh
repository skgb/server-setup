#!bash


[ -z "$PERLBREW_ROOT" ] && . /opt/perlbrew/etc/bashrc
export TESTING="--notest"

# some XS modules require additional packages for linking
export DEBIAN_FRONTEND=noninteractive
apt-get -y install libxml2-dev zlib1g-dev libxslt1-dev libcmark-dev
export DEBIAN_FRONTEND=
cpanm $TESTING XML::LibXML XML::LibXSLT HTML::HTML5::Parser DBD::mysql CommonMark || SETUPFAIL=942

# the pure Perl modules should be installed after the linked XS modules to make sure
# that dependencies can be properly satisfied
cpanm $TESTING Module::Metadata Module::Install Devel::StackTrace Test::More Test::Exception Test::Warnings Text::Trim String::Random HTML::Entities || SETUPFAIL=943
cpanm $TESTING Mojolicious DateTime DateTime::Format::ISO8601 Time::Date Mojo::SMTP::Client Email::MessageID || SETUPFAIL=944
cpanm $TESTING String::Util List::MoreUtils Util::Any Digest::MD5 Mojolicious::Plugin::Authorization || SETUPFAIL=945
cpanm $TESTING Perl::Version SemVer Text::WordDiff || SETUPFAIL=946
cpanm $TESTING LWP::UserAgent REST::Client Cpanel::JSON::XS Try::Tiny URI || SETUPFAIL=947
cpanm $TESTING JSON::MaybeXS Regexp::Common || SETUPFAIL=948

# Neo4j
cpanm -n LWP::Protocol::https REST::Neo4p || SETUPFAIL=949
cpanm Neo4j::Driver || SETUPFAIL=949



rm -Rf /root/.cpanm/work /root/.cpanm/latest-build /root/.cpanm/build.log
rmdir -v /root/.cpanm || true

