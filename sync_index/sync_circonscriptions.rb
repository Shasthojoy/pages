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
index_circos=Algolia::Index.new("circonscriptions")
circos_list=<<END
SELECT e.slug as election_slug,c.circonscription_id,c.departement,c.code_departement,c.num_commune,c.name_commune,c.num_circonscription,c.departement,c.name_circonscription,deputy_name,deputy_gender,date_part('year',age(deputy_birthday)) as deputy_age,deputy_group,deputy_party,deputy_url,deputy_mandates,deputy_election,deputy_job,deputy_twitter,cit.population
FROM circos AS c
INNER JOIN elections AS e ON (e.circonscription_id=c.circonscription_id)
INNER JOIN cities AS cit ON (cit.city_id=c.city_id)
ORDER BY departement,num_circonscription DESC
END

res=db.exec(circos_list)
if not res.num_tuples.zero? then
    old=nil
    batch=[]
	res.each do |r|
		dept=r['departement'].nil? ? '999' : r['departement']
		circo=r['num_circonscription']
		new=dept+'-'+circo
		numcommune=r['num_commune'].nil? ? '0' : r['num_commune']
		id=new+'-'+numcommune
		deputy_election=r['deputy_election'].nil? ? nil : Date.parse(r['deputy_election'])
		age=r['deputy_age'].nil? ? nil : r['deputy_age'].to_i
		deptnum=r['departement'].nil? ? 999 : r['departement'].to_i
		citynum=r['num_commune'].nil? ? nil : r['num_commune'].to_i
		mandates=r['deputy_mandates'].nil? ? nil : r['deputy_mandates'].to_i
		batch.push({
			"objectID"=>id,
			"departement"=>deptnum,
			"circonscription_id"=>r['circonscription_id'],
			"election_slug"=>r['election_slug'],
			"code_departement"=>r['code_departement'],
			"num_commune"=>citynum,
			"name_commune"=>r['name_commune'],
			"num_circonscription"=>r['num_circonscription'].to_i,
			"name_circonscription"=>r['name_circonscription'],
			"deputy_name"=>r['deputy_name'],
			"deputy_gender"=>r['deputy_gender'],
			"deputy_election"=>deputy_election,
			"deputy_age"=>age,
			"deputy_group"=>r['deputy_group'],
			"deputy_party"=>r['deputy_party'],
			"deputy_url"=>r['deputy_url'],
			"deputy_mandates"=>mandates,
			"deputy_job"=>r['deputy_job'],
			"deputy_twitter"=>r['deputy_twitter'],
			"population"=>r['population'].to_i
		})
		if old!=new then
			old=new
			puts "Saving departement circo #{circo} from dept #{dept} (pop: #{r['population']})"
		end
	end
    #puts JSON.dump(batch)
    index_circos.add_objects(batch)
end
