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
SELECT c.telegram_id,c.firstname,c.lastname,c.email,c.reset_code,c.registered,c.country,c.user_key,c.validation_level,c.birthday,c.telephone,ci.zipcode,ci.name as city,ci.population,ci.departement
FROM users AS c LEFT JOIN cities AS ci ON (ci.city_id=c.city_id)
WHERE c.user_key=$1
END
				'get_supported_candidates_by_key'=><<END,
SELECT ca.*, s.support_date
FROM users AS u
INNER JOIN supporters AS s ON (s.email=u.email AND u.user_key=$1)
INNER JOIN candidates AS ca ON (ca.candidate_id=s.candidate_id);
END
				'reset_citizen_email'=><<END,
UPDATE users SET email_status=2, validation_level=(validation_level & 14), email=reset_email, reset_email=null, reset_code=null WHERE email=$1 AND reset_email IS NOT null RETURNING *
END
				'get_ballot_by_id'=><<END,
SELECT b.ballot_id,b.completed,b.date_generated,cb.position,cb.vote_status,c.*,u.* FROM ballots as b INNER JOIN candidates_ballots as cb ON (cb.ballot_id=b.ballot_id) INNER JOIN candidates as c ON (c.candidate_id=cb.candidate_id) INNER JOIN users as u ON (u.email=b.email) WHERE b.ballot_id=$1 AND cb.candidate_id=$2 AND u.user_key=$3 ORDER BY cb.position ASC;
END
				'get_ballot_by_email'=><<END,
SELECT b.ballot_id,b.completed,b.date_generated,cb.position,cb.vote_status,c.* FROM ballots as b INNER JOIN candidates_ballots as cb ON (cb.ballot_id=b.ballot_id) INNER JOIN candidates as c ON (c.candidate_id=cb.candidate_id) WHERE b.email=$1 ORDER BY cb.position ASC;
END
				'get_ballots_stats'=><<END,
SELECT case when cb.ballot_id is null then 1 else count(*) end,c.slug,c.candidate_id FROM candidates as c LEFT JOIN candidates_ballots as cb ON cb.candidate_id=c.candidate_id WHERE c.qualified AND NOT c.abandonned GROUP BY c.slug,c.candidate_id,cb.ballot_id ORDER BY c.slug ASC;
END
				'create_ballot'=><<END,
INSERT INTO ballots (email) VALUES ($1) RETURNING *;
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

			}
		end

		helpers do
			def page_info(infos)
				info={
					'page_description'=>"description",
					'page_author'=>"Des citoyens ordinaires",
					'page_image'=>"pas de photo",
					'page_url'=>"https://laprimaire.org/citoyen/vote/#{infos['user_key']}",
					'page_title'=>"Votez !",
					'social_title'=>"Votez !"
				}
				return info
			end

			def create_ballot(email)
				set=generate_set()
				res=Pages.db_query(@queries["create_ballot"],[email])
				ballot_id=res[0]['ballot_id']
				params=[ballot_id]+set
				res=Pages.db_query(@queries["populate_ballot"],params)
				ballot={'ballot_id'=>ballot_id,'candidates'=>[]}
				res.each { |r| ballot["candidates"].push(r) }
				raise "error creating ballot : #{res.num_tuples} entries created instead of 5 expected" if res.num_tuples<5
				return ballot
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
					set.push(c) if not set.include?(c)
				end
				return set
			end

			def access_ballot(email,ballot_id)
			end
		end

		configure do
			set :view, 'views'
			set :root, File.expand_path('../../',__FILE__)
		end

		get '/citoyen/:user_key' do
			candidats=[
				{'photo'=>'soutien-1-dispo.jpg'},
				{'photo'=>'soutien-2-dispo.jpg'},
				{'photo'=>'soutien-3-dispo.jpg'},
				{'photo'=>'soutien-4-dispo.jpg'},
				{'photo'=>'soutien-5-dispo.jpg'}
			]
			citoyens=[
				{'photo'=>'plebiscite-1-dispo.jpg'},
				{'photo'=>'plebiscite-2-dispo.jpg'},
				{'photo'=>'plebiscite-3-dispo.jpg'},
				{'photo'=>'plebiscite-4-dispo.jpg'},
				{'photo'=>'plebiscite-5-dispo.jpg'},
			]
			errors=[]
			success=[]
			begin
				Pages.db_init()
				res=Pages.db_query(@queries["get_citizen_by_key"],[params['user_key']])
				return erb :error, :locals=>{:msg=>{"title"=>"Page inconnue","message"=>"La page demandée n'existe pas"}} if res.num_tuples.zero?
				citoyen=res[0]
				citoyen_hash=Digest::SHA256.hexdigest(citoyen['email'])
				payload={
					:iss=> COCORICO_APP_ID,
					:sub=> citoyen_hash,
					:email=> citoyen['email'],
					:lastName=> citoyen['lastname'],
					:firstName=> citoyen['firstname'],
					:authorizedVotes=> [ "57dd7f6fa18d6654d022a1a9" ]
				}
				encoded_token= JWT.encode payload, COCORICO_SECRET, 'HS256'
				account={
					'email_valid'=>(citoyen['validation_level'].to_i&1)!=0,
					'phone_valid'=>(citoyen['validation_level'].to_i&2)!=0,
					'facebook_valid'=>(citoyen['validation_level'].to_i&4)!=0,
					'membership_valid'=>(citoyen['validation_level'].to_i&8)!=0
				}
				validations=0
				account.each { |k,v| validations+=1 if v }
				account['valid']=(validations>1)
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
				res1=Pages.db_query(@queries["get_supported_candidates_by_key"],[params['user_key']])
				idx_candidat=0
				idx_citoyen=0
				if not res1.num_tuples.zero? then
					res1.each do |r|
						if (r['verified'].to_b) then
							candidats[idx_candidat]=r
							idx_candidat+=1
						else
							citoyens[idx_citoyen]=r
							idx_citoyen+=1
						end
					end
				end
			rescue PG::Error => e
				status 500
				return erb :error, :locals=>{:msg=>{"title"=>"Erreur serveur","message"=>e.message}}
			ensure
				Pages.db.close() unless Pages.db.nil?
			end
			erb :citoyen, :locals=>{
				'success'=>success,
				'errors'=>errors,
				'citoyen'=>citoyen,
				'candidats'=>candidats,
				'citoyens'=>citoyens,
				'account'=>account,
				'token'=>encoded_token,
				'vote_id'=>'57dd7f6fa18d6654d022a1a9',
				'cc_app_id'=>COCORICO_APPID
			}
		end

		get '/citoyen/vote/tutorial' do
			erb :vote_tutorial
		end

		get '/citoyen/auth/:user_key' do
			Pages.db_init()
			res=Pages.db_query(@queries["get_citizen_by_key"],[params['user_key']])
			return erb :error, :locals=>{:msg=>{"title"=>"Page inconnue","message"=>"La page demandée n'existe pas"}} if res.num_tuples.zero?
			citoyen=res[0]
			redirect "/citoyen/vote/#{params['user_key']}" if (citoyen['validation_level'].to_i>2 && params['reauth'].nil?)
			# citoyen['location']=citoyen['city'].nil? ? '' : citoyen['city']+' '+citoyen['zipcode']+' '+citoyen['country']
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
			return JSON.dump({'param_missing'=>'user_key'}) if params['user_key'].nil?
			return JSON.dump({'param_missing'=>'candidate'}) if params['candidate'].nil?
			Pages.db_init()
			res=Pages.db_query(@queries["get_ballot_by_id"],[params['ballot'],params['candidate'],params['user_key']])
			ballot=res[0]
			token={
				:iss=> COCORICO_APP_ID,
				:sub=> Digest::SHA256.hexdigest(ballot['email']),
				:email=> ballot['email'],
				:lastName=> ballot['lastname'],
				:firstName=> ballot['firstname'],
				:birthdate=> ballot['birthday'],
				:authorizedVotes=> [ballot['vote_id']],
				:exp=>(Time.new.getutc+VOTING_TIME_ALLOWED).to_i
			}
			vote_token=JWT.encode token, COCORICO_SECRET, 'HS256'
			res=Pages.db_query(@queries["update_citizen_hash"],[token[:sub],ballot['email']])
			return JSON.dump({'token'=>vote_token})
		end

		get '/citoyen/vote/:user_key' do
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
			#2 We check if a ballot has already been created
			res=Pages.db_query(@queries["get_ballot_by_email"],[citoyen['email']])
			if res.num_tuples.zero? then
				#2bis If no pre-existing ballot exist we create one for the citizen
				ballot=create_ballot(citoyen['email'])
			else
				ballot={'ballot_id'=>res[0]['ballot_id'],'candidates'=>[]}
				res.each { |r| ballot["candidates"].push(r) }
			end
			votes_left_to_cast=5
			ballot['candidates'].each do |candidate| 
				candidate['firstname']=candidate['name'].split(' ')[0]
				candidate['lastname']=candidate['name'].split(' ')[1]
				vote_status=candidate['vote_status']
				candidate['vote_status']="absent"
				candidate['vote_status']="pending" if (!vote_status.nil? && vote_status!="complete") #FIX following Jean-Marc webhook changes
				candidate['vote_status']="success" if vote_status=="complete" #FIX following Jean-Marc webhook changes
				votes_left_to_cast-=1 if candidate['vote_status']=='success'
				birthday=Date.parse(candidate['birthday'].split('?')[0]) unless candidate['birthday'].nil?
				age=nil
				unless birthday.nil? then
					now = Time.now.utc.to_date
					age = now.year - birthday.year - ((now.month > birthday.month || (now.month == birthday.month && now.day >= birthday.day)) ? 0 : 1)
				end
				candidate['age']=age
			end
			ballot['votes_left']=votes_left_to_cast

			#3 We register a new ballot access #LATER
			# access_ballot(citizen['email'],ballot['ballot_id'],request)

			erb :vote_citoyen, :locals=>{
				'auth'=>auth,
				'cocorico_app_id'=>COCORICO_APP_ID,
				'citoyen'=>citoyen,
				'ballot'=>ballot
			}
		end
	end
end
