# encoding: utf-8

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
	@@db=nil

	class << self
		attr_accessor :db
	end

	def self.db_init
		if ::DEBUG then
			@@db=PG.connect(
				"dbname"=>PGNAME_TEST,
				"user"=>PGUSER_TEST,
				"password"=>PGPWD_TEST,
				"host"=>PGHOST,
				"port"=>PGPORT
			)
		else
			@@db=PG.connect(
				"dbname"=>PGNAME,
				"user"=>PGUSER,
				"password"=>PGPWD,
				"host"=>PGHOST,
				"port"=>PGPORT
			)
		end
	end

	def self.db_query(query,params=nil)
		return params.nil? ? @@db.exec(query) : @@db.exec_params(query,params)
	end

	def self.db_close()
		@@db.close() unless @@db.nil?
	end

	class App < Sinatra::Application

		configure :development do
			 register Sinatra::Reloader
		end
		use Pages::Ville
		use Pages::Theme
		use Pages::Candidat
		use Pages::AdminCandidat
		use Pages::AdminCitoyen
	end
end
