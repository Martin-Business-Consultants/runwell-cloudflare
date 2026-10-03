module Cloudflare
  # The Email Worker that hands each email to Runwell: the message exactly as it arrived, posted to
  # the relay with the install's inbound password. If Runwell refuses it, the sender gets a bounce
  # saying so, rather than the mail vanishing.
  module RequestsWorker
    def self.code = <<~JS
      export default {
        async email(message, env) {
          const raw = await new Response(message.raw).arrayBuffer()
          const response = await fetch(env.RUNWELL_INBOX, {
            method: "POST",
            headers: {
              "Content-Type": "message/rfc822",
              "Authorization": "Basic " + btoa("actionmailbox:" + env.RUNWELL_PASSWORD)
            },
            body: raw
          })
          if (!response.ok) message.setReject(`Runwell couldn't take this message (${response.status}). Please try again later.`)
        }
      }
    JS
  end
end
