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
	class Circonscription < Sinatra::Application
		def initialize(base)
			super(base)
			@queries={
				'get_candidates_by_circonscription'=><<END,
SELECT c.code_departement,c.departement,c.name_circonscription,c.num_circonscription,u.email,u.slug,u.firstname,u.lastname,u.gender,u.birthday,u.job,u.secteur,ce.accepted,ce.verified,ce.enrolled_at::DATE as enrolled_at, date_part('day',ce.verified_at::DATE) as verified_at,date_part('day',now() - ce.verified_at) as nb_days_verified,ce.qualified,ce.qualified_at,ce.official,ce.official_at,ce.fields->>'vision', ce.fields->>'prio1', ce.fields->>'prio2', ce.fields->>'prio3', u.photo, u.website, u.twitter, u.facebook, u.youtube,u.linkedin,u.blog,u.wikipedia,u.instagram, z.nb_soutiens, w.nb_soutiens_7j, y.nb_soutiens_30j
FROM users as u
INNER JOIN candidates_elections as ce ON (ce.email=u.email AND ce.accepted)
INNER JOIN elections as e ON (e.election_id=ce.election_id AND e.hostname=$3)
INNER JOIN circonscriptions as c ON (e.circonscription_id=c.id AND c.num_circonscription=$2 AND c.departement=$1)
LEFT JOIN (
	SELECT count(s.supporter) as nb_soutiens, s.candidate, s.election_id
	FROM supporters as s
    INNER JOIN elections as e ON (e.election_id=s.election_id AND e.parent_election_id=2)
	GROUP BY s.candidate,s.election_id
) as z
ON (z.candidate=u.email AND z.election_id=e.election_id)
LEFT JOIN (
    SELECT count(s.supporter) as nb_soutiens_7j, s.candidate, s.election_id
	FROM supporters as s
    INNER JOIN elections as e ON (e.election_id=s.election_id AND e.parent_election_id=2)
    WHERE s.support_date> (now()::date-7)
	GROUP BY s.candidate,s.election_id
) as w
ON (w.candidate=u.email AND w.election_id=e.election_id)
LEFT JOIN (
    SELECT count(s.email) as nb_soutiens_30j, s.candidate, s.election_id
	FROM supporters as s
    INNER JOIN elections as e ON (e.election_id=s.election_id AND e.parent_election_id=2)
    WHERE s.support_date> (now()::date-30)
	GROUP BY s.candidate,s.election_id
) as y
ON (y.candidate=u.email AND y.election_id=e.election_id)
ORDER BY z.nb_soutiens DESC
END
			}
		end

		helpers do
			def page_info(infos=nil)
				info={
					'page_description'=>"desc",
					'page_author'=>"Des citoyens ordinaires",
					'page_image'=>"photo",
					'page_url'=>"https://laprimaire.org/qualifie/balbla", #FIXME
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
        
        subdomain do
            get '/departement/:dept/circonscription/:num' do
                candidates=[]
                begin
                    Pages.db_init()
                    res=Pages.db_query(@queries["get_candidates_by_circonscription"],[params['dept'],params['num'],request.host])
                    if not res.num_tuples.zero? then
                        res.each do |a|
                            candidates.push(a)
                        end
                    end
                rescue PG::Error => e
                    status 500
                    return erb :error, :locals=>{:msg=>{"title"=>"Erreur de base de données","message"=>e.message}}
                ensure
                    Pages.db_close()
                end
                erb :index, :locals=>{
                    'page_info'=>page_info(),
                    'template'=>:circonscription,
                    'vars'=>{'candidates'=>candidates}
                }
            end
        end
	end
end

