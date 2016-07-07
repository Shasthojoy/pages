=begin
   Copyright 2016 Telegraph-ai

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
=end

module Pages
	class Candidat < Sinatra::Application
		def initialize(base)
			super(base)
			@queries={
				'get_candidate'=><<END,
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
			}
		end

		configure do
			set :view, 'views'
			set :root, File.expand_path('../../',__FILE__)
		end

		get '/candidat/:candidate_id' do
			if params['candidate_id']=='sitemap.xml' then
				content_type 'text/xml'
				return File.read(File.expand_path(File.dirname(__FILE__))+'/sitemap.xml') 
			end
			begin
				Pages.db_init()
				res=Pages.db_query(@queries["get_candidate"],[params['candidate_id']])
			rescue PG::Error => e
				status 500
				return erb :error, :locals=>{:msg=>{"title"=>"Erreur serveur","message"=>e.message}}
			ensure
				Pages.db.close() unless Pages.db.nil?
			end
			if res.num_tuples.zero? then
				status 404
				return erb :error, :locals=>{:msg=>{"title"=>"Page candidat inconnue","message"=>"Cette page ne correspond à aucun candidat"}}
			end
			candidat=res[0]
			if ABANDONS.include?(candidat['candidate_id'].to_i) then
				status 200
				return erb :error, :locals=>{:msg=>{"title"=>"Candidat retiré","message"=>"Ce candidat a souhaité retirer sa candidature"}}
			end
			if EXCLUSIONS.include?(candidat['candidate_id'].to_i) then
				status 200
				return erb :error, :locals=>{:msg=>{"title"=>"Candidat disqualifié","message"=>"Ce candidat a été disqualifé pour infraction aux règles de LaPrimaire.org"}}
			end
			candidat['encoded_name']=URI::encode(candidat['name'])
			candidat['goal']=candidat['soutiens'].to_i<=500 ? 500 : candidat['soutiens']
			candidat['qualified']= (candidat['soutiens'].to_i >= 500)
			candidat['video']=candidat['video'].gsub('watch?v=','embed/') unless candidat['video'].nil?
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
	end
end

