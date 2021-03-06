defmodule CoherenceAssent.Test.Web do
  @moduledoc false

  def view do
    quote do
      use Phoenix.View, root: "tmp/coherence/web/templates"

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_csrf_token: 0, get_flash: 2, view_module: 1]

      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      import CoherenceAssent.Test.Web.Gettext
      import CoherenceAssent.Test.Web.ErrorHelpers
      import CoherenceAssent.Test.Web.Router.Helpers
      import CoherenceAssent.Test.Coherence.ViewHelpers
    end
  end
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
