defmodule CoherenceAssent.Test.Web.ViewHelpers do
  use Phoenix.HTML
  use CoherenceAssent.ViewHelpers, helpers: Coherence.ControllerHelpers.router_helpers()

  @type conn :: Plug.Conn.t

  defp concat([], acc), do: Enum.reverse(acc)
  defp concat([h|t], []), do: concat(t, [h])
end
