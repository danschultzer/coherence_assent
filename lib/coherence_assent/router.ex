defmodule CoherenceAssent.Router do
  @moduledoc """
  Handles routing for CoherenceAssent.

  ## Usage

  Configure `lib/my_project/web/router.ex` the following way:

      defmodule MyProject.Router do
        use MyProjectWeb, :router
        use CoherenceAssent.Router

        scope "/", MyProjectWeb do
          pipe_through :browser

          coherence_assent_routes
        end

        ...
      end
  """

  defmacro __using__(_opts \\ []) do
    quote do
      import unquote(__MODULE__)
    end
  end

  @doc """
  CoherenceAssent router macro.
  Use this macro to define the CoherenceAssent routes.

  ## Examples:
      scope "/" do
        coherence_assent_routes
      end
  """
  defmacro coherence_assent_routes(options \\ %{}) do
    quote location: :keep do
      options = Map.merge(%{scope: "auth"}, unquote(Macro.escape(options)))

      scope "/#{options[:scope]}", as: "coherence_assent" do
        get "/:provider", CoherenceAssent.AuthController, :index
        get "/:provider/callback", CoherenceAssent.AuthController, :callback
        delete "/:provider", CoherenceAssent.AuthController, :delete
        get "/:provider/new", CoherenceAssent.RegistrationController, :add_login_field
        post "/:provider/create", CoherenceAssent.RegistrationController, :create
      end
    end
  end
end
