defmodule CoherenceAssent.Strategy.Helpers do
  @moduledoc """
  Contains helper methods for strategies.
  """

  @doc false
  def prune(map) do
    map
    |> Enum.map(fn {k, v} -> if is_map(v), do: {k, prune(v)}, else: {k, v} end)
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Enum.into(%{})
  end
end
