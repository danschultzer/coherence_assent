use Mix.Config

config :coherence,
  user_schema: CoherenceAssent.Test.User,
  repo: CoherenceAssent.Test.Repo,
  module: CoherenceAssent.Test,
  web_module: CoherenceAssent,
  router: CoherenceAssent.Test.Web.Router,
  messages_backend: CoherenceAssent.Test.Coherence.Messages,
  logged_out_url: "/logged_out",
  email_from_name: "Your Name",
  email_from_email: "yourname@example.com",
  opts: [:authenticatable, :recoverable, :lockable, :trackable, :unlockable_with_token, :confirmable, :registerable]

config :coherence, CoherenceAssent.Coherence.Mailer,
  adapter: Swoosh.Adapters.Test

config :coherence_assent, ecto_repos: [CoherenceAssent.Test.Repo]
config :coherence_assent, CoherenceAssent.Test.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "coherence_assent_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "priv/test"

config :coherence_assent, CoherenceAssent.Test.Web.Endpoint,
  secret_key_base: "1lJGFCaor+gPGc21GCvn+NE0WDOA5ujAMeZoy7oC5un7NPUXDir8LAE+Iba5bpGH",
  render_errors: [view: CoherenceAssent.ErrorView, accepts: ~w(html json)]
