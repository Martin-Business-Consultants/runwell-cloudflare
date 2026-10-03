# Sets up (or repairs) requests by email through Cloudflare Email Routing: Runwell receives through
# its relay with a password of its own, and Cloudflare gets the Worker and the routing rule.
module Cloudflare
  class EmailRoutingsController < ::ApplicationController
    require_permission :manage_settings
    agent_tool :set_up_cloudflare_email, on: :create, title: "Set up requests by email through Cloudflare Email Routing",
      description: "Uses the Cloudflare token in Settings > Cloudflare and the requests address in Settings > Email: uploads the Email Worker, turns Email Routing on for the address's subdomain and routes the address to Runwell. Safe to run again."

    def create
      return redirect_to(cloudflare_settings_path, alert: "The Cloudflare plugin is switched off: switch it on in Settings › Plugins.") unless Runwell::Plugins.enabled?(:cloudflare)
      connection = Connection.current
      return redirect_to(cloudflare_settings_path, alert: "Add a Cloudflare API token first.") unless connection&.token?

      setting = ::Setting.current
      return redirect_to(cloudflare_settings_path, alert: "Set the requests address in Settings › Email first.") if setting.requests_email.blank?
      if ::Setting.inbound_from_environment? && ::Setting.inbound_ingress != :relay
        return redirect_to(cloudflare_settings_path, alert: "The server’s INBOUND_EMAIL_INGRESS says #{::Setting.inbound_ingress}; set it to relay (or remove it) to receive through Cloudflare.")
      end

      password = setting.receive_mail_through!(:relay)
      EmailRouting.new(connection).set_up!(address: setting.requests_email, relay_url: main_app.rails_relay_inbound_emails_url, password: password)
      redirect_to cloudflare_settings_path, notice: "Done. Mail to #{setting.requests_email} now comes to Runwell through Cloudflare. Send one to try it."
    rescue EmailRouting::Refused, Api::Error => error
      connection&.note_error!(error.message)
      redirect_to cloudflare_settings_path, alert: "Cloudflare: #{error.message}"
    end
  end
end
