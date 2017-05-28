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
index_candidats=Algolia::Index.new("candidats_legislatives")
candidates_list=<<END
SELECT e.slug as election_slug, c.code_departement,c.departement,c.name_circonscription,c.num_circonscription,u.email,u.slug,u.firstname,u.lastname,u.birthday,u.job,u.secteur,ce.accepted,ce.verified,ce.enrolled_at::DATE as enrolled_at, date_part('day',ce.verified_at::DATE) as verified_at,date_part('day',now() - ce.verified_at) as nb_days_verified,ce.qualified,ce.qualified_at,ce.official,ce.official_at,ce.fields->>'candidate' as supported_candidate, ce.fields->>'candidate_photo' as supported_candidate_photo, ce.fields->>'age' as age, ce.fields->>'vision', ce.fields->>'prio1', ce.fields->>'prio2', ce.fields->>'prio3',ce.fields->>'gender' as gender, u.photo, u.website, u.twitter, u.facebook, u.youtube,u.linkedin,u.blog,u.wikipedia,u.instagram, z.nb_soutiens, w.nb_soutiens_7j, y.nb_soutiens_30j
FROM users as u
INNER JOIN candidates_elections as ce ON (ce.email=u.email)
INNER JOIN elections as e ON (e.election_id=ce.election_id AND e.parent_election_id=2)
INNER JOIN circonscriptions as c ON (e.circonscription_id=c.id)
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

sitemap=<<END
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
END

res=db.exec(candidates_list)
if not res.num_tuples.zero? then
	res.each do |r|
		qualified = r['qualified'].to_b ? "oui" : "non"
		verified = r['verified'].to_b ? "verified" : "not_verified"
		official= r['official'].to_b ? "official" : "not_official"
		supported_candidate= r['supported_candidate'].nil? ? "Indépendant" : r['supported_candidate']
		supported_candidate_photo= r['supported_candidate_photo'].nil? ? "independant.jpg" : r['supported_candidate_photo']
		supported_candidate_visibility= r['supported_candidate'].nil? ? "invisible" : ""
		gender= r['gender']=='M' ? "Homme" : "Femme"
		birthday=Date.parse(r['birthday'].split('?')[0]) unless r['birthday'].nil?
		status="incomplete"
		unless r['vision'].nil? or r['vision'].empty? then
			status="complete"
		end
		#age=nil
		#unless birthday.nil? then
		#	now = Time.now.utc.to_date
		#	age = now.year - birthday.year - ((now.month > birthday.month || (now.month == birthday.month && now.day >= birthday.day)) ? 0 : 1)
		#end
		#if (r['verified'].to_b and not r['vision'].nil? and r['nb_soutiens_30j'].to_i>0) then
		if (r['verified'].to_b) then
			index_candidats.save_object({
				"objectID"=>r['email']+'-'+r['election_id'].to_s,
				"slug"=>r['slug'],
				"election_slug"=>r['election_slug'],
				"supported_candidate"=>supported_candidate,
				"supported_candidate_photo"=>supported_candidate_photo,
				"supported_candidate_visibility"=>supported_candidate_visibility,
				"code_departement"=>r['code_departement'],
				"num_departement"=>r['departement'],
				"name_circonscription"=>r['name_circonscription'],
				"num_circonscription"=>r['num_circonscription'].to_i,
				"name"=>r['firstname']+' '+r['lastname'],
				"photo"=>r['photo'],
				"gender"=>gender,
				"age"=>r['age'].to_i,
				"job"=>r['job'],
				"secteur"=>r['secteur'],
				"departement"=>r['departement'],
				"vision"=>r['vision'],
				"prio1"=>r['prio1'],
				"prio2"=>r['prio2'],
				"prio3"=>r['prio3'],
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
				"nb_soutiens_7j"=>r['nb_soutiens_7j'].to_i,
				"nb_views"=>r['nb_views'].to_i,
				"status"=>status
			})
			sitemap+=<<END
<url>
	<loc>https://legislatives.laprimaire.org/candidat/#{r['slug']}</loc>
	<lastmod>#{r['date_verified']}</lastmod>
</url>
END
			puts "Added candidat #{r['firstname']} #{r['lastname']}"
		end
	end
	sitemap+="</urlset>\n"
end
File.write(ARGV[0],sitemap)
