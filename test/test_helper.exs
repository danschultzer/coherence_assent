defmodule TestHelpers do
  defp clear_path(path) do
    if File.dir? path do
      File.rm_rf! path
    end
    File.mkdir_p! path
  end

  defp save_app_file(path) do
    # Add app layout file
    layout_path = path <> "/templates/layout"
    File.mkdir_p! layout_path
    file_path = layout_path <> "/app.html.eex"
    {:ok, file} = File.open file_path, [:write]
    IO.binwrite file, "<%= render @view_module, @view_template, assigns %>"
    File.close file
    # EEx.compile_file(file_path, engine: Phoenix.HTML.Engine, trim: true)
  end

  def setup do
    web_path = "tmp/coherence/web"
    clear_path(web_path)
    save_app_file(web_path)
    clear_path("priv/test/migrations")
    install_coherence(web_path)
    reload_views()
    setup_db()
  end

  defp install_coherence(web_path) do
    Mix.Task.run "coh.install", ~w(--full --confirmable --invitable --no-config --no-models --no-views --no-web --no-messages --web-path=#{web_path} --repo=CoherenceAssent.Test.Repo --web-module=CoherenceAssent.Test.Web --silent)
    Mix.Task.run "coherence_assent.install", ~w(--no-update-coherence --web-path=#{web_path} --silent)
  end

  defp reload_views do
    Code.load_file("test/support/web/views/layout_view.ex")
    Code.load_file("test/support/web/views/registration_view.ex")
  end

  defp setup_db do
    Mix.Task.run "ecto.drop"
    Mix.Task.run "ecto.create"
    Mix.Task.run "ecto.migrate"
  end
end

Logger.configure(level: :error)
TestHelpers.setup()
Logger.configure(level: :info)

ExUnit.start()
Application.ensure_all_started(:bypass)

{:ok, _pid} = CoherenceAssent.Test.Web.Endpoint.start_link
{:ok, _pid} = CoherenceAssent.Test.Repo.start_link

Ecto.Adapters.SQL.Sandbox.mode(CoherenceAssent.Test.Repo, :manual)
