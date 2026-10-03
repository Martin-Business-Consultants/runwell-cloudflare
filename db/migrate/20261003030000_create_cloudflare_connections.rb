# The Cloudflare account the plugin works in: an API token (encrypted) and what it set up there for
# requests by email (the zone, the Email Worker, the routing rule), so it can check and repeat it.
class CreateCloudflareConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :cloudflare_connections do |t|
      t.text :api_token
      t.string :account_id
      t.string :zone_id
      t.string :zone_name
      t.string :email_address
      t.string :worker_name
      t.string :email_rule_id
      t.datetime :email_set_up_at
      t.text :last_error
      t.datetime :last_error_at
      t.timestamps
    end
  end
end
