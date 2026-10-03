module Cloudflare
  # Requests by email through Cloudflare Email Routing: mail to the requests address goes to an Email
  # Worker that posts it, as it arrived, to Runwell's relay (Action Mailbox), signed with the install's
  # inbound password. Setting up uploads the Worker with that password, turns Email Routing on for the
  # address's domain (a subdomain, so the main domain's mail is left alone) with plus addresses
  # honored (replies come back as requests+r42-…@), and routes the address to the Worker. Safe to
  # run again: each step finds what's there and puts it right.
  class EmailRouting
    WORKER = "runwell-requests"
    RULE = "Runwell requests"

    class Refused < StandardError; end

    def initialize(connection, api: Api.new(connection.api_token))
      @connection, @api = connection, api
    end

    def set_up!(address:, relay_url:, password:)
      domain = address.to_s.split("@", 2).last.to_s.downcase
      raise Refused, "Set the requests address in Settings › Email first." if domain.blank?

      zone = find_zone(domain)
      raise Refused, "Use an address on a subdomain (like requests@in.#{zone["name"]}): turning Email Routing on for #{zone["name"]} itself would move all of its mail to Cloudflare." if domain == zone["name"]

      upload_worker(zone.dig("account", "id"), relay_url, password)
      enable_routing(zone["id"], domain)
      honor_plus_addresses(zone["id"])
      rule_id = route(zone["id"], address)

      @connection.update!(account_id: zone.dig("account", "id"), zone_id: zone["id"], zone_name: zone["name"], email_address: address,
        worker_name: WORKER, email_rule_id: rule_id, email_set_up_at: Time.current, last_error: nil, last_error_at: nil)
    end

    # The zone the domain belongs to: the domain itself or the nearest parent the account holds.
    def find_zone(domain)
      labels = domain.split(".")
      (0...(labels.size - 1)).each do |start|
        zone = @api.get("/zones", name: labels[start..].join(".")).first
        return zone if zone
      end
      raise Refused, "#{domain} isn’t in a zone this token can see. Check the domain is on Cloudflare and the token covers it."
    end

    private
      def upload_worker(account_id, relay_url, password)
        @api.upload_worker(account_id, WORKER, Cloudflare::RequestsWorker.code,
          main_module: "worker.js", compatibility_date: "2025-01-01",
          bindings: [ { type: "plain_text", name: "RUNWELL_INBOX", text: relay_url },
                      { type: "secret_text", name: "RUNWELL_PASSWORD", text: password } ])
      end

      def enable_routing(zone_id, domain)
        @api.post("/zones/#{zone_id}/email/routing/dns", name: domain)
      rescue Api::Error => error
        raise unless error.message.match?(/already|exist/i)
      end

      # Best effort: an account where this setting can't be changed still routes the plain address.
      def honor_plus_addresses(zone_id)
        @api.patch("/zones/#{zone_id}/email/routing", support_subaddress: true)
      rescue Api::Error => error
        Rails.logger.warn "[cloudflare] plus addresses: #{error.message}"
      end

      def route(zone_id, address)
        rule = { name: RULE, enabled: true, matchers: [ { type: "literal", field: "to", value: address } ],
                 actions: [ { type: "worker", value: [ WORKER ] } ] }
        existing = Array(@api.get("/zones/#{zone_id}/email/routing/rules")).find { it["name"] == RULE }
        (existing ? @api.put("/zones/#{zone_id}/email/routing/rules/#{existing["id"]}", rule) : @api.post("/zones/#{zone_id}/email/routing/rules", rule))["id"]
      end
  end
end
