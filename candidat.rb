require 'sinatra/base'
require 'sinatra/reloader'
require 'erb'
include ERB::Util

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
			@queries['get_candidate_by_key']=<<END
SELECT c.*, CASE WHEN s.soutiens is NULL THEN 0 ELSE s.soutiens END
  FROM candidates as c
    left join (
	    SELECT candidate_id,count(*) as soutiens
	    FROM supporters
	    GROUP BY candidate_id
      ) as s
  on (s.candidate_id = c.candidate_id)
WHERE c.candidate_key = $1;
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
			Candidat.db.exec_params(@queries[name],params)
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
				res=Candidat.db_query("get_candidate_by_key",[params['candidate_key']])
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
			secteur=html_escape(candidat['secteur']) unless candidat['secteur'].nil?
			departement_name=candidat['departement'].split(' - ')[1]
			departement_name=html_escape(departement_name) unless candidat['departement'].nil?
			departement=html_escape(candidat['departement']) unless candidat['departement'].nil?
			job=html_escape(candidat['job']) unless candidat['job'].nil?
			email=html_escape(candidat['email']) unless candidat['email'].nil?
			vision=html_escape(candidat['vision']) unless candidat['vision'].nil?
			prio1=html_escape(candidat['prio1']) unless candidat['prio1'].nil?
			prio2=html_escape(candidat['prio2']) unless candidat['prio2'].nil?
			prio3=html_escape(candidat['prio3']) unless candidat['prio3'].nil?
			trello=html_escape(candidat['trello']) unless candidat['trello'].nil?
			website=html_escape(candidat['website']) unless candidat['website'].nil?
			facebook=html_escape(candidat['facebook']) unless candidat['facebook'].nil?
			twitter=html_escape(candidat['twitter']) unless candidat['twitter'].nil?
			linkedin=html_escape(candidat['linkedin']) unless candidat['linkedin'].nil?
			blog=html_escape(candidat['blog']) unless candidat['blog'].nil?
			instagram=html_escape(candidat['instagram']) unless candidat['instagram'].nil?
			wikipedia=html_escape(candidat['wikipedia']) unless candidat['wikipedia'].nil?
			birthday=Date.parse(candidat['birthday']) unless candidat['birthday'].nil?
			age=nil
			unless birthday.nil? then
				now = Time.now.utc.to_date
				age = now.year - birthday.year - ((now.month > birthday.month || (now.month == birthday.month && now.day >= birthday.day)) ? 0 : 1)
			end
			date_verified=Date.parse(candidat['date_verified']) unless candidat['date_verified'].nil?
			days_verified = (Date.today-date_verified).to_i unless date_verified.nil?

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
			prefill={
				'photo'=>"Field3=#{candidat['candidate_key']}&Field4=#{candidat['email']}",
				'about'=>"Field15=#{candidat['candidate_key']}&Field18=#{email}&Field8=#{candidat['birthday']}&Field12=#{secteur}&Field17=#{job}&Field9=#{departement}",
				'summary'=>"Field6=#{candidat['candidate_key']}&Field7=#{email}&Field1=#{vision}&Field3=#{prio1}&Field2=#{prio2}&Field4=#{prio3}",
				'links'=>"Field8=#{trello}&Field1=#{website}&Field2=#{facebook}&Field3=#{twitter}&Field4=#{linkedin}&Field5=#{blog}&Field6=#{instagram}&Field7=#{wikipedia}&Field9=#{candidat['candidate_key']}&Field11=#{email}"
			}
			erb :admin, :locals=>{
				:candidat=>candidat,
				:prefill=>prefill,
				:gender=>gender,
				:secteur=>secteur,
				:departement_name=>departement_name,
				:job=>job,
				:email=>email,
				:vision=>vision,
				:prio1=>prio1,
				:prio2=>prio2,
				:prio3=>prio3,
				:trello=>trello,
				:website=>website,
				:facebook=>facebook,
				:twitter=>twitter,
				:linkedin=>linkedin,
				:blog=>blog,
				:instagram=>instagram,
				:wikipedia=>wikipedia,
				:age=>age,
				:days_verified=>days_verified
			}
		end

	end
end
