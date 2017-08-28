defmodule CoherenceAssent.Test.Repo do
  use Ecto.Repo, otp_app: :coherence_assent

  def log(_cmd), do: nil
end
