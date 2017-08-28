defmodule CoherenceAssent.Messages do
  @moduledoc """
  Interface for handling localization of build in CoherenceAssent messages.
  The following module defines the behaviour for rendering internal
  CoherenceAssent messages.
  The coherence_assent mix tasks adds to the coherence messages file in the
  user's app that uses this behaviour to ensure the user has implement all the
  required messages.
  """

  @callback could_not_sign_in()  :: binary
  @callback identity_cannot_be_removed_missing_user_password()  :: binary
  @callback account_already_bound_to_other_user([{atom, any}])  :: binary
  @callback login_with_provider([{atom, any}])  :: binary
  @callback remove_provider_authentication([{atom, any}])  :: binary
  @callback authentication_has_been_removed([{atom, any}])  :: binary

  @doc """
  Returns the Messages module from the users app's configuration
  """
  def backend do
    Coherence.Config.messages_backend()
  end
end
