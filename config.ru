require './candidat'
require './config/keys.local.rb'
require 'pg'

DEBUG=(ENV['RACK_ENV']!='production')
PGHOST= DEBUG ? PGHOST_DEBUG : PGHOST

run Democratech::Candidat

