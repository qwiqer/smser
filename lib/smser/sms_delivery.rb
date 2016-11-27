require 'smser/delivery_job'
require 'delegate'

module Smser
  # The <tt>ActionMailer::MessageDelivery</tt> class is used by
  # <tt>ActionMailer::Base</tt> when creating a new mailer.
  # <tt>MessageDelivery</tt> is a wrapper (+Delegator+ subclass) around a lazy
  # created <tt>Mail::Message</tt>. You can get direct access to the
  # <tt>Mail::Message</tt>, deliver the email or schedule the email to be sent
  # through Active Job.
  #
  #   Notifier.welcome(User.first)               # an ActionMailer::MessageDelivery object
  #   Notifier.welcome(User.first).deliver_now   # sends the email
  #   Notifier.welcome(User.first).deliver_later # enqueue email delivery as a job through Active Job
  #   Notifier.welcome(User.first).message       # a Mail::Message object
  class SmsDelivery < Delegator
    def initialize(smser_class, action, *args) #:nodoc:
      @smser_class, @action, @args = smser_class, action, args

      # The sms is only processed if we try to call any methods on it.
      # Typical usage will leave it unloaded and call deliver_later.
      @processed_smser = nil
      @sms_message = nil
    end

    # Method calls are delegated to the Mail::Message that's ready to deliver.
    def __getobj__ #:nodoc:
      @sms_message ||= processed_smser.message
    end

    # Unused except for delegator internals (dup, marshaling).
    def __setobj__(sms_message) #:nodoc:
      @sms_message = sms_message
    end

    # Returns the resulting Mail::Message
    def message
      __getobj__
    end

    # Was the delegate loaded, causing the smser action to be processed?
    def processed?
      @processed_smser || @sms_message
    end

    # Enqueues the esms to be delivered through Active Job. When the
    # job runs it will send the esms using +deliver_now!+. That means
    # that the message will be sent bypassing checking +perform_deliveries+
    # and +raise_delivery_errors+, so use with caution.
    #
    #   Notifier.welcome(User.first).deliver_later!
    #   Notifier.welcome(User.first).deliver_later!(wait: 1.hour)
    #   Notifier.welcome(User.first).deliver_later!(wait_until: 10.hours.from_now)
    #
    # Options:
    #
    # * <tt>:wait</tt> - Enqueue the esms to be delivered with a delay
    # * <tt>:wait_until</tt> - Enqueue the esms to be delivered at (after) a specific date / time
    # * <tt>:queue</tt> - Enqueue the esms on the specified queue
    def deliver_later!(options={})
      enqueue_delivery :deliver_now!, options
    end

    # Enqueues the esms to be delivered through Active Job. When the
    # job runs it will send the esms using +deliver_now+.
    #
    #   Notifier.welcome(User.first).deliver_later
    #   Notifier.welcome(User.first).deliver_later(wait: 1.hour)
    #   Notifier.welcome(User.first).deliver_later(wait_until: 10.hours.from_now)
    #
    # Options:
    #
    # * <tt>:wait</tt> - Enqueue the esms to be delivered with a delay.
    # * <tt>:wait_until</tt> - Enqueue the esms to be delivered at (after) a specific date / time.
    # * <tt>:queue</tt> - Enqueue the esms on the specified queue.
    def deliver_later(options={})
      enqueue_delivery :deliver_now, options
    end

    # Delivers an esms without checking +perform_deliveries+ and +raise_delivery_errors+,
    # so use with caution.
    #
    #   Notifier.welcome(User.first).deliver_now!
    #
    def deliver_now!
      processed_smser.handle_exceptions do
        message.deliver!
      end
    end

    # Delivers an esms:
    #
    #   Notifier.welcome(User.first).deliver_now
    #
    def deliver_now
      processed_smser.handle_exceptions do
        message.deliver
      end
    end

    private
    # Returns the processed Mailer instance. We keep this instance
    # on hand so we can delegate exception handling to it.
    def processed_smser
      @processed_smser ||= @smser_class.new.tap do |smser|
        smser.process @action, *@args
      end
    end

    def enqueue_delivery(delivery_method, options={})
      if processed?
        ::Kernel.raise "You've accessed the message before asking to " \
            "deliver it later, so you may have made local changes that would " \
            "be silently lost if we enqueued a job to deliver it. Why? Only " \
            "the smser method *arguments* are passed with the delivery job! " \
            "Do not access the message in any way if you mean to deliver it " \
            "later. Workarounds: 1. don't touch the message before calling " \
            "#deliver_later, 2. only touch the message *within your smser " \
            "method*, or 3. use a custom Active Job instead of #deliver_later."
      else
        args = @smser_class.name, @action.to_s, delivery_method.to_s, *@args
        ::Smser::DeliveryJob.set(options).perform_later(*args)
      end
    end
  end
end
