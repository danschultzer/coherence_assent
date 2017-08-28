Code.require_file "../../mix_helpers.exs", __DIR__

defmodule Mix.Tasks.CoherenceAssent.InstallTest do
  use ExUnit.Case
  import MixHelper

  defmodule MigrationsRepo do
    def __adapter__ do
      true
    end

    def config do
      [priv: "tmp", otp_app: :coherence_assent]
    end
  end

  setup do
    :ok
  end

  @all_template_dirs ~w(auth registration)

  test "generates files" do
    in_tmp "generates_files", fn ->
      ~w( --no-migrations --no-update-coherence --web-path=./)
      |> Mix.Tasks.CoherenceAssent.Install.run

      ~w(registration)
      |> assert_dirs(@all_template_dirs, "templates/coherence/")
    end
  end

  test "does not generate files for no boilerplate" do
    in_tmp "does_not_generate_files_for_no_boilerplate", fn ->
      ~w(--no-boilerplate --no-migrations --no-update-coherence --web-path=./)
      |> Mix.Tasks.CoherenceAssent.Install.run

      ~w()
      |> assert_dirs(@all_template_dirs, "templates/coherence_assent/")
    end
  end

  test "updates coherence" do
    in_tmp "updates_coherence", fn ->
      File.mkdir_p!("lib/coherence_assent_web")
      Mix.Task.reenable "coh.install"
      Mix.Task.run "coh.install", ~w(--full --confirmable --invitable --no-config --repo=CoherenceAssent.Test.Repo --no-migrations --web-module=CoherenceAssent.Test.Web)

      ~w(--no-boilerplate)
      |> Mix.Tasks.CoherenceAssent.Install.run

      file_path = "lib/coherence_assent/coherence/user.ex"
      assert_file file_path, fn file ->
        assert file =~ "use Coherence.Schema"
        assert file =~ "use CoherenceAssent.Schema"
        assert file =~ "coherence_schema()"
        assert file =~ "coherence_assent_schema()"
        refute file =~ "|> validate_coherence(params)"
        assert file =~ "|> validate_coherence_assent(params)"
      end

      file_path = "lib/coherence_assent_web/views/coherence/coherence_view_helpers.ex"
      assert_file file_path, fn file ->
        assert file =~ "use CoherenceAssent.ViewHelpers, helpers: CoherenceAssent.Test.Web.Router.Helpers"
      end
      assert {{:module, _, _, _}, _} = Code.eval_file file_path

      file_path = "lib/coherence_assent_web/coherence_messages.ex"
      assert_file file_path, fn file ->
        assert file =~ "@behaviour CoherenceAssent.Messages"
        assert file =~ "def could_not_sign_in"
        assert file =~ "def identity_cannot_be_removed_missing_user_password"
        assert file =~ "def account_already_bound_to_other_user"
        assert file =~ "def login_with_provider"
        assert file =~ "def remove_provider_authentication"
        assert file =~ "def authentication_has_been_removed"
      end
      assert {{:module, _, _, _}, _} = Code.eval_file file_path

      file_path = "lib/coherence_assent_web/templates/coherence/registration/new.html.eex"
      assert_file file_path, fn file ->
        assert file =~ "<%= oauth_links(@conn) %>"
      end

      file_path = "lib/coherence_assent_web/templates/coherence/session/new.html.eex"
      assert_file file_path, fn file ->
        assert file =~ "<%= oauth_links(@conn) %>"
      end

      file_path = "lib/coherence_assent_web/templates/coherence/registration/edit.html.eex"
      assert_file file_path, fn file ->
        assert file =~ "<%= oauth_links(@conn, @current_user) %>"
      end
    end
  end

  test "adds migrations" do
    in_tmp "migrations", fn ->
      ~w(--no-templates --no-update-coherence --migration-path=./ --web-path=./)
      |> Mix.Tasks.CoherenceAssent.Install.run

      assert [_] = Path.wildcard("*_create_user_identities_tables.exs")
    end
  end

  def assert_dirs(dirs, full_dirs, path) do
    Enum.each dirs, fn dir ->
      assert File.dir? Path.join(path, dir)
    end
    Enum.each full_dirs -- dirs, fn dir ->
      refute File.dir? Path.join(path, dir)
    end
  end

  def assert_file_list(files, full_files, path) do
    Enum.each files, fn file ->
      assert_file Path.join(path, file)
    end
    Enum.each full_files -- files, fn file ->
      refute_file Path.join(path, file)
    end
  end
end
