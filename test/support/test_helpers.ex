defmodule OAuth2.TestHelpers do
  def bypass_server(%Bypass{port: port}) do
    "http://localhost:#{port}"
  end
end
