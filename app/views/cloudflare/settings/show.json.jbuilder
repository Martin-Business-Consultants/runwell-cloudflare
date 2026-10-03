connection = @connection
json.summary(connection.email_set_up? ? "Requests by email come in through Cloudflare at #{connection.email_address}" : "Requests by email through Cloudflare aren't set up#{" (no API token yet)" unless connection.token?}")
json.token connection.token?
json.email_set_up connection.email_set_up?
json.email_address connection.email_address
json.zone connection.zone_name
json.worker connection.worker_name
json.set_up_at connection.email_set_up_at
json.last_error connection.last_error
json.receiving Setting.inbound_ingress == :relay
