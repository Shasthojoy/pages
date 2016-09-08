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
	class AdminCandidat < Sinatra::Application
		def initialize(base)
			super(base)
			@queries={
				'get_candidate_by_key'=><<END,
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
				'get_supporters_by_key'=><<END,
select c.firstname, c.lastname, c.city, ci.departement, s.support_date from citizens as c inner join supporters as s on (s.user_id=c.user_id) inner join candidates as ca on (ca.candidate_id=s.candidate_id) left join cities as ci on (ci.city_id=c.city_id) where ca.candidate_key=$1;
END
				'get_articles_by_key'=><<END,
select a.*,at.name as theme, at.slug as theme_slug, atp.name as parent_theme, atp.slug as parent_theme_slug from candidates as ca inner join articles as a on (a.candidate_id=ca.candidate_id) inner join articles_themes as at on (at.theme_id=a.theme_id) left join articles_themes as atp on (atp.theme_id=at.parent_theme_id) where ca.candidate_key=$1 order by a.date_published ASC
END
			}
		end

		configure do
			set :view, 'views'
			set :root, File.expand_path('../../',__FILE__)
		end

		get '/admin/:candidate_key' do
			soutiens=[]
			articles=[]
			begin
				Pages.db_init()
				res=Pages.db_query(@queries["get_candidate_by_key"],[params['candidate_key']])
				return erb :error, :locals=>{:msg=>{"title"=>"Page inconnue","message"=>"La page demandée n'existe pas"}} if res.num_tuples.zero?
				candidat=res[0]
				if ABANDONS.include?(candidat['candidate_id'].to_i) then
					status 200
					return erb :error, :locals=>{:msg=>{"title"=>"Page inconnue","message"=>"La page demandée n'existe pas"}}
				end
				if EXCLUSIONS.include?(candidat['candidate_id'].to_i) then
					status 200
					return erb :error, :locals=>{:msg=>{"title"=>"Page inconnue","message"=>"La page demandée n'existe pas"}}
				end
				res1=Pages.db_query(@queries["get_supporters_by_key"],[params['candidate_key']])
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
				res2=Pages.db_query(@queries["get_articles_by_key"],[params['candidate_key']])
				if not res2.num_tuples.zero? then
					res2.each do |r|
						articles.push({
							'article_id'=>r['article_id'],
							'title'=>r['title'],
							'summary'=>r['summary'],
							'source_url'=>r['source_url'],
							'published_url'=>r['published_url'],
							'theme'=>r['theme'],
							'theme_slug'=>r['theme_slug'],
							'parent_theme'=>r['parent_theme'],
							'parent_theme_slug'=>r['parent_theme_slug'],
							'date_added'=>Date.parse(r['date_added']).to_s,
							'date_published'=>Date.parse(r['date_published']).to_s
						})
					end
				end
			rescue Exception => e
				status 500
				return erb :error, :locals=>{:msg=>{"title"=>"Erreur serveur","message"=>e.message}}
			ensure
				Pages.db_close()
			end
			if res.num_tuples.zero? then
				status 404
				return erb :error, :locals=>{:msg=>{"title"=>"Page candidat inconnue","message"=>"Cette page ne correspond à aucun citoyen"}}
			end
			email=html_escape(candidat['email']) unless candidat['email'].nil?
			secteur=html_escape(candidat['secteur']) unless candidat['secteur'].nil?
			departement_name=candidat['departement'].split(' - ')[1] unless candidat['departement'].nil?
			departement_name=html_escape(departement_name) unless departement_name.nil?
			departement=html_escape(candidat['departement']) unless candidat['departement'].nil?
			job=html_escape(candidat['job']) unless candidat['job'].nil?
			bio=html_escape(candidat['bio']) unless candidat['bio'].nil?
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
			video=html_escape(candidat['video'].split('?')[0]) unless candidat['video'].nil? or candidat['video'].empty?
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
			bio_encoded=CGI.escape(ERB::Util.url_encode(candidat['bio'])) unless candidat['bio'].nil?
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
				'about'=>"Field15=#{candidat['candidate_key']}&Field18=#{email}&Field8=#{candidat['birthday']}&Field12=#{secteur}&Field17=#{job}&Field9=#{departement}&Field20=#{bio_encoded}",
				'summary'=>"Field6=#{candidat['candidate_key']}&Field7=#{email}&Field1=#{vision}&Field3=#{prio1}&Field2=#{prio2}&Field4=#{prio3}",
				'articles'=>"Field115=#{candidat['candidate_key']}&Field118=#{candidat['email']}",
				'links'=>"Field13=#{youtube}&Field15=#{video}&Field8=#{trello}&Field1=#{website}&Field2=#{facebook}&Field3=#{twitter}&Field4=#{linkedin}&Field5=#{blog}&Field6=#{instagram}&Field7=#{wikipedia}&Field9=#{candidat['candidate_key']}&Field11=#{email}"
			}
			erb :admin, :locals=>{
				:candidat=>candidat,
				:prefill=>prefill,
				:gender=>gender,
				:secteur=>secteur,
				:departement_name=>departement_name,
				:job=>job,
				:bio=>bio,
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
				:bio_encoded=>bio_encoded,
				:vision_encoded=>vision_encoded,
				:prio1_encoded=>prio1_encoded,
				:prio2_encoded=>prio2_encoded,
				:prio3_encoded=>prio3_encoded,
				:email_encoded=>email_encoded,
				:articles=>articles
			}
		end
	end
end
