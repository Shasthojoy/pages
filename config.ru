require './candidat'
require './config/keys.local.rb'
require 'pg'
Democratech::Candidat.db=PG::Connection.open(:dbname=>DBNAME,"user"=>DBUSER,"sslmode"=>"require","password"=>DBPWD,"host"=>DBHOST)
run Democratech::Candidat

