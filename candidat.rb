require 'sinatra/base'
require 'sinatra/reloader'
require 'open-uri'

module Democratech
	class Candidat < Sinatra::Base
		class << self
			attr_accessor :db
		end

		def self.db_close
			if Candidat.db then
				Candidat.db.flush
				Candidat.db.close
			end
		end

		def self.db_init
			get_candidate=<<END
SELECT c.*, CASE WHEN s.soutiens is NULL THEN 0 ELSE s.soutiens END
  FROM candidates as c
    left join (
	    SELECT candidate_id,count(*) as soutiens
	    FROM supporters
	    GROUP BY candidate_id
      ) as s
  on (s.candidate_id = c.candidate_id)
WHERE c.candidate_id = $1;
END
			Candidat.db_close
			Candidat.db=PG.connect(
				"dbname"=>PGNAME,
				"user"=>PGUSER,
				"password"=>PGPWD,
				"sslmode"=>"require",
				"host"=>PGHOST,
				"port"=>PGPORT
			)
			Candidat.db.prepare("get_candidate",get_candidate)
		end

		def self.db_query(name,params)
			if Candidat.db.nil? or Candidat.db.status!=PG::CONNECTION_OK then
				self.db_init
			end
			Candidat.db.exec_prepared("get_candidate",params)
		end

		configure :development do
			register Sinatra::Reloader
		end

		get '/candidat/:candidate_id' do
			begin
				res=Candidat.db_query("get_candidate",[params['candidate_id']])
			rescue PG::Error => e
				status 500
				return erb :error, :locals=>{:error=>{"title"=>"Erreur serveur","message"=>e.message}}
			end
			if res.num_tuples.zero? then
				status 404
				return erb :error, :locals=>{:error=>{"title"=>"Page candidat inconnue","message"=>"Cette page ne correspond à aucun candidat"}}
			end
			candidat=res[0]
			candidat['encoded_name']=URI::encode(candidat['name'])
			candidat['goal']=candidat['soutiens'].to_i<=500 ? 500 : candidat['soutiens']
			candidat['qualified']=candidat['soutiens']==500
			m=(candidat['gender']=="M")
			gender={
				"le"=>m ? "le":"la",
				"il"=>m ? "il":"elle",
				"ce"=>m ? "ce":"cette",
				"citoyen"=>m ? "citoyen":"citoyenne",
				"citoyens"=>m ? "citoyens":"citoyennes",
				"candidat"=>m ? "candidat":"candidate",
				"candidats"=>m ? "candidats":"candidates",
				"qualifié"=>m ? "qualifié":"qualifiée",
				"son"=>m ? "son":"sa"
			}
			if candidat['photo'] then
				candidat['photo']="https://bot.democratech.co/static/candidats/%s%s" % [candidat['candidate_id'],File.extname(candidat['photo'])]
			else
				candidat['photo']="https://bot.democratech.co/static/images/missing-photo-M.jpg"
			end
			erb :candidat, :locals=>{:candidat=>candidat, :gender=>gender}
		end
	end
end
