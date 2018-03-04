defmodule CoherenceAssent do
  @moduledoc """
  A module that provides multi provider authentication for your Coherence
  enabled Phoenix app.
  """

  @doc false
  @spec config(atom) :: Keyword.t | nil
  def config(provider) do
    Keyword.get(providers!(), String.to_atom(provider), nil)
  end

  @doc false
  @spec repo() :: Ecto.Repo.t | nil
  def repo, do: Coherence.Config.repo()

  @doc false
  @spec providers!() :: list | nil | no_return
  def providers! do
    Application.get_env(:coherence_assent, :providers) || raise "CoherenceAssent is missing the :providers configuration!"
  end

  defmodule CallbackError do
    defexception [:message, :error, :error_uri]
  end

  defmodule CallbackCSRFError do
    defexception message: "CSRF detected"
  end

  defmodule RequestError do
    defexception [:message, :error]
  end

  defmodule ConfigurationError do
    defexception [:message]
  end
end
