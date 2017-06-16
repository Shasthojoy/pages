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
		register Sinatra::Subdomain

		def initialize(base)
			super(base)
			@queries={
				'get_candidate_by_slug'=><<END,
SELECT u.*, ce.fields,ci.name_circonscription as circonscriptionzz, CASE WHEN s.soutiens is NULL THEN 0 ELSE s.soutiens END
    FROM users as u
    INNER JOIN candidates_elections as ce ON (ce.email=u.email)
    INNER JOIN elections as e ON (ce.election_id=e.election_id AND e.hostname=$2)
    INNER JOIN circonscriptions AS ci ON (ci.id=e.circonscription_id)
    LEFT JOIN (
	    SELECT candidate,election_id,count(supporter) as soutiens
	    FROM supporters
	    GROUP BY candidate,election_id
      ) as s
  on (s.candidate = u.email AND s.election_id=e.election_id)
WHERE u.slug = $1;
END
				'get_candidate_by_circo'=><<END,
SELECT (row_to_json(u.*)::jsonb||('{"circonscription": "'::text||(ce.fields->>'circonscription')::text||'"}')::jsonb)::jsonb
    FROM users as u
    INNER JOIN candidates_elections as ce ON (ce.email=u.email)
    INNER JOIN elections as e ON (ce.election_id=e.election_id AND e.hostname=$2)
    LEFT JOIN (
     SELECT candidate,election_id,count(supporter) as soutiens
     FROM supporters
     GROUP BY candidate,election_id
      ) as s
  on (s.candidate = u.email AND s.election_id=e.election_id) 
WHERE ce.accepted;
END
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
				'get_candidate_qualified_by_name'=><<END,
SELECT c.*, CASE WHEN s.soutiens is NULL THEN 0 ELSE s.soutiens END
  FROM candidates as c
    left join (
	    SELECT candidate_id,count(*) as soutiens
	    FROM supporters
	    GROUP BY candidate_id
      ) as s
  on (s.candidate_id = c.candidate_id)
WHERE c.slug = $1 and qualified;
END
				'get_articles_by_candidate'=><<END,
SELECT a.*,at.name as theme, at.slug as theme_slug, pat.name as parent_theme, pat.slug as parent_theme_slug FROM articles as a INNER JOIN articles_themes as at ON (at.theme_id=a.theme_id) LEFT JOIN articles_themes as pat ON (pat.theme_id=at.parent_theme_id) WHERE a.candidate_id=$1 AND now() > a.date_published
END
				'get_parrainages'=><<END,
SELECT * FROM candidats_officiels ORDER BY ranking ASC,parrainages DESC, name ASC
END
			}
		end

		helpers do            
			def page_info(infos)
				gender=infos['gender']
				info={
					'page_description'=>"#{infos['name']} s'est #{gender['qualifié']} à LaPrimaire.org, la primaire citoyenne, en obtenant ses 500 soutiens citoyens et est officiellement #{gender['candidat']} à l'élection présidentielle de 2017.",
					'page_author'=>"Des citoyens ordinaires",
					'page_image'=>infos['photo'],
					'page_url'=>"https://laprimaire.org/qualifie/#{infos['slug']}",
					'page_title'=>"#{infos['name']}, #{gender['candidat']} à la primaire citoyenne pour l'élection présidentielle de 2017",
					'social_title'=>"Découvrez #{infos['name']}, #{gender['candidat']} à la primaire citoyenne pour l'élection présidentielle de 2017"
				}
				return info
			end

			def strip_tags(text)
				return text.gsub(/<\/?[^>]*>/, "")
			end
		end

		configure do
			set :view, 'views'
			set :root, File.expand_path('../../',__FILE__)
		end

		subdomain do
			get '/candidat/:slug' do
				if params['candidate_id']=='sitemap.xml' then
					content_type 'text/xml'
					return File.read(File.expand_path(File.dirname(__FILE__))+'/sitemap.xml') 
				end
				begin
					Pages.db_init()
					res=Pages.db_query(@queries["get_candidate_by_slug"],[params['slug'],request.host])
				rescue PG::Error => e
					status 500
					return erb :error, :locals=>{:msg=>{"title"=>"Erreur serveur","message"=>strip_tags(e.message)}}
				ensure
					Pages.db_close()
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
					if candidat['candidate_id'].to_i==697785064574 then # Droit de réponse
						return erb :error, :locals=>{:msg=>{"title"=>"Candidat disqualifié","message"=>"Ce candidat a été disqualifé pour infraction aux règles de LaPrimaire.org.<p><b>droit de réponse&nbsp;:</b> L'intéressé conteste ces accusations fondées sur des statistiques sujettes à caution et non communiquées au public.</p><p><b>notre réponse&nbsp;:</b> Voici l'<a href=\"https://docs.google.com/document/d/1N71aDm8IhpWX92Y-Ub3rOjTTOEpu9tdJoK8QkCrDug4/edit?usp=sharing\" target=\"_blank\">analyse des soutiens du candidat</a> sur laquelle nous avons basé notre décision de disqualification."}}
					else
						return erb :error, :locals=>{:msg=>{"title"=>"Candidat disqualifié","message"=>"Ce candidat a été disqualifé pour infraction aux règles de LaPrimaire.org"}}
					end
				end
				if (!candidat['fields'].nil?) then
					candidate_fields=JSON.parse(candidat['fields'])
					candidat.merge!(candidate_fields){|k,o,n| n.nil? ? o : n }
					candidat.delete('fields')
				end
				candidat['name']=candidat['firstname'].to_s+' '+candidat['lastname'].to_s
				candidat['encoded_name']=URI::encode(candidat['name'])
				candidat['goal']=candidat['soutiens'].to_i<=150 ? 150 : candidat['soutiens']
				candidat['qualified']= (candidat['soutiens'].to_i >= 150)
				candidat['video']=candidat['video'].gsub('watch?v=','embed/') unless candidat['video'].nil?
				secteur=html_escape(candidat['secteur']) unless candidat['secteur'].nil?
				circonscription=candidat['circonscriptionzz']
				departement_name=candidat['departement'].split(' - ')[1] unless candidat['departement'].nil?
				departement_name=html_escape(departement_name) unless departement_name.nil?
				departement=html_escape(candidat['departement']) unless candidat['departement'].nil?
				job=html_escape(candidat['job']) unless candidat['job'].nil?
				vision=html_escape(candidat['vision']) unless candidat['vision'].nil?
				prio1=html_escape(candidat['prio1']) unless candidat['prio1'].nil?
				prio2=html_escape(candidat['prio2']) unless candidat['prio2'].nil?
				prio3=html_escape(candidat['prio3']) unless candidat['prio3'].nil?
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
					"proposé"=>m ? "proposé":"proposée",
					"son"=>m ? "son":"sa"
				}
				if candidat['photo'] then
					candidat['photo']="#{AWS_S3_BUCKET_URL}/%s" % [candidat['photo']]
				else
					candidat['photo']="https://bot.democratech.co/static/images/missing-photo-M.jpg"
				end
				erb :candidat_declare, :views=>"views/#{subdomain}",
				:locals=>{
					:candidat=>candidat,
					:gender=>gender,
					:secteur=>secteur,
					:departement_name=>departement_name,
					:job=>job,
					:vision=>vision,
					:prio1=>prio1,
					:prio2=>prio2,
					:prio3=>prio3,
					:trello=>nil,
					:website=>website,
					:facebook=>facebook,
					:twitter=>twitter,
					:linkedin=>linkedin,
					:blog=>blog,
					:youtube=>youtube,
					:instagram=>instagram,
					:wikipedia=>wikipedia,
					:circonscription=>circonscription,
					:age=>candidat['age'],
					:days_verified=>days_verified,
				}
			end
		end

		get '/candidat/parrainages' do
			begin
				Pages.db_init()
				candidats=Pages.db_query(@queries["get_parrainages"])
				return erb :error, :locals=>{:msg=>{"title"=>"Erreur serveur","message"=>"Erreur de base de données"}} if candidats.num_tuples.zero?
			rescue PG::Error => e
				status 500
				return erb :error, :locals=>{:msg=>{"title"=>"Erreur serveur","message"=>strip_tags(e.message)}}
			ensure
				Pages.db_close()
			end
			info={
				'page_description'=>"Le nombre de parrainages reçus par le conseil constitutionnel pour les candidats à la présidentielle de 2017. ",
				'page_author'=>"LaPrimaire.org",
				'page_image'=>'https://s3.eu-central-1.amazonaws.com/laprimaire/images/parrainages.jpg',
				'page_url'=>"https://laprimaire.org/candidat/parrainages",
				'page_title'=>"Tous les parrainages reçus par les candidats à la présidentielle",
				'social_title'=>"Découvrez en temps réel, les parrainages reçus par les candidats à la présidentielle"
			}
			erb :parrainages, :locals=>{
				'candidats'=>candidats
			}
		end

		get '/candidat/:candidate_id' do
			if params['candidate_id']=='sitemap.xml' then
				content_type 'text/xml'
				return File.read(File.expand_path(File.dirname(__FILE__))+'/sitemap.xml') 
			end
			begin
				Pages.db_init()
				if params['candidate_id'].to_i==0 then # new version with slug
					res=Pages.db_query(@queries["get_candidate_by_slug"],[params['candidate_id']])
				else # old version with id
					res=Pages.db_query(@queries["get_candidate"],[params['candidate_id']])
				end

			rescue PG::Error => e
				status 500
				return erb :error, :locals=>{:msg=>{"title"=>"Erreur serveur","message"=>strip_tags(e.message)}}
			ensure
				Pages.db_close()
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
				if candidat['candidate_id'].to_i==697785064574 then # Droit de réponse
					return erb :error, :locals=>{:msg=>{"title"=>"Candidat disqualifié","message"=>"Ce candidat a été disqualifé pour infraction aux règles de LaPrimaire.org.<p><b>droit de réponse&nbsp;:</b> L'intéressé conteste ces accusations fondées sur des statistiques sujettes à caution et non communiquées au public.</p><p><b>notre réponse&nbsp;:</b> Voici l'<a href=\"https://docs.google.com/document/d/1N71aDm8IhpWX92Y-Ub3rOjTTOEpu9tdJoK8QkCrDug4/edit?usp=sharing\" target=\"_blank\">analyse des soutiens du candidat</a> sur laquelle nous avons basé notre décision de disqualification."}}
				else
					return erb :error, :locals=>{:msg=>{"title"=>"Candidat disqualifié","message"=>"Ce candidat a été disqualifé pour infraction aux règles de LaPrimaire.org"}}
				end
			end
			candidat['encoded_name']=URI::encode(candidat['name'])
			candidat['goal']=candidat['soutiens'].to_i<=200 ? 200 : candidat['soutiens']
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
				candidat['photo']="#{AWS_S3_BUCKET_URL}/laprimaire/%s%s" % [candidat['candidate_id'],File.extname(candidat['photo'])]
			else
				candidat['photo']="https://bot.democratech.co/static/images/missing-photo-M.jpg"
			end
			erb :candidat_declare_demo, :locals=>{
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

		get '/qualifie/:name' do
			articles={}
			begin
				Pages.db_init()
				res=Pages.db_query(@queries["get_candidate_qualified_by_name"],[params["name"]])
				if res.num_tuples.zero? then
					status 404
					return erb :error, :locals=>{:msg=>{"title"=>"Page candidat inconnue","message"=>"Cette page ne correspond à aucun candidat"}}
				end
				candidat=res[0]
				res1=Pages.db_query(@queries["get_articles_by_candidate"],[candidat['candidate_id']])
				if not res1.num_tuples.zero? then
					res1.each do |a|
						a['date_published']=Date.parse(a['date_published']).strftime("%d/%m/%Y")
						if a['theme_slug']=='biographie' then
							articles['biographie']=a
						else
							articles[a['parent_theme_slug']]=[] if articles[a['parent_theme_slug']].nil?
							articles[a['parent_theme_slug']].push(a)
						end
					end
				end
			rescue PG::Error => e
				status 500
				return erb :error, :locals=>{:msg=>{"title"=>"Erreur de base de données","message"=>strip_tags(e.message)}}
			ensure
				Pages.db_close()
			end
			candidat['annonce']=false
			if RETRAITS.include?(candidat['slug']) then
				candidat['annonce']=true
			end
			if ABANDONS.include?(candidat['candidate_id'].to_i) then
				status 200
				return erb :error, :locals=>{:msg=>{"title"=>"Candidat retiré","message"=>"Ce candidat a souhaité retirer sa candidature"}}
			end
			if EXCLUSIONS.include?(candidat['candidate_id'].to_i) then
				status 200
				return erb :error, :locals=>{:msg=>{"title"=>"Candidat disqualifié","message"=>"Ce candidat a été disqualifé pour infraction aux règles de LaPrimaire.org"}}
			end
			candidat['articles']=articles
			candidat['firstname']=candidat['name'].split(' ')[0]
			candidat['lastname']=candidat['name'].split(' ')[1]
			candidat['encoded_name']=URI::encode(candidat['name'])
			candidat['goal']=candidat['soutiens'].to_i<=500 ? 500 : candidat['soutiens']
			candidat['qualified']= (candidat['soutiens'].to_i >= 500)
			candidat['video']=candidat['video'].gsub('watch?v=','embed/') unless candidat['video'].nil?
			candidat['secteur']=html_escape(candidat['secteur']) unless candidat['secteur'].nil? ## starts here
			candidat['departement_name']=candidat['departement'].split(' - ')[1] unless candidat['departement'].nil?
			candidat['departement_name']=html_escape(candidat['departement_name']) unless candidat['departement_name'].nil?
			candidat['departement']=html_escape(candidat['departement']) unless candidat['departement'].nil?
			candidat['job']=html_escape(candidat['job']) unless candidat['job'].nil?
			candidat['vision']=html_escape(candidat['vision']) unless candidat['vision'].nil?
			candidat['prio1']=html_escape(candidat['prio1']) unless candidat['prio1'].nil?
			candidat['prio2']=html_escape(candidat['prio2']) unless candidat['prio2'].nil?
			candidat['prio3']=html_escape(candidat['prio3']) unless candidat['prio3'].nil?
			candidat['trello']=html_escape(candidat['trello'].split('?')[0]) unless candidat['trello'].nil? or candidat['trello'].empty?
			candidat['website']=html_escape(candidat['website'].split('?')[0]) unless candidat['website'].nil? or candidat['website'].empty?
			candidat['facebook']=html_escape(candidat['facebook'].split('?')[0]) unless candidat['facebook'].nil? or candidat['facebook'].empty?
			candidat['twitter']=html_escape(candidat['twitter'].split('?')[0]) unless candidat['twitter'].nil? or candidat['twitter'].empty?
			candidat['linkedin']=html_escape(candidat['linkedin'].split('?')[0]) unless candidat['linkedin'].nil? or candidat['linkedin'].empty?
			candidat['blog']=html_escape(candidat['blog'].split('?')[0]) unless candidat['blog'].nil? or candidat['blog'].empty?
			candidat['youtube']=html_escape(candidat['youtube'].split('?')[0]) unless candidat['youtube'].nil? or candidat['youtube'].empty?
			candidat['instagram']=html_escape(candidat['instagram'].split('?')[0]) unless candidat['instagram'].nil? or candidat['instagram'].empty?
			candidat['wikipedia']=html_escape(candidat['wikipedia'].split('?')[0]) unless candidat['wikipedia'].nil? or candidat['wikipedia'].empty?
			candidat['photo_square']="#{AWS_S3_BUCKET_URL}qualifies/#{candidat['slug']}.jpg"
			birthday=Date.parse(candidat['birthday'].split('?')[0]) unless candidat['birthday'].nil?
			candidat['age']=nil
			unless birthday.nil? then
				now = Time.now.utc.to_date
				candidat['age'] = now.year - birthday.year - ((now.month > birthday.month || (now.month == birthday.month && now.day >= birthday.day)) ? 0 : 1)
			end
			date_verified=Date.parse(candidat['date_verified']) unless candidat['date_verified'].nil?
			candidat['days_verified'] = (Date.today-date_verified).to_i unless date_verified.nil?
			m=(candidat['gender']=="M")
			candidat['gender']={
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
			erb :index, :locals=>{
				'page_info'=>page_info(candidat),
				'vars'=>candidat,
				'template'=>:candidat_qualifie
			}
		end

		get '/candidat/vote/:name' do
			title=params["title"]
			name=params["name"]
			info={
				'name'=>name,
				'title'=>title,
				'page_description'=>"Votez pour #{name}",
				'page_author'=>"LaPrimaire.org",
				'page_url'=>"https://laprimaire.org/candidat/vote/#{name}",
				'page_title'=>"Votez pour #{name}"
			}
			erb :dummy_vote, :locals=>info
		end
	end
end

