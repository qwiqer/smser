require 'active_job'

module Smser
  # The <tt>Smser::DeliveryJob</tt> class is used when you
  # want to send emails outside of the request-response cycle.
  #
  # Exceptions are rescued and handled by the smser class.
  class DeliveryJob < ActiveJob::Base # :nodoc:
    queue_as { Smser::Base.deliver_later_queue_name }

    rescue_from StandardError, with: :handle_exception_with_smser_class

    def perform(smser, mail_method, delivery_method, *args) #:nodoc:
      smser.constantize.public_send(mail_method, *args).send(delivery_method)
    end

    private
    # "Deserialize" the smser class name by hand in case another argument
    # (like a Global ID reference) raised DeserializationError.
    def smser_class
      if smser = Array(@serialized_arguments).first || Array(arguments).first
        smser.constantize
      end
    end

    def handle_exception_with_smser_class(exception)
      if klass = smser_class
        klass.handle_exception exception
      else
        raise exception
      end
    end
  end
end
