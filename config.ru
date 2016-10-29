require File.expand_path('../config/environment', __FILE__)

require './config/keys.local.rb'
COCORICO_HOST=DEBUG ? CC_HOST_TEST : CC_HOST
COCORICO_APP_ID=DEBUG ? CC_APP_ID_TEST : CC_APP_ID
COCORICO_SECRET=DEBUG ? CC_SECRET_TEST : CC_SECRET
API_HOST=DEBUG ? API_HOST_TEST : API_HOST_PROD
Pages.log=Logger.new(::DEBUG ? STDOUT : STDERR)
Pages.log.level= ::DEBUG ? Logger::DEBUG : Logger::WARN

run Pages::App
