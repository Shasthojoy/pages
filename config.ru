require File.expand_path('../config/environment', __FILE__)

require './config/keys.local.rb'

use Rack::Cors do
	allow do
		origins '*',''
		resource '*', headers: :any, methods: [:get]
	end
end

cookie_settings = {
	:path=>'/',
	:expire_after=>3600*24*30,
	:secret=>COOKIE_SECRET
}
if ::DEBUG then
	cookie_settings[:domain]='localhost'
	use Rack::Session::Cookie, cookie_settings
else
	cookie_settings[:domain]='*.laprimaire.org'
	cookie_settings[:secure]=true
	cookie_settings[:httponly]=true
	use Rack::Session::EncryptedCookie, cookie_settings
end
use Rack::Csrf, :raise=>true

COCORICO_HOST=::DEBUG ? CC_HOST_TEST : CC_HOST
COCORICO_APP_ID=::DEBUG ? CC_APP_ID_TEST : CC_APP_ID
COCORICO_SECRET=::DEBUG ? CC_SECRET_TEST : CC_SECRET
API_HOST=::DEBUG ? API_HOST_TEST : API_HOST_PROD
BOT_HOST=::DEBUG ? BOT_HOST_TEST : BOT_HOST_LIVE
Pages.log=Logger.new(::DEBUG ? STDOUT : STDERR)
Pages.log.level= ::DEBUG ? Logger::DEBUG : Logger::WARN
Pages.aws=Aws::S3::Resource.new(credentials: Aws::Credentials.new(AWS_API_KEY,AWS_API_SECRET),region: AWS_REGION)
run Pages::App
