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
index_articles=Algolia::Index.new("articles")
articles_list=<<END
SELECT c.name, c.slug, c.photo, a.*,at.name as theme, at.slug as theme_slug, pat.name as parent_theme, pat.slug as parent_theme_slug 
FROM articles as a 
INNER JOIN candidates as c ON (c.candidate_id=a.candidate_id)
INNER JOIN articles_themes as at ON (at.theme_id=a.theme_id) 
LEFT JOIN articles_themes as pat ON (pat.theme_id=at.parent_theme_id) 
WHERE now() > a.date_published
ORDER BY a.date_published DESC
END

res=db.exec(articles_list)
if not res.num_tuples.zero? then
	res.each do |r|
		index_articles.save_object({
			"objectID"=>r['article_id'],
			"slug"=>r['slug'],
			"theme"=>r['theme'],
			"theme_slug"=>r['theme_slug'],
			"parent_theme"=>r['parent_theme'],
			"parent_theme_slug"=>r['parent_theme_slug'],
			"published_url"=>r['published_url'],
			"date_published"=>r['date_published'],
			"candidate_id"=>r['candidate_id'],
			"name"=>r['name'],
			"title"=>r['title'],
			"photo_square"=>"#{AWS_S3_BUCKET_URL}qualifies/#{r['slug']}.jpg",
		})
		puts "Saved article #{r['title']} from #{r['name']}"	
	end
end
