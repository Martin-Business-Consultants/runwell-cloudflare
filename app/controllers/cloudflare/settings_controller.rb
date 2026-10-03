# Settings > Cloudflare: the API token the plugin uses, and requests by email through Cloudflare
# Email Routing (set up, or set up again, with one button).
module Cloudflare
  class SettingsController < ::ApplicationController
    require_permission :manage_settings
    agent_tool :show_cloudflare_settings, on: :show, title: "Show the Cloudflare connection and requests by email through it"
    agent_exempt :update, reason: "the API token is entered by a person in the browser"

    before_action :set_connection

    def show
    end

    def update
      token = params.dig(:connection, :api_token).to_s.strip
      return redirect_to(cloudflare_settings_path, alert: "Paste the API token.") if token.blank?

      @connection.update!(api_token: token)
      redirect_to cloudflare_settings_path, notice: "Saved. Now set up requests by email below."
    end

    private
      def set_connection = @connection = Connection.for_settings
  end
end
