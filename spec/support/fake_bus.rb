module Support
  class FakeBus
    attr_reader :published

    def initialize
      @published = []
    end

    def publish(envelope)
      @published << envelope
    end
  end
end
