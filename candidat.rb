require 'sinatra/base'
require 'sinatra/reloader'

module Democratech
	class Candidat < Sinatra::Base
		class << self
			attr_accessor :db
		end

		configure :development do
			register Sinatra::Reloader
		end

		get '/candidat/:uuid' do
			res=Candidat.db.exec("SELECT * FROM candidates WHERE uuid='%s'" % [params['uuid']])
			puts params
			page={'url'=>"toto"}
			erb :candidat, :locals=>{:candidat=>res[0],:page=>page}
		end
	end
end
