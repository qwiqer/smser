require 'smser/version'

require 'smser/base'
require 'smser/sms_delivery'
require 'smser/message'

module Smser
  mattr_accessor :deliver_method
end
