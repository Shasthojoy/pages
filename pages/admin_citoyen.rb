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
SELECT c.telegram_id,c.firstname,c.lastname,c.email,c.reset_code,c.registered,c.country,c.user_key,c.validation_level,c.birthday,c.telephone,c.city,ci.zipcode,ci.population,ci.departement
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

			def access_ballot(email,ballot_id)
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
			if !success.empty() then
				return erb :success, :locals=>{:msg=>{"title"=>"Email mis à jour","message"=>success[0]}}
			elsif !errors.empty() then
				return erb :error, :locals=>{:msg=>{"title"=>"Email non mis à jour","message"=>errors[0]}}
			end
			return erb :error, :locals=>{:msg=>{"title"=>"Page inconnue","message"=>"La page demandée n'existe pas"}} if res.num_tuples.zero?
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
				'page_info'=>page_info({}),
				'template'=>:comparateur,
				'vars'=>{}
			}
		end

		get '/citoyen/auth/:user_key' do
			begin
				Pages.db_init()
				res=Pages.db_query(@queries["get_citizen_by_key"],[params['user_key']])
				return erb :error, :locals=>{:msg=>{"title"=>"Page inconnue","message"=>"La page demandée n'existe pas"}} if res.num_tuples.zero?
				citoyen=res[0]
			rescue PG::Error => e
				Pages.log.error "/citoyen/auth DB Error #{params}\n#{e.message}"
				status 500
				return erb :error, :locals=>{:msg=>{"title"=>"Erreur serveur","message"=>e.message}}
			ensure
				Pages.db_close()
			end
			redirect "/citoyen/vote/#{params['user_key']}/1" if (citoyen['validation_level'].to_i>2 && params['reauth'].nil?)
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

		get '/citoyen/vote/:user_key' do
				redirect "/citoyen/vote/#{params['user_key']}/1"
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
