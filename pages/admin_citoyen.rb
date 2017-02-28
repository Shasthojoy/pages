# encoding: utf-8

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

require 'digest'
require 'date'

module Pages
	class AdminCitoyen < Sinatra::Application
		def initialize(base)
			super(base)
			@queries={
				'get_citizen_by_key'=><<END,
SELECT c.telegram_id,c.firstname,c.lastname,c.email,c.reset_code,c.registered,c.country,c.user_key,c.validation_level,c.birthday,c.telephone,c.city,ci.zipcode,ci.population,ci.departement,ci.num_circonscription,ci.num_commune,ci.code_departement, t.national as telephone_national
FROM users AS c 
LEFT JOIN cities AS ci ON (ci.city_id=c.city_id)
LEFT JOIN telephones AS t ON (t.international=c.telephone)
WHERE c.user_key=$1
END
				'get_citizen_by_email'=><<END,
SELECT c.telegram_id,c.firstname,c.lastname,c.email,c.reset_code,c.registered,c.country,c.user_key,c.validation_level,c.birthday,c.telephone,c.city,ci.zipcode,ci.population,ci.departement,ci.num_circonscription,ci.num_commune,ci.code_departement, t.national as telephone_national
FROM users AS c 
LEFT JOIN cities AS ci ON (ci.city_id=c.city_id)
LEFT JOIN telephones AS t ON (t.international=c.telephone)
WHERE c.email=$1
END
				'get_candidates_by_election'=><<END,
SELECT u.*,ce.fields,ce.finalist
FROM users AS u
INNER JOIN candidates_elections AS ce ON (ce.email=u.email and ce.qualified)
INNER JOIN elections as e ON (ce.election_id=e.election_id)
WHERE e.slug=$1
END
				'reset_citizen_email'=><<END,
UPDATE users SET email_status=2, validation_level=(validation_level & 14), email=reset_email, reset_email=null, reset_code=null WHERE email=$1 AND reset_email IS NOT null RETURNING *
END
				'get_ballot_by_id'=><<END,
SELECT b.ballot_id,b.vote_id,b.date_generated,b.vote_status,v.cc_vote_id,u.* FROM ballots as b INNER JOIN users as u ON (u.email=b.email) INNER JOIN votes as v ON (v.vote_id=b.vote_id) WHERE b.ballot_id=$1 AND u.user_key=$2;
END
				'get_vote_by_id'=><<END,
SELECT * FROM votes WHERE vote_id=$1
END
				'get_ballot_by_email'=><<END,
SELECT b.ballot_id,b.vote_status,b.date_generated FROM ballots as b WHERE b.email=$1 and b.vote_id=$2;
END
				'get_ballots_stats'=><<END,
SELECT count(*),c.slug,c.candidate_id FROM candidates as c LEFT JOIN candidates_ballots as cb ON (cb.candidate_id=c.candidate_id AND cb.vote_status='complete') WHERE c.qualified AND NOT c.abandonned GROUP BY c.slug,c.candidate_id ORDER BY c.slug ASC;
END
				'create_ballot'=><<END,
INSERT INTO ballots (email,vote_id) VALUES ($1,$2) RETURNING *;
END
				'update_citizen_hash'=><<END,
UPDATE users SET hash=$1 WHERE email=$2 RETURNING *;
END
				'populate_ballot'=><<END,
WITH ballot_candidates AS (
	INSERT INTO candidates_ballots (ballot_id,candidate_id,position) VALUES ($1,$2,1), ($1,$3,2), ($1,$4,3), ($1,$5,4), ($1,$6,5) RETURNING *
)
SELECT b.ballot_id,b.completed,b.date_generated,bc.position,bc.vote_status,c.* 
FROM candidates AS c 
INNER JOIN ballot_candidates as bc ON (bc.candidate_id=c.candidate_id)
INNER JOIN ballots as b ON (b.ballot_id=bc.ballot_id)
ORDER BY bc.position ASC;
END
				'get_circonscription_by_email'=><<END,
SELECT * FROM voters as v 
INNER JOIN users AS u ON (u.email=v.email AND u.email=$1)
INNER JOIN elections_view as ev ON (ev.election_id=v.election_id)
INNER JOIN circonscriptions as c ON (c.id=ev.circonscription_id)
WHERE ev.parent_slug=$2
END
				'set_circonscription_by_email'=><<END,
INSERT INTO voters (election_id,email) SELECT ev.election_id,$1 FROM elections_view as ev WHERE ev.circonscription_id=$2 AND ev.parent_slug=$3
END
				'get_candidates_supported'=><<END,
SELECT c.*
FROM users AS u
INNER JOIN voters AS v ON (v.email=u.email AND u.email=$1)
INNER JOIN elections AS e ON (e.election_id=v.election_id AND e.slug=$2)
INNER JOIN supporters AS s ON (s.supporter=u.email)
INNER JOIN users AS c ON (s.candidate=c.email)
END
				'add_supporter'=><<END,
INSERT INTO supporters (election_id,supporter,candidate)
SELECT e.election_id,$1,c.email
FROM users AS c ON (c.slug=$2)
END
			}
		end

		helpers do
			def error_occurred(code,msg) 
				status code
				return JSON.dump({
					'title'=>msg['title'],
					'msg'=>msg['msg']
				})
			end

			def authenticate_citizen(user_key)
				res=Pages.db_query(@queries["get_citizen_by_key"],[user_key])
				return res.num_tuples.zero? ? nil : res[0]
			end

			def get_candidates_supported(supporter_email,election_slug)
				res=Pages.db_query(@queries["get_candidates_supported"],[supporter_email,election_slug])
				return res.num_tuples.zero? ? nil : res
			end

			def get_circonscription(email,election_slug)
				res=Pages.db_query(@queries["get_circonscription_by_email"],[email,election_slug])
				return res.num_tuples.zero? ? nil : res[0]
			end

			def set_circonscription(email,circonscription_id,election_slug)
				res=Pages.db_query(@queries["set_circonscription_by_email"],[email,circonscription_id,election_slug])
				return res.num_tuples.zero? ? nil : res[0]
			end

			def page_info(infos=nil)
				return {
					'page_description'=>"description",
					'page_author'=>"Des citoyens ordinaires",
					'page_image'=>"pas de photo",
					'page_url'=>"https://laprimaire.org",
					'page_title'=>"Votez !",
					'social_title'=>"Votez !"
				} if infos.nil?
				return {
					'page_description'=>"description",
					'page_author'=>"Des citoyens ordinaires",
					'page_image'=>"pas de photo",
					'page_url'=>"https://laprimaire.org/citoyen/vote/#{infos['user_key']}",
					'page_title'=>"Votez !",
						'social_title'=>"Votez !"
				}
			end

			def create_ballot(email,vote_id)
				res=Pages.db_query(@queries["create_ballot"],[email,vote_id])
				ballot_id=res[0]['ballot_id']
				return {'ballot_id'=>ballot_id,'vote_status'=>"absent",'candidates'=>[]}
			end

			def generate_set()
				res=Pages.db_query(@queries["get_ballots_stats"])
				candidats=[]
				weights=[]
				res.each_with_index do |r,i|
					candidats.push(r['candidate_id'])
					weights.push(r['count'])
				end
				wrs = -> (freq) { freq.max_by { |_, weight| rand ** (1.0 / weight) }.first }
				probas=weights.map {|w| 1/w.to_f}
				ps=probas.map {|w| (Float w)/probas.reduce(:+)}
				wcandidats = candidats.zip(ps).to_h
				set=[]
				while set.length<5 do
					c=wrs[wcandidats]
					set.push(c)
					wcandidats.delete(c)
				end
				return set
			end

			def email_domain_valid(email)
				check="SELECT domain FROM forbidden_domains as fd WHERE fd.domain=substring($1 from '@(.*)$')"
				res=Pages.db_query(check,[email])
				return res.num_tuples.zero?
			end

			def clones_count()
				check="SELECT count(*),ip_address,useragent_raw FROM (SELECT ip_address,email,ua.useragent_raw FROM auth_history AS a INNER JOIN user_agents AS ua ON (ua.useragent_id=a.useragent_id) GROUP BY ip_address,email,useragent_raw) as a where ip_address=$1 and useragent_raw=$2 group by ip_address,useragent_raw order by count desc"
				res=Pages.db_query(check,[request.ip,request.user_agent])
				return res.num_tuples.zero? ? 0 : res[0]['count']
			end
		end

		configure do
			set :view, 'views'
			set :root, File.expand_path('../../',__FILE__)
		end

		get '/citoyen/:user_key' do
			errors=[]
			success=[]
			begin
				Pages.db_init()
				res=Pages.db_query(@queries["get_citizen_by_key"],[params['user_key']])
				return erb :error, :locals=>{:msg=>{"title"=>"Page inconnue","message"=>"La page demandée n'existe pas"}} if res.num_tuples.zero?
				citoyen=res[0]
				#1 We check the validation level of the candidate authentication 
				auth={
					'email_valid'=>(citoyen['validation_level'].to_i&1)!=0,
					'phone_valid'=>(citoyen['validation_level'].to_i&2)!=0
				}
				redirect "/citoyen/auth/#{params['user_key']}" if citoyen['validation_level'].to_i<3
				email=citoyen['email']
				if not params['reset_email'].nil? then
					if not params['reset_code'].nil? and params['reset_code']==citoyen['reset_code'] then
						res1=Pages.db_query(@queries["reset_citizen_email"],[email])
						if not res1.num_tuples.zero? then
							updated_citoyen=res1[0]
							citoyen['email']=updated_citoyen['email']
							citoyen['email_status']=updated_citoyen['email_status']
							citoyen['validation_level']=updated_citoyen['validation_level']
							success.push("Votre email a bien été mis-à-jour. Votre nouvel email : #{citoyen['email']}")
						end
					else
						errors.push("Impossible de mettre à jour votre email : le code fourni est erroné.")
					end
				end
			rescue PG::Error => e
				status 500
				return erb :error, :locals=>{:msg=>{"title"=>"Erreur serveur","message"=>e.message}}
			ensure
				Pages.db_close()
			end
			if !success.empty?() then
				return erb :success, :locals=>{:msg=>{"title"=>"Email mis à jour","message"=>success[0]}}
			elsif !errors.empty?() then
				return erb :error, :locals=>{:msg=>{"title"=>"Email non mis à jour","message"=>errors[0]}}
			end
			return erb :error, :locals=>{:msg=>{"title"=>"Page inconnue","message"=>"La page demandée n'existe pas"}} if res.num_tuples.zero?
			return erb :admin_citoyen, :locals=>{
				'citoyen'=>citoyen,
				'errors'=>errors,
				'success'=>success
			}
			return erb :index, :locals=>{
				'page_info'=>{
					'page_description'=>"Explorez et comparez les propositions des 5 citoyen(ne)s candidat(e)s finalistes à LaPrimaire.org.",
					'page_author'=>"Les citoyen(ne)s candidat(e)s à LaPrimaire.org",
					'page_image'=>"https://s3.eu-central-1.amazonaws.com/laprimaire/images/comparateur.jpg",
					'page_url'=>"https://laprimaire.org/citoyen/vote/comparateur",
					'page_title'=>"Explorez et comparez les propositions des citoyen(ne)s candidat(e)s à LaPrimaire.org !",
					'social_title'=>"Explorez et comparez les propositions des citoyen(ne)s candidat(e)s à LaPrimaire.org !"
				},
				'template'=>:citoyen,
				'vars'=>{
					'citoyen'=>citoyen,
					'errors'=>errors,
					'success'=>success
				}
			}
		end

		get '/citoyen/vote/tutorial' do
			erb :vote_tutorial
		end

		get '/citoyen/vote/tutorial_final' do
			erb :vote_tutorial2
		end

		get '/citoyen/vote/100k' do
			erb :illustration_100k
		end

		get '/citoyen/vote/comparateur' do
			erb :index, :locals=>{
				'page_info'=>{
					'page_description'=>"Explorez et comparez les propositions des 5 citoyen(ne)s candidat(e)s finalistes à LaPrimaire.org.",
					'page_author'=>"Les citoyen(ne)s candidat(e)s à LaPrimaire.org",
					'page_image'=>"https://s3.eu-central-1.amazonaws.com/laprimaire/images/comparateur.jpg",
					'page_url'=>"https://laprimaire.org/citoyen/vote/comparateur",
					'page_title'=>"Explorez et comparez les propositions des citoyen(ne)s candidat(e)s à LaPrimaire.org !",
					'social_title'=>"Explorez et comparez les propositions des citoyen(ne)s candidat(e)s à LaPrimaire.org !"
				},
				'template'=>:comparateur,
				'vars'=>{}
			}
		end

		get '/citoyen/verif/:email' do
			return erb :error, :locals=>{:msg=>{"title"=>"Page inconnue","message"=>"La page demandée n'existe pas"}} if params['email'].nil?
			email=params['email'].downcase.gsub(/\A\p{Space}*|\p{Space}*\z/, '')
			return erb :error, :locals=>{:msg=>{"title"=>"Mauvais email","message"=>"Votre email n'est pas valide"}} if email.match(/\A[^@\s]+@([^@\s]+\.)+[^@\s]+\z/).nil?
			erb :index, :locals=>{
				'page_info'=>page_info(),
				'vars'=>{'email'=>params['email'],'newcitizen'=>params['newcitizen']},
				'no_navbar'=>true,
				'template'=>:email_verification
			}
		end

		get '/citoyen/auth/:user_key' do
			begin
				Pages.db_init()
				res=Pages.db_query(@queries["get_citizen_by_key"],[params['user_key']])
				return erb :error, :locals=>{:msg=>{"title"=>"Page inconnue","message"=>"La page demandée n'existe pas"}} if res.num_tuples.zero?
				citoyen=res[0]
				if !email_domain_valid(citoyen['email']) then
					status 403
					citoyen['forbidden']=1
					Pages.log.error "Forbidden email domain name : #{citoyen['email']}"
				end
				clones=clones_count()
				if clones>FRAUD_THRESHOLD_CLONES then
					status 403
					citoyen['fraud_suspected']=1
					Pages.log.error "Fraud suspected : #{citoyen['email']} [#{clones} clones]"
				end
			rescue PG::Error => e
				Pages.log.error "/citoyen/auth DB Error #{params}\n#{e.message}"
				status 500
				return erb :error, :locals=>{:msg=>{"title"=>"Erreur serveur","message"=>e.message}}
			ensure
				Pages.db_close()
			end
			redirect "/citoyen/#{params['user_key']}" if (citoyen['validation_level'].to_i>2 && params['reauth'].nil?)
			citoyen['birthday']=Date.parse(citoyen['birthday']).strftime('%d/%m/%Y') unless citoyen['birthday'].nil?
			erb :index, :locals=>{
				'page_info'=>page_info(citoyen),
				'vars'=>{'citoyen'=>citoyen},
				'no_navbar'=>true,
				'template'=>:authentication
			}
		end

		get '/citoyen/token/:user_key' do
			return JSON.dump({'param_missing'=>'ballot'}) if params['ballot'].nil?
			return JSON.dump({'param_missing'=>'user key'}) if params['user_key'].nil?
			return JSON.dump({'param_missing'=>'vote id'}) if params['vote_id'].nil?
			if VOTE_PAUSED then
				status 404
				return JSON.dump({'message'=>'votes are currently paused, please retry in a few minutes...'})
			end
			begin
				Pages.db_init()
				res=Pages.db_query(@queries["get_ballot_by_id"],[params['ballot'],params['user_key']])
				ballot=res[0]
				token={
					:iss=> COCORICO_APP_ID,
					:sub=> Digest::SHA256.hexdigest(ballot['email']),
					:email=> ballot['email'],
					:lastName=> ballot['lastname'],
					:firstName=> ballot['firstname'],
					:birthdate=> ballot['birthday'],
					:authorizedVotes=> [ballot['cc_vote_id']],
					:exp=>(Time.new.getutc+VOTING_TIME_ALLOWED).to_i
				}
				vote_token=JWT.encode token, COCORICO_SECRET, 'HS256'
				res=Pages.db_query(@queries["update_citizen_hash"],[token[:sub],ballot['email']])
			rescue PG::Error => e
				Pages.log.error "/citoyen/token DB Error #{params}\n#{e.message}"
				status 500
				return JSON.dump({"title"=>"Erreur serveur","message"=>e.message})
			ensure
				Pages.db_close()
			end
			return JSON.dump({'token'=>vote_token})
		end

		get '/citoyen/vote/:user_key/1' do
			redirect "/citoyen/vote/#{params['user_key']}/2"
		end

		get '/citoyen/spa/:user_key/election/legislatives-2017' do
			errors=[]
			success=[]
			begin
				Pages.db_init()
				citoyen=authenticate_citizen(params['user_key'])
				return error_occurred(404,{"title"=>"Page inconnue","msg"=>"La page demandée n'existe pas [code:CSEL0]"}) if citoyen.nil?
				redirect "/citoyen/auth/#{params['user_key']}" if citoyen['validation_level'].to_i<3
				circonscription=get_circonscription(citoyen['email'],'legislatives-2017')
				circonscription['deputy_slug']=circonscription['deputy_url'].split('/')[-1]
				circonscription['election_slug']=circonscription['slug']
				raise 'choose-circonscription' if circonscription.nil? #user has not yet registered to the election
			rescue StandardError => e
				return erb 'spa/election/choose-circonscription'.to_sym, :locals=>{
					'citoyen'=>citoyen
				}
			rescue PG::Error => e
				Pages.log.error "/citoyen/spa/election/legislatives-2017 DB Error [code:CSEL1] #{params}\n#{e.message}"
				return error_occurred(500,{"title"=>"Erreur serveur","msg"=>"Récupération des infos impossible [code:CSEL1]"})
			ensure
				Pages.db_close()
			end
			return erb 'spa/elections/legislatives-2017'.to_sym, :locals=>{
				'citoyen'=>citoyen,
				'circonscription'=>circonscription,
				'errors'=>errors,
				'success'=>success
			}
		end

		get '/citoyen/spa/:user_key/election/presidentielle-2017' do
			begin
				Pages.db_init()
				citoyen=authenticate_citizen(params['user_key'])
				return error_occurred(404,{"title"=>"Page inconnue","msg"=>"La page demandée n'existe pas [code:CSEL0]"}) if citoyen.nil?
				res=Pages.db_query(@queries["get_candidates_by_election"],['presidentielle-2017'])
				qualified=[]
				finalists=[]
				if not res.num_tuples.zero? then
					res.each do |c|
						c['fields']=JSON.parse(c['fields'])
						qualified.push(c)
						finalists.push(c) if c['finalist'].to_b
					end
				end
			rescue PG::Error => e
				Pages.log.error "/citoyen/spa/election DB Error #{params}\n#{e.message}"
				return error_occurred(500,{"title"=>"Erreur serveur","msg"=>"Récupération des infos impossible [code:CSEP0]"})
			ensure
				Pages.db_close()
			end
			erb 'spa/elections/presidentielle-2017'.to_sym, :locals=>{
				'partial'=>'presidentielle-2017',
				'qualified'=>qualified
			}
		end

		get '/citoyen/spa/:user_key/candidate/:partial' do
			erb 'spa/candidate'.to_sym, :locals=>{
				'partial'=>params['partial']
			}
		end

		get '/citoyen/spa/:user_key/donations/:partial' do
			erb 'spa/donations'.to_sym, :locals=>{
				'partial'=>params['partial']
			}
		end

		get '/citoyen/spa/:user_key/about/:partial' do
			erb 'spa/about'.to_sym, :locals=>{
				'partial'=>params['partial']
			}
		end

		get '/citoyen/spa/:user_key/home' do
			erb 'spa/home'.to_sym
		end

		get '/citoyen/vote/:user_key' do
			redirect "/citoyen/vote/#{params['user_key']}/2"
		end

		get '/citoyen/vote/:user_key/:vote_id' do
			begin
				Pages.db_init()
				res=Pages.db_query(@queries["get_citizen_by_key"],[params['user_key']])
				return erb :error, :locals=>{:msg=>{"title"=>"Page inconnue","message"=>"La page demandée n'existe pas"}} if res.num_tuples.zero?
				citoyen=res[0]
				res=Pages.db_query(@queries["get_vote_by_id"],[params['vote_id']])
				return erb :error, :locals=>{:msg=>{"title"=>"Vote inconnu","message"=>"La page demandée n'existe pas"}} if res.num_tuples.zero?
				vote=res[0]
				#1 We check the validation level of the candidate authentication 
				auth={
					'email_valid'=>(citoyen['validation_level'].to_i&1)!=0,
					'phone_valid'=>(citoyen['validation_level'].to_i&2)!=0
				}
				redirect "/citoyen/auth/#{params['user_key']}" if citoyen['validation_level'].to_i<3
				res=Pages.db_query("SELECT * FROM candidates WHERE finalist")
				finalists=[]
				res.each { |f| finalists.push(f.clone) } if !res.num_tuples.zero?
				#2 We check if a ballot has already been created
				res=Pages.db_query(@queries["get_ballot_by_email"],[citoyen['email'],vote['vote_id']])
				if res.num_tuples.zero? then
					#2bis If no pre-existing ballot exist we create one for the citizen
					ballot=create_ballot(citoyen['email'],vote['vote_id'])
				else
					vote_status=res[0]['vote_status'].nil? ? "absent" : res[0]['vote_status']
					ballot={'ballot_id'=>res[0]['ballot_id'],'vote_status'=>vote_status,'candidates'=>[]}
				end
				finalists.shuffle.each { |r| ballot["candidates"].push(r) }
			rescue PG::Error => e
				Pages.log.error "/citoyen/vote DB Error #{params}\n#{e.message}"
				status 500
				return erb :error, :locals=>{:msg=>{"title"=>"Erreur serveur","message"=>e.message}}
			ensure
				Pages.db_close()
			end
			ballot['candidates'].each do |candidate| 
				candidate['firstname']=candidate['name'].split(' ')[0]
				candidate['lastname']=candidate['name'].split(' ')[1]
				candidate['vote_status']= vote['vote_status'].nil? ? "absent" : vote['vote_status']
				birthday=Date.parse(candidate['birthday'].split('?')[0]) unless candidate['birthday'].nil?
				age=nil
				unless birthday.nil? then
					now = Time.now.utc.to_date
					age = now.year - birthday.year - ((now.month > birthday.month || (now.month == birthday.month && now.day >= birthday.day)) ? 0 : 1)
				end
				candidate['age']=age
			end
			tmp={
				'e'=>citoyen['email'],
				'f'=>citoyen['firstname'],
				'l'=>citoyen['lastname'],
				'a'=>citoyen['address'],
				'z'=>citoyen['zipcode'],
				'v'=>citoyen['city']
			}
			donation_params=""
			tmp.each do |k,v|
				donation_params+="#{k}="+CGI.escape(v) if !v.nil?
				donation_params+="&" if k!='v'
			end
			donation_params="?"+donation_params if !donation_params.empty?
			citoyen['donation_params']=donation_params
			erb :vote_citoyen, :locals=>{
				'auth'=>auth,
				'cocorico_app_id'=>COCORICO_APP_ID,
				'citoyen'=>citoyen,
				'ballot'=>ballot,
				'vote'=>vote
			}
		end
	end
end
