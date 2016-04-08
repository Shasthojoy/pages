require './candidat'
require './config/keys.local.rb'
require 'pg'

DEBUG=(ENV['RACK_ENV']!='production')
PRODUCTION=(ENV['RACK_ENV']=='production')
PGPWD=DEBUG ? PGPWD_TEST : PGPWD_LIVE
PGNAME=DEBUG ? PGNAME_TEST : PGNAME_LIVE
PGUSER=DEBUG ? PGUSER_TEST : PGUSER_LIVE
PGHOST=DEBUG ? PGHOST_TEST : PGHOST_LIVE


run Democratech::Candidat

