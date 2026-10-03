module Cloudflare
  # One row: the API token Runwell uses with Cloudflare (Settings > Cloudflare), and what it set
  # up there for requests by email.
  class Connection < ApplicationRecord
    self.table_name = "cloudflare_connections"

    encrypts :api_token

    validate { errors.add(:base, "There is already a Cloudflare connection") if new_record? && self.class.exists? }

    def self.current = first
    def self.for_settings = first || new
    def self.record = first || create!

    def token? = api_token.present?
    def email_set_up? = email_set_up_at.present?

    def note_error!(message) = update!(last_error: message.to_s.truncate(500), last_error_at: Time.current)
  end
end
