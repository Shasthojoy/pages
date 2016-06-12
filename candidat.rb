require 'sinatra/base'
require 'sinatra/reloader'
require 'date'
require 'erb'
require 'cgi'
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
			@queries['get_citizen_by_key']=<<END
SELECT c.user_id,c.firstname,c.lastname,c.email,c.registered,c.country,c.citizen_key,c.validation_level,ci.zipcode,ci.name,ci.population,ci.departement
FROM citizens AS c LEFT JOIN cities AS ci ON (ci.city_id=c.city_id)
WHERE c.citizen_key=$1
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
			@queries['get_supporters_by_key']=<<END
select c.firstname, c.lastname, c.city, ci.departement, s.support_date from citizens as c inner join supporters as s on (s.user_id=c.user_id) inner join candidates as ca on (ca.candidate_id=s.candidate_id) left join cities as ci on (ci.city_id=c.city_id) where ca.candidate_key=$1;
END
			@queries['get_supported_candidates_by_key']=<<END
SELECT ca.name, ca.gender, ca.candidate_id, ca.candidate_key, s.support_date
FROM citizens AS ci
INNER JOIN supporters AS s ON (s.user_id=ci.user_id AND ci.citizen_key=$1)
INNER JOIN candidates AS ca ON (ca.candidate_id=s.candidate_id);
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
			secteur=html_escape(candidat['secteur']) unless candidat['secteur'].nil?
			departement_name=candidat['departement'].split(' - ')[1] unless candidat['departement'].nil?
			departement_name=html_escape(departement_name) unless departement_name.nil?
			departement=html_escape(candidat['departement']) unless candidat['departement'].nil?
			job=html_escape(candidat['job']) unless candidat['job'].nil?
			vision=html_escape(candidat['vision']) unless candidat['vision'].nil?
			prio1=html_escape(candidat['prio1']) unless candidat['prio1'].nil?
			prio2=html_escape(candidat['prio2']) unless candidat['prio2'].nil?
			prio3=html_escape(candidat['prio3']) unless candidat['prio3'].nil?
			trello=html_escape(candidat['trello'].split('?')[0]) unless candidat['trello'].nil? or candidat['trello'].empty?
			website=html_escape(candidat['website'].split('?')[0]) unless candidat['website'].nil? or candidat['website'].empty?
			facebook=html_escape(candidat['facebook'].split('?')[0]) unless candidat['facebook'].nil? or candidat['facebook'].empty?
			twitter=html_escape(candidat['twitter'].split('?')[0]) unless candidat['twitter'].nil? or candidat['twitter'].empty?
			linkedin=html_escape(candidat['linkedin'].split('?')[0]) unless candidat['linkedin'].nil? or candidat['linkedin'].empty?
			blog=html_escape(candidat['blog'].split('?')[0]) unless candidat['blog'].nil? or candidat['blog'].empty?
			youtube=html_escape(candidat['youtube'].split('?')[0]) unless candidat['youtube'].nil? or candidat['youtube'].empty?
			instagram=html_escape(candidat['instagram'].split('?')[0]) unless candidat['instagram'].nil? or candidat['instagram'].empty?
			wikipedia=html_escape(candidat['wikipedia'].split('?')[0]) unless candidat['wikipedia'].nil? or candidat['wikipedia'].empty?
			birthday=Date.parse(candidat['birthday'].split('?')[0]) unless candidat['birthday'].nil?
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
			if candidat['photo'] then
				candidat['photo']="#{AWS_S3_BUCKET_URL}%s%s" % [candidat['candidate_id'],File.extname(candidat['photo'])]
			else
				candidat['photo']="https://bot.democratech.co/static/images/missing-photo-M.jpg"
			end
			erb :candidat, :locals=>{
				:candidat=>candidat,
				:gender=>gender,
				:secteur=>secteur,
				:departement_name=>departement_name,
				:job=>job,
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
				:youtube=>youtube,
				:instagram=>instagram,
				:wikipedia=>wikipedia,
				:age=>age,
				:days_verified=>days_verified,
			}
		end

		get '/admin/:candidate_key' do
			soutiens=[]
			begin
				Candidat.db_init()
				res=Candidat.db_query("get_candidate_by_key",[params['candidate_key']])
				return erb :error, :locals=>{:error=>{"title"=>"Page inconnue","message"=>"La page demandée n'existe pas"}} if res.num_tuples.zero?
				candidat=res[0]
				res1=Candidat.db_query("get_supporters_by_key",[params['candidate_key']])
				if not res1.num_tuples.zero? then
					res1.each do |r|
						soutiens.push({
							'firstname'=>r['firstname'],
							'lastname'=>r['lastname'],
							'departement'=>r['departement'],
							'city'=>r['city'],
							'support_date'=>Date.parse(r['support_date']).to_s
						})
					end
				end
			rescue Exception => e
				status 500
				return erb :error, :locals=>{:error=>{"title"=>"Erreur serveur","message"=>e.message}}
			ensure
				Candidat.db.close() unless Candidat.db.nil?
			end
			if res.num_tuples.zero? then
				status 404
				return erb :error, :locals=>{:error=>{"title"=>"Page candidat inconnue","message"=>"Cette page ne correspond à aucun candidat"}}
			end
			email=html_escape(candidat['email']) unless candidat['email'].nil?
			secteur=html_escape(candidat['secteur']) unless candidat['secteur'].nil?
			departement_name=candidat['departement'].split(' - ')[1] unless candidat['departement'].nil?
			departement_name=html_escape(departement_name) unless departement_name.nil?
			departement=html_escape(candidat['departement']) unless candidat['departement'].nil?
			job=html_escape(candidat['job']) unless candidat['job'].nil?
			vision=html_escape(candidat['vision']) unless candidat['vision'].nil?
			prio1=html_escape(candidat['prio1']) unless candidat['prio1'].nil?
			prio2=html_escape(candidat['prio2']) unless candidat['prio2'].nil?
			prio3=html_escape(candidat['prio3']) unless candidat['prio3'].nil?
			trello=html_escape(candidat['trello'].split('?')[0]) unless candidat['trello'].nil? or candidat['trello'].empty?
			website=html_escape(candidat['website'].split('?')[0]) unless candidat['website'].nil? or candidat['website'].empty?
			facebook=html_escape(candidat['facebook'].split('?')[0]) unless candidat['facebook'].nil? or candidat['facebook'].empty?
			twitter=html_escape(candidat['twitter'].split('?')[0]) unless candidat['twitter'].nil? or candidat['twitter'].empty?
			linkedin=html_escape(candidat['linkedin'].split('?')[0]) unless candidat['linkedin'].nil? or candidat['linkedin'].empty?
			blog=html_escape(candidat['blog'].split('?')[0]) unless candidat['blog'].nil? or candidat['blog'].empty?
			youtube=html_escape(candidat['youtube'].split('?')[0]) unless candidat['youtube'].nil? or candidat['youtube'].empty?
			instagram=html_escape(candidat['instagram'].split('?')[0]) unless candidat['instagram'].nil? or candidat['instagram'].empty?
			wikipedia=html_escape(candidat['wikipedia'].split('?')[0]) unless candidat['wikipedia'].nil? or candidat['wikipedia'].empty?
			birthday=Date.parse(candidat['birthday'].split('?')[0]) unless candidat['birthday'].nil?
			photo_url= candidat['photo'].nil? ? "https://bot.democratech.co/static/images/missing-photo-M.jpg" : AWS_S3_BUCKET_URL+candidat['photo']
			age=nil
			unless birthday.nil? then
				now = Time.now.utc.to_date
				age = now.year - birthday.year - ((now.month > birthday.month || (now.month == birthday.month && now.day >= birthday.day)) ? 0 : 1)
			end
			date_verified=Date.parse(candidat['date_verified']) unless candidat['date_verified'].nil?
			days_verified = (Date.today-date_verified).to_i unless date_verified.nil?
			vision_encoded=CGI.escape(ERB::Util.url_encode(candidat['vision'])) unless candidat['vision'].nil?
			prio1_encoded=CGI.escape(ERB::Util.url_encode(candidat['prio1'])) unless candidat['prio1'].nil?
			prio2_encoded=CGI.escape(ERB::Util.url_encode(candidat['prio2'])) unless candidat['prio2'].nil?
			prio3_encoded=CGI.escape(ERB::Util.url_encode(candidat['prio3'])) unless candidat['prio3'].nil?
			email_encoded=CGI.escape(ERB::Util.url_encode(email))

			candidat['goal']=candidat['soutiens'].to_i<=500 ? 500 : candidat['soutiens']
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
				'links'=>"Field13=#{youtube}&Field8=#{trello}&Field1=#{website}&Field2=#{facebook}&Field3=#{twitter}&Field4=#{linkedin}&Field5=#{blog}&Field6=#{instagram}&Field7=#{wikipedia}&Field9=#{candidat['candidate_key']}&Field11=#{email}"
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
				:youtube=>youtube,
				:instagram=>instagram,
				:wikipedia=>wikipedia,
				:age=>age,
				:days_verified=>days_verified,
				:soutiens=>soutiens,
				:photo_url=>photo_url,
				:vision_encoded=>vision_encoded,
				:prio1_encoded=>prio1_encoded,
				:prio2_encoded=>prio2_encoded,
				:prio3_encoded=>prio3_encoded,
				:email_encoded=>email_encoded
			}
		end

		get '/citizen/:citizen_key' do
			candidats=[]
			begin
				Candidat.db_init()
				res=Candidat.db_query("get_citizen_by_key",[params['citizen_key']])
				return erb :error, :locals=>{:error=>{"title"=>"Page inconnue","message"=>"La page demandée n'existe pas"}} if res.num_tuples.zero?
				citizen=res[0]
				res1=Candidat.db_query("get_supported_candidates_by_key",[params['citizen_key']])
				if not res1.num_tuples.zero? then
					res1.each do |r|
						candidats.push({
							'name'=>r['name'],
							'candidate_key'=>r['candidate_key'],
							'support_date'=>Date.parse(r['support_date']).to_s
						})
					end
				end
			rescue Exception => e
				status 500
				return erb :error, :locals=>{:error=>{"title"=>"Erreur serveur","message"=>e.message}}
			ensure
				Candidat.db.close() unless Candidat.db.nil?
			end
			if res.num_tuples.zero? then
				status 404
				return erb :error, :locals=>{:error=>{"title"=>"Page candidat inconnue","message"=>"Cette page ne correspond à aucun candidat"}}
			end
			erb :citoyen, :locals=>{
				:citoyen=>citizen,
				:candidats=>candidats
			}
		end
	end
end
