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
	class Paiement < Sinatra::Application
		def initialize(base)
			super(base)
			@queries={
				'get_citizen_by_email'=>"SELECT email,firstname,lastname,city,zipcode,country FROM users WHERE email=$1"
			}
		end

		helpers do
			def strip_tags(text)
				return text.gsub(/<\/?[^>]*>/, "")
			end
		end

		configure do
			set :view, 'views'
			set :root, File.expand_path('../../',__FILE__)
		end

		get '/paiement/retour' do
			status=params['vads_trans_status']
			email=params['vads_cust_email']
			if (status!="AUTHORISED" && status!="CAPTURED") then
				redirect 'https://laprimaire.org/adherer/'
				return
			end
			citizen={}
			begin
				Pages.db_init()
				res=Pages.db_query(@queries["get_citizen_by_email"],[email])
				citizen=res[0] if !res.num_tuples.zero?
			rescue PG::Error => e
				status 500
				return erb :error, :locals=>{:msg=>{"title"=>"Erreur de base de données","message"=>strip_tags(e.message)}}
			ensure
				Pages.db_close()
			end
			erb :confirm_address, :locals=>{
				'page_info'=>{
					'page_description'=>"Confirmez l'adresse que nous ferons figurer sur votre reçu fiscal",
					'page_author'=>"Des citoyens ordinaires",
					'page_url'=>"https://laprimaire.org/paiement/retour",
					'page_title'=>"Confirmez votre adresse"
				},
				'citoyen'=>citizen,
				'params'=>params
			}
		end
	end
end
