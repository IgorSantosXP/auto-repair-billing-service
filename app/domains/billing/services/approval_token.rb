require "digest"

module Billing
  module Services
    # The plain token only travels in the e-mail; the database keeps its SHA256 digest.
    class ApprovalToken
      TTL = 72.hours

      def self.generate
        plain = SecureRandom.urlsafe_base64(32)
        { plain: plain, digest: Digest::SHA256.hexdigest(plain), expires_at: TTL.from_now }
      end

      def self.valid?(plain_token, stored_digest, expires_at)
        return false if plain_token.blank? || stored_digest.blank? || expires_at.nil? || Time.current > expires_at

        generated = Digest::SHA256.hexdigest(plain_token.to_s)
        ActiveSupport::SecurityUtils.secure_compare(generated, stored_digest.to_s)
      end
    end
  end
end
