require 'sinatra/base'
require 'sinatra/reloader'
require 'open-uri'

module Democratech
	class Candidat < Sinatra::Base
		class << self
			attr_accessor :db
		end

		def self.db_load_queries
			@queries={}
			@queries['get_candidate']=<<END
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
		end
		def self.db_init
			Candidat.db=PG.connect(
				"dbname"=>PGNAME,
				"user"=>PGUSER,
				"password"=>PGPWD,
				"host"=>PGHOST,
				"port"=>PGPORT
			)
		end

		def self.db_query(name,params)
			Candidat.db.exec_params(@queries['get_candidate'],params)
		end

		configure :development do
			register Sinatra::Reloader
		end

		get '/candidat/:candidate_id' do
			if params['candidate_id']=='sitemap.xml' then
				content_type 'text/xml'
				return File.read(File.expand_path(File.dirname(__FILE__))+'/sitemap.xml') 
			end
			begin
				Candidat.db_init()
				res=Candidat.db_query("get_candidate",[params['candidate_id']])
			rescue PG::Error => e
				status 500
				return erb :error, :locals=>{:error=>{"title"=>"Erreur serveur","message"=>e.message}}
			ensure
				Candidat.db.close() unless Candidat.db.nil?
			end
			if res.num_tuples.zero? then
				status 404
				return erb :error, :locals=>{:error=>{"title"=>"Page candidat inconnue","message"=>"Cette page ne correspond à aucun candidat"}}
			end
			candidat=res[0]
			candidat['encoded_name']=URI::encode(candidat['name'])
			candidat['goal']=candidat['soutiens'].to_i<=500 ? 500 : candidat['soutiens']
			candidat['qualified']= (candidat['soutiens'].to_i >= 500)
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
				candidat['photo']="#{AWS_S3_BUCKET_URL}%s%s" % [candidat['candidate_id'],File.extname(candidat['photo'])]
			else
				candidat['photo']="https://bot.democratech.co/static/images/missing-photo-M.jpg"
			end
			erb :candidat, :locals=>{:candidat=>candidat, :gender=>gender}
		end

		get '/admin/:candidate_key' do
			begin
				Candidat.db_init()
				res=Candidat.db_query("get_candidate",[params['candidate_key']])
			rescue PG::Error => e
				status 500
				return erb :error, :locals=>{:error=>{"title"=>"Erreur serveur","message"=>e.message}}
			ensure
				Candidat.db.close() unless Candidat.db.nil?
			end
			if res.num_tuples.zero? then
				status 404
				return erb :error, :locals=>{:error=>{"title"=>"Page candidat inconnue","message"=>"Cette page ne correspond à aucun candidat"}}
			end
			candidat=res[0]
			erb :admin, :locals=>{:candidat=>candidat}
		end

	end
end
