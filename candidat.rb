require 'sinatra/base'
require 'sinatra/reloader'

GET_CANDIDATE=<<END
SELECT c.*, CASE WHEN s.soutiens is NULL THEN 0 ELSE s.soutiens END
  FROM candidates as c
    left join (
	    SELECT candidate_id,count(*) as soutiens
	    FROM supporters
	    GROUP BY candidate_id
      ) as s
  on (s.candidate_id = c.candidate_id)
WHERE c.uuid = $1;
END


module Democratech
	class Candidat < Sinatra::Base
		class << self
			attr_accessor :db
		end

		configure :development do
			register Sinatra::Reloader
		end

		get '/candidat/:uuid' do
			res=Candidat.db.exec_prepared("get_candidate",[params['uuid']])
			candidat=res[0]
			candidat['soutiens']=200
			candidat['soutiens']=candidat['soutiens']<=500 ? candidat['soutiens'] : 500
			m=(candidat['gender']=="M")
			gender={
				"le"=>m ? "le":"la",
				"ce"=>m ? "ce":"cette",
				"citoyen"=>m ? "citoyen":"citoyenne",
				"citoyens"=>m ? "citoyens":"citoyennes",
				"candidat"=>m ? "candidat":"candidate",
				"candidats"=>m ? "candidats":"candidates",
				"qualifié"=>m ? "qualifié":"qualifiée",
				"son"=>m ? "son":"sa"
			}
			candidat['photo']="https://bot.democratech.co/static/photos/%s%s" % [candidat['uuid'],File.extname(candidat['photo'])] if not candidat['photo'].nil?
			page={'url'=>"toto"}
			erb :candidat, :locals=>{:candidat=>candidat,:page=>page, :gender=>gender}
		end
	end
end
