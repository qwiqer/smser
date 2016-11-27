require 'smser/rescuable'

module Smser
  class Base < AbstractController::Base
    include Rescuable

    class_attribute :default_params
    self.default_params = {}.freeze

    cattr_accessor :deliver_later_queue_name
    self.deliver_later_queue_name = :smsers

    class << self
      def default(value = nil)
        self.default_params = default_params.merge(value).freeze if value
        default_params
      end
      alias :default_options= :default

      def sms_path
        @sms_path ||= name.underscore
      end

      # Allows to set the name of current mailer.
      attr_writer :smser_name
      alias :controller_path :sms_path

      def method_missing(method_name, *args) # :nodoc:
        if action_methods.include?(method_name.to_s)
          Smser::SmsDelivery.new(self, method_name, *args)
        else
          super
        end
      end
    end

    attr_internal :message, :action_name

    def sms(to:, body: nil, from: nil, callback: nil)
      @_message ||= Message.new(
        to: to,
        from: from || default_params[:from],
        body: body || default_i18n_body,
        status_callback: callback || default_params[:status_callback]
      )
    end

    def process(method_name, *args) #:nodoc:
      @_action_name = method_name.to_s
      process_action(method_name, *args)
    end

    private

    def default_i18n_body(interpolations = {})
      mailer_scope = self.class.sms_path.tr('/', '.')
      I18n.t!(action_name, interpolations.merge(scope: [mailer_scope]))
    end
  end
end
