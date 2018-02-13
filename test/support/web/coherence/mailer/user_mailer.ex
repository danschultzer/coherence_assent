defmodule CoherenceAssent.Coherence.UserEmail do
  import Swoosh.Email
  alias CoherenceAssent.Coherence.Mailer

  def confirmation(_user, _url) do
    %Swoosh.Email{}
    |> from({"Site", "site@example.com"})
    |> to({"User", "user@example.com"})
    |> subject("Confirm your new account")
    |> html_body("")
    |> text_body("")
  end
end