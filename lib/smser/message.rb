module Smser
  class Message
    attr_reader :to, :from, :body, :options

    def initialize(to:, from:, body:, **options)
      @to = to
      @from = from
      @body = body
      @options = options
    end

    def deliver
      Smser.deliver_method.call(self)
    end
  end
end
