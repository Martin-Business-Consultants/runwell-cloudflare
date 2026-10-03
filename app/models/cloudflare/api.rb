require "net/http"

module Cloudflare
  # Cloudflare's API (api.cloudflare.com/client/v4) with the connection's token: JSON in and out,
  # and the multipart upload a Worker needs. Cloudflare's own error messages come back as Error.
  class Api
    class Error < StandardError; end

    BASE = "https://api.cloudflare.com/client/v4"

    def initialize(token)
      @token = token.presence or raise Error, "Add a Cloudflare API token first."
    end

    def get(path, params = {}) = call(Net::HTTP::Get, path, params: params)
    def post(path, body = {}) = call(Net::HTTP::Post, path, body: body)
    def put(path, body = {}) = call(Net::HTTP::Put, path, body: body)
    def patch(path, body = {}) = call(Net::HTTP::Patch, path, body: body)

    # A Worker in module syntax: its code and metadata (bindings, compatibility date) as parts.
    def upload_worker(account_id, name, code, metadata)
      boundary = "runwell#{SecureRandom.hex(12)}"
      body = [
        "--#{boundary}", %(Content-Disposition: form-data; name="metadata"), "Content-Type: application/json", "", metadata.to_json,
        "--#{boundary}", %(Content-Disposition: form-data; name="#{metadata[:main_module]}"; filename="#{metadata[:main_module]}"), "Content-Type: application/javascript+module", "", code,
        "--#{boundary}--", ""
      ].join("\r\n")
      call(Net::HTTP::Put, "/accounts/#{account_id}/workers/scripts/#{name}", raw: body, content_type: "multipart/form-data; boundary=#{boundary}")
    end

    private
      def call(verb, path, body: nil, params: {}, raw: nil, content_type: "application/json")
        uri = URI("#{BASE}#{path}")
        uri.query = URI.encode_www_form(params) if params.any?
        request = verb.new(uri)
        request["Authorization"] = "Bearer #{@token}"
        request["Content-Type"] = content_type
        request.body = raw || (body.to_json unless verb == Net::HTTP::Get)

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) { it.request(request) }
        answer = JSON.parse(response.body.presence || "{}")
        return answer["result"] if answer["success"]

        raise Error, Array(answer["errors"]).map { it["message"] }.compact_blank.to_sentence.presence || "Cloudflare answered #{response.code}"
      rescue JSON::ParserError
        raise Error, "Cloudflare answered #{response&.code} with something that isn't JSON"
      rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => error
        raise Error, "Couldn't reach Cloudflare: #{error.message}"
      end
  end
end
