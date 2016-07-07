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
	class AdminCitoyen < Sinatra::Application
		def initialize(base)
			super(base)
			@queries={
				'get_citizen_by_key'=><<END,
SELECT c.telegram_id,c.firstname,c.lastname,c.email,c.reset_code,c.registered,c.country,c.user_key,c.validation_level,ci.zipcode,ci.name as city,ci.population,ci.departement
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
			}
		end

		configure do
			set :view, 'views'
			set :root, File.expand_path('../../',__FILE__)
		end

		get '/citoyen/:user_key' do
			email_updated=false
			begin
				Pages.db_init()
				res=Pages.db_query(@queries["get_citizen_by_key"],[params['user_key']])
				return erb :error, :locals=>{:msg=>{"title"=>"Page inconnue","message"=>"La page demandée n'existe pas"}} if res.num_tuples.zero?
				citizen=res[0]
				email=citizen['email']
				if not params['reset_email'].nil? then
					res1=Pages.db_query(@queries["reset_citizen_email"],[email])
					if not res1.num_tuples.zero? then
						citizen=res1[0]
						email=citizen['email']
						email_updated=true
					end
				end
			rescue PG::Error => e
				status 500
				return erb :error, :locals=>{:msg=>{"title"=>"Erreur serveur","message"=>e.message}}
			ensure
				Pages.db.close() unless Pages.db.nil?
			end
			if email_updated then
				erb :success, :locals=>{ :msg=>{ "title"=>"Email validé", "message"=>"Votre nouvel email (#{email}) a été mis à jour avec succès !" } }
			else
				status 500
				erb :error, :locals=>{ :msg=>{ "title"=>"Email inchangé", "message"=>"Votre email (#{email}) est resté inchangé" } }
			end
		end

=begin
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
				'account'=>account
			}
		end
=end
	end
end
