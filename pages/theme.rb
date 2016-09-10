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
	class Theme < Sinatra::Application
		def initialize(base)
			super(base)
			@queries={
				'get_articles_by_theme'=><<END,
SELECT c.name, c.slug, c.photo, a.*,at.name as theme, at.slug as theme_slug, pat.name as parent_theme, pat.slug as parent_theme_slug 
FROM articles as a 
INNER JOIN candidates as c ON (c.candidate_id=a.candidate_id)
INNER JOIN articles_themes as at ON (at.theme_id=a.theme_id) 
LEFT JOIN articles_themes as pat ON (pat.theme_id=at.parent_theme_id) 
WHERE pat.slug=$1 AND now() > a.date_published
ORDER BY a.date_published DESC
END
			}
		end

		helpers do
			def page_info(infos)
				info={
					'page_description'=>"desc",
					'page_author'=>"Des citoyens ordinaires",
					'page_image'=>"photo",
					'page_url'=>"https://laprimaire.org/qualifie/#{infos['name']}",
					'page_title'=>"title",
					'social_title'=>"social_title"
				}
				return info
			end
		end

		configure do
			set :view, 'views'
			set :root, File.expand_path('../../',__FILE__)
		end

		get '/theme/:name' do
			begin
				Pages.db_init()
				res=Pages.db_query(@queries["get_articles_by_theme"],[params["name"]])
				if not ['planete','societe','economie','institutions'].include?(params["name"]) then
					status 404
					return erb :error, :locals=>{:msg=>{"title"=>"Page thématique inconnue","message"=>"Cette page ne correspond à aucun thème"}}
				end
				articles=[]
				theme={
					'slug'=>params["name"],
					'name'=>params["name"].capitalize,
					'image'=>"#{AWS_S3_BUCKET_URL}themes/#{params['name']}.jpg",
					'articles'=>[]
				}
				if not res.num_tuples.zero? then
					res.each do |a|
						theme['name']=a['parent_theme'] if theme['name'].nil?
						a['date_published']=Date.parse(a['date_published']).strftime("%d/%m/%Y")
						a['firstname']=a['name'].split(' ')[0]
						a['lastname']=a['name'].split(' ')[1]
						a['photo_square']="#{AWS_S3_BUCKET_URL}qualifies/#{a['slug']}.jpg"
						a['image']="#{AWS_S3_BUCKET_URL}themes/#{a['theme_slug']}.jpg"
						theme['articles'].push(a)
					end
				end
			rescue PG::Error => e
				status 500
				return erb :error, :locals=>{:msg=>{"title"=>"Erreur de base de données","message"=>e.message}}
			ensure
				Pages.db_close()
			end
			erb :index, :locals=>{
				'page_info'=>page_info(theme),
				'template'=>:theme,
				'vars'=>theme
			}
		end
	end
end

