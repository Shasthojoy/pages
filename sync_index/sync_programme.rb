require_relative '../config/keys.local.rb'
require 'csv'
require 'uri'
require 'net/http'
require 'json'
require 'pg'
require 'openssl'
require 'algoliasearch'
require 'wannabe_bool'

Algolia.init :application_id=>ALGOLIA_ID, :api_key=>ALGOLIA_KEY
index_programme=Algolia::Index.new("programmes")
file=CSV.read('programme.csv')
file.each_with_index do |p,i|
	index_programme.save_object({
		"objectID"=>i.to_s,
		"candidat"=>p[0],
		"candidat_slug"=>p[10],
		"candidat_photo"=>p[11],
		"link"=>p[3],
		"theme"=>p[1],
		"theme_slug"=>p[7],
		"parent_theme"=>p[8],
		"parent_theme_slug"=>p[9],
		"proposition"=>p[2],
		"priority"=>p[4]
	})
	puts "Saved programme #{p[1]} from #{p[0]}"
end
