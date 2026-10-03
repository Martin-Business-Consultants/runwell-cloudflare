module Cloudflare
  # A Runwell plugin for an install behind Cloudflare's proxy. With it on, a request that
  # arrived through Cloudflare carries the visitor's own address (from CF-Connecting-IP, trusted
  # only when the connection really came from a Cloudflare range) and counts as https when
  # Cloudflare received it over https, so approval evidence and portal sessions record the
  # right address and ASSUME_SSL isn't needed. The ranges are Cloudflare's published lists,
  # bundled and refreshed nightly. With an API token (Settings > Cloudflare) it also sets up
  # requests by email through Cloudflare Email Routing (Cloudflare::EmailRouting). One table.
  class Engine < ::Rails::Engine
    initializer "cloudflare.routes" do |app|
      app.routes.append do
        scope "cloudflare", module: "cloudflare", as: "cloudflare" do
          resource :settings, only: %i[show update]
          resource :email_routing, only: :create
        end
      end
    end

    # Before ActionDispatch::SSL (which redirects http) and RemoteIp (which reads the headers).
    initializer "cloudflare.middleware" do |app|
      if app.config.force_ssl
        app.middleware.insert_before ActionDispatch::SSL, Cloudflare::Middleware
      else
        app.middleware.insert_before ActionDispatch::RemoteIp, Cloudflare::Middleware
      end
    end

    config.to_prepare do
      Runwell::Plugins.register :cloudflare, name: "Cloudflare", version: Cloudflare::VERSION, author: "Runwell",
        enabled_by_default: false, requires: ">= 2.5.0", homepage: "https://github.com/Martin-Business-Consultants/runwell-cloudflare",
        description: "For an install behind Cloudflare’s proxy: records the visitor’s real address and treats a request Cloudflare received over https as https. With an API token, it also sets up requests by email through Cloudflare Email Routing, free, in one step."
      Runwell::Plugins.nightly :cloudflare, -> { Cloudflare::Ranges.refresh! }
      Runwell::Plugins.settings :cloudflare, "Cloudflare", -> { cloudflare_settings_path }
      Runwell::Plugins.slot :email_inbound, :cloudflare, "cloudflare/slots/email_inbound"
    end
  end
end
