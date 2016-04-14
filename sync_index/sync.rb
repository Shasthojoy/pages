require_relative '../config/keys.local.rb'
require 'csv'
require 'uri'
require 'net/http'
require 'json'
require 'pg'
require 'openssl'
require 'algoliasearch'
require 'wannabe_bool'

db=PG.connect(
	"dbname"=>PGNAME,
	"user"=>PGUSER,
	"password"=>PGPWD,
	"host"=>PGHOST,
	"port"=>PGPORT
)
Algolia.init :application_id=>ALGOLIA_ID, :api_key=>ALGOLIA_KEY
index_candidats=Algolia::Index.new("candidates")
index_citoyens=Algolia::Index.new("citizens")
candidates_list=<<END
SELECT ca.candidate_id,ca.user_id,ca.name,ca.gender,ca.verified,ca.date_added,date_part('day',now()-ca.date_added) as nb_days_added,ca.date_verified,date_part('day',now() - ca.date_verified) as nb_days_verified,ca.qualified,ca.date_qualified,ca.official,ca.date_officialized,ca.photo,ca.trello,ca.website,ca.twitter,ca.facebook,ca.youtube,ca.linkedin,ca.tumblr,ca.blog,ca.wikipedia,ca.instagram, z.nb_views, z.nb_soutiens
FROM candidates as ca
LEFT JOIN (
       SELECT y.candidate_id, y.nb_views, count(s.user_id) as nb_soutiens
 FROM (
		SELECT c.candidate_id, sum(cv.nb_views) as nb_views
		  FROM candidates as c
		  LEFT JOIN candidates_views as cv
		    ON (
			       cv.candidate_id=c.candidate_id
		       )
		 GROUP BY c.candidate_id
	) as y
	LEFT JOIN supporters as s
	ON ( s.candidate_id=y.candidate_id)
	GROUP BY y.candidate_id,y.nb_views
) as z
ON (z.candidate_id = ca.candidate_id)
END

sitemap=<<END
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
<script/>
END

res=db.exec(candidates_list)
if not res.num_tuples.zero? then
	res.each do |r|
		qualified = r['qualified'].to_b ? "qualified" : "not_qualified"
		verified = r['verified'].to_b ? "verified" : "not_verified"
		official= r['official'].to_b ? "official" : "not_official"
		gender= r['gender']=='M' ? "Homme" : "Femme"
		if (r['verified'].to_b) then
			index_candidats.save_object({
				"objectID"=>r['candidate_id'],
				"candidate_id"=>r['candidate_id'],
				"name"=>r['name'],
				"photo"=>r['photo'],
				"gender"=>gender,
				"trello"=>r['trello'],
				"website"=>r['website'],
				"twitter"=>r['twitter'],
				"facebook"=>r['facebook'],
				"youtube"=>r['youtube'],
				"linkedin"=>r['linkedin'],
				"tumblr"=>r['tumblr'],
				"blog"=>r['blog'],
				"wikipedia"=>r['wikipedia'],
				"instagram"=>r['instagram'],
				"date_added"=>r['date_added'],
				"nb_days_added"=>r['nb_days_added'].to_i,
				"verified"=>verified,
				"date_verified"=>r['date_verified'],
				"nb_days_verified"=>r['nb_days_verified'].to_i,
				"qualified"=>qualified,
				"date_qualified"=>r['date_qualified'],
				"official"=>official,
				"date_officializied"=>r['date_officializied'],
				"nb_soutiens"=>r['nb_soutiens'].to_i,
				"nb_views"=>r['nb_views'].to_i
			})
			sitemap+=<<END
<url>
	<loc>https://laprimaire.org/candidat/#{r['candidate_id']}</loc>
	<lastmod>#{r['date_verified']}</lastmod>
</url>
END
			puts "Added candidat #{r['name']}"
		elsif r['nb_soutiens'].to_i>1
			index_citoyens.save_object({
				"objectID"=>r['candidate_id'],
				"candidate_id"=>r['candidate_id'],
				"name"=>r['name'],
				"photo"=>r['photo'],
				"gender"=>gender,
				"date_added"=>r['date_added'],
				"nb_days_added"=>r['nb_days_added'].to_i,
				"nb_soutiens"=>r['nb_soutiens'].to_i,
				"nb_views"=>r['nb_views'].to_i
			})
			sitemap+=<<END
<url>
	<loc>https://laprimaire.org/candidat/#{r['candidate_id']}</loc>
	<lastmod>#{r['date_added']}</lastmod>
</url>
END
			puts "Added citoyen #{r['name']}"
		else
			puts "Skipped citoyen #{r['name']}"
		end
	end
	sitemap+="</urlset>\n"
end
File.write(ARGV[0],sitemap)
