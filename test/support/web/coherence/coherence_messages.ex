defmodule CoherenceAssent.Test.Coherence.Messages do
  @moduledoc false
  @behaviour Coherence.Messages
  @domain "coherence"

  def cant_be_blank, do: dgettext(@domain, "can't be blank")
  def mailer_required, do: dgettext(@domain, "Mailer configuration required!")
  def invalid_request, do: dgettext(@domain, "Invalid Request.")

  def could_not_sign_in, do: dgettext("coherence_assent", "Could not sign in. Please try again.")
  def identity_cannot_be_removed_missing_user_password, do: dgettext("coherence_assent", "Authentication cannot be removed until you've entered a password for your account.")
  def account_already_bound_to_other_user(opts), do: dgettext("coherence_assent", "The %{provider} account is already bound to another user.", opts)
  def login_with_provider(opts), do: dgettext("coherence_assent", "Sign in with %{provider}", opts)
  def remove_provider_authentication(opts), do: dgettext("coherence_assent", "Remove %{provider} authentication", opts)
  def authentication_has_been_removed(opts), do: dgettext("coherence_assent", "Authentication with %{provider} has been removed", opts)
  def confirmation_email_sent, do: dgettext(@domain, "Confirmation email sent.")

  def dgettext(domain, msg, opts \\ %{}), do: msg
end
