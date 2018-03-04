defmodule CoherenceAssent.Mix.Utils do
  @moduledoc false

  @spec raise_option_errors(list) :: no_return
  def raise_option_errors(list) do
    list
    |> Enum.map(fn option -> "--" <> Atom.to_string(option) |> String.replace("_", "-") end)
    |> Enum.join(", ")
    |> raise_unsupported
  end

  @spec raise_unsupported(list) :: no_return
  defp raise_unsupported(list) do
    Mix.raise """
    The following option(s) are not supported:
        #{inspect list}
    """
  end

  @spec verify_args!(list, list) :: nil | no_return
  def verify_args!(parsed, unknown) do
    unless Enum.empty?(parsed) do
      parsed
      |> Enum.join(", ")
      |> raise_invalid
    end

    unless Enum.empty?(unknown) do
      unknown
      |> Enum.map(&(elem(&1, 0)))
      |> Enum.join(", ")
      |> raise_invalid
    end
  end

  @spec raise_invalid(list) :: no_return
  defp raise_invalid(opts) do
    Mix.raise """
    Invalid argument(s) #{opts}
    """
  end
end
