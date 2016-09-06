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
	class Ville < Sinatra::Application
		def initialize(base)
			super(base)
			@queries={
				'get_ville'=><<END,
SELECT c.*, count(users.city_id) as users_nb
FROM cities c
LEFT OUTER JOIN users ON (c.city_id = users.city_id)
WHERE c.slug = $1
GROUP BY c.city_id
ORDER BY c.zipcode;
END
		}
		end

		configure do
			set :view, 'views'
			set :root, File.expand_path('../../',__FILE__)
		end

		get '/ville/:ville_slug' do
			begin
				Pages.db_init()
				res=Pages.db_query(@queries["get_ville"],[params['ville_slug']])
			rescue PG::Error => e
				status 500
				return erb :error, :locals=>{:msg=>{"title"=>"Erreur serveur","message"=>e.message}}
			ensure
				Pages.db.close() unless Pages.db.nil?
			end
			if res.num_tuples.zero? then
				status 404
				return erb :error, :locals=>{:msg=>{"title"=>"Page Ville inconnue","message"=>"Cette page ne correspond à aucune ville"}}
			end
			erb :ville, :locals=>{
					:villes => res
			}
		end

	end
end
