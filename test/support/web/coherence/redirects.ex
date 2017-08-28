defmodule Coherence.Redirects do
  use Redirects

  def session_create(conn, _), do: redirect(conn, to: "/session_created")
  def registration_create(conn, _), do: redirect(conn, to: "/registration_created")
end
