$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'pages'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'boot'

Bundler.require :default, ENV['RACK_ENV']
Dir[File.expand_path('../../pages/*.rb', __FILE__)].each do |f|
	STDERR.puts "loading #{f}"
	require f
end

require 'pages'
