defmodule Mix.Tasks.CoherenceAssent.Install do
  use Mix.Task

  import Macro, only: [camelize: 1]
  import Mix.Generator
  import Mix.Ecto
  import CoherenceAssent.Mix.Utils

  @shortdoc "Configure the CoherenceAssent Package"

  @moduledoc """
  Configure CoherenceAssent for your Phoenix/Coherence application.

  This installer will normally do the following unless given an option not to do so:
    * Update User schema installed by Coherence.
    * Update registration and session templates.
    * Generate appropriate migration files.
    * Generate appropriate template files.

  ## Examples
      mix coherence_assent.install

  ## Option list
    * Your Coherence user schema and Coherence templates will be modified unless the `--no-update-coherence` option is given.
    * A `--config-file config/config.exs` option can be given to change what config file to append to.
    * A `--installed-options` option to list the previous install options.
    * A `--silent` option to disable printing instructions
    * A `--web-path="lib/my_project_web"` option can be given to specify the web path
    * A `--migration-path` option to set the migration path
    * A `--module` option to override the module

  ## Disable Options
    * `--no-update-coherence` -- Don't update Coherence user file.
    * `--no-migrations` -- Don't create any migration files.
    * `--no-templates` -- Don't create the `WEB_PATH/templates/coherence_assent` files.
    * `--no-boilerplate` -- Don't create any of the boilerplate files.
  """

  @all_options       ~w(auth registration)
  @all_options_atoms Enum.map(@all_options, &(String.to_atom(&1)))
  @default_options   ~w(auth registration)

  # the options that default to true, and can be disabled with --no-option
  @default_booleans  ~w(templates boilerplate migrations update_coherence)

  # all boolean_options
  @boolean_options   @default_booleans ++ ~w(default) ++ @all_options

  @switches [
    module: :string, migration_path: :string, web_path: :string,
    silent: :boolean
  ] ++ Enum.map(@boolean_options, &({String.to_atom(&1), :boolean}))

  @switch_names Enum.map(@switches, &(elem(&1, 0)))

  @doc false
  def run(args) do
    {opts, parsed, unknown} = OptionParser.parse(args, switches: @switches)

    verify_args!(parsed, unknown)

    {bin_opts, opts} = parse_options(opts)

    opts
    |> do_config(bin_opts)
    |> do_run
  end

  defp do_run(config) do
    config
    |> validate_project_structure
    |> update_coherence_files
    |> gen_coherence_assent_templates
    |> gen_migration_files
    |> print_instructions
  end

  defp validate_project_structure(%{web_path: web_path} = config) do
    case File.lstat(web_path) do
      {:ok, %{type: :directory}} ->
        config
      _ ->
        if Mix.shell.yes?("Cannot find web path #{web_path}. Are you sure you want to continue?") do
          config
        else
          Mix.raise "Cannot find web path #{web_path}"
        end
    end
  end
  defp validate_project_structure(config), do: config

  defp validate_option(_, :all), do: true
  defp validate_option(%{opts: opts}, opt) do
    if opt in opts, do: true, else: false
  end

  ##################
  # Coherence Update

  defp update_coherence_files(%{update_coherence: true} = config) do
    config
    |> update_user_model
    |> update_coherence_view_helpers
    |> update_coherence_messages
    |> update_coherence_templates
  end
  defp update_coherence_files(config), do: config

  defp update_user_model(config) do
    user_path = lib_path("coherence/user.ex")
    case File.lstat(user_path) do
      {:ok, %{type: :regular}} -> update_user_model_file(user_path)
                                  config
      _ -> Mix.raise "Cannot find Coherence user model at #{user_path}"
    end
  end

  defp update_user_model_file(user_path) do
    user_path
    |> File.read()
    |> update_user_model_content(fn content -> add_after_in_content(content, "use Coherence.Schema", "use CoherenceAssent.Schema") end)
    |> update_user_model_content(fn content -> add_after_in_content(content, "coherence_schema()", "coherence_assent_schema()") end)
    |> update_user_model_content(fn content -> replace_in_content(content, "|> validate_coherence(params)", "|> validate_coherence_assent(params)") end)
    |> update_file(user_path)
  end

  defp update_user_model_content({:ok, content}, func) do
    func.(content)
  end
  defp update_user_model_content({:error, error}, _func),
    do: {:error, error}

  defp update_coherence_view_helpers(%{web_path: web_path} = config) do
    path = web_path |> Path.join("views/coherence/coherence_view_helpers.ex")
    needle = "@helpers WEBAPP.Router.Helpers"
    needle_regex = ~r/^((\s*)#{Regex.escape("@helpers ")}([\.\w]*)#{Regex.escape(".Router.Helpers")})$/m
    string = "use CoherenceAssent.ViewHelpers, helpers: \\3.Router.Helpers"

    path
    |> File.lstat()
    |> update_coherence_view_helpers_file(path, needle_regex, needle, string)
    |> add_to_file_instructions(config, path, string)
  end

  defp update_coherence_view_helpers_file({:ok, %{type: :regular}}, helpers_path, needle_regex, needle, string) do
    helpers_path
    |> File.read!()
    |> add_after_in_content(needle_regex, needle, string)
    |> update_file(helpers_path)
  end
  defp update_coherence_view_helpers_file({:error, error}, _helpers_path, _needle_regex, _needle, _string),
    do: {:error, error}

  defp update_coherence_messages(%{web_path: web_path} = config) do
    path = web_path |> Path.join("coherence_messages.ex")
    string = """

               @behaviour CoherenceAssent.Messages

               def could_not_sign_in, do: dgettext("coherence_assent", "Could not sign in. Please try again.")
               def identity_cannot_be_removed_missing_user_password, do: dgettext("coherence_assent", "Authentication cannot be removed until you've entered a password for your account.")
               def account_already_bound_to_other_user(opts), do: dgettext("coherence_assent", "The %{provider} account is already bound to another user.", opts)
               def login_with_provider(opts), do: dgettext("coherence_assent", "Sign in with %{provider}", opts)
               def remove_provider_authentication(opts), do: dgettext("coherence_assent", "Remove %{provider} authentication", opts)
               def authentication_has_been_removed(opts), do: dgettext("coherence_assent", "Authentication with %{provider} has been removed", opts)
             """
    regex = ~r/#{Regex.escape("def could_not_sign_in")}/

    path
    |> File.lstat()
    |> update_coherence_messages_file(path, regex, string)
    |> add_to_file_instructions(config, path, string)
  end

  defp update_coherence_messages_file({:ok, %{type: :regular}}, messages_path, regex, string) do
    messages_path
    |> File.read!()
    |> add_to_end_in_module(string, regex)
    |> update_file(messages_path)
  end
  defp update_coherence_messages_file({:error, error}, _messages_path, _regex, _string),
    do: {:error, error}

  defp update_coherence_templates(%{web_path: web_path} = config) do
    %{config: config, failed: []}
    |> update_coherence_template(web_path, "templates/coherence/session/new.html.eex", "<%= oauth_links(@conn) %>")
    |> update_coherence_template(web_path, "templates/coherence/registration/new.html.eex", "<%= oauth_links(@conn) %>")
    |> update_coherence_template(web_path, "templates/coherence/registration/edit.html.eex", "<%= oauth_links(@conn, @current_user) %>")
    |> update_coherence_templates_instructions()
  end

  defp update_coherence_template(%{failed: failed} = params, web_path, path, string) do
    path = Path.join(web_path, path)

    failed = path
    |> File.lstat()
    |> add_to_coherence_template_file(path, string)
    |>  case do
         {:error, error} -> failed ++ [path: path, string: string, error: error]
         {:ok, _file}    -> failed
       end

    Map.merge(params, %{failed: failed})
  end

  defp add_to_coherence_template_file({:ok, %{type: :regular}}, path, string) do
    content = File.read!(path)

    content
    |> String.contains?(string)
    |> case do
         true -> {:ok, content}
         _    -> {:ok, content <> "\n" <> string}
       end
    |> update_file(path)
  end
  defp add_to_coherence_template_file({:error, error}, _path, _string),
    do: {:error, error}

  defp update_coherence_templates_instructions(%{config: config, failed: [_ | _] = failed}) do
    messages = failed
             |> Enum.reduce([], fn failed, strings ->
                  strings ++ ["WARNING: Could not update \"#{failed[:path]}\". Please add \"#{failed[:string]}\" to the template file."]
                end)

    config
    |> Map.merge(%{
      instructions:
    """
    #{config.instructions}

    #{Enum.join(messages, "\n")}
    """
    })
  end
  defp update_coherence_templates_instructions(%{config: config}), do: config

  defp add_after_in_content(content, needle, replacement) when is_binary(needle) do
    add_after_in_content(content, ~r/^((\s*)#{Regex.escape(needle)})$/m, needle, replacement)
  end
  defp add_after_in_content(content, needle_regex, needle, replacement) do
    regex_replacement = "\\1\n\\2#{replacement}"

    replace(content, needle_regex, regex_replacement, needle, replacement)
  end

  defp replace_in_content(content, needle, replacement) do
    regex = ~r/#{Regex.escape(needle)}/

    replace(content, regex, replacement, needle, replacement)
  end

  defp add_to_end_in_module(string, insert, regex_needle) do
    regex = ~r/^defmodule(.*)end$/s
    regex_replacement = "defmodule\\1#{insert}end"
    case Regex.match?(regex_needle, string) do
      true  -> {:ok, string}
      false -> {:ok, Regex.replace(regex, string, regex_replacement, global: false)}
    end
  end

  defp replace(string, regex, regex_replacement, needle, replacement) do
    found_needle = Regex.match?(regex, string)
    found_replacement = Regex.match?(~r/#{Regex.escape(replacement)}/, string)

    case {found_needle, found_replacement} do
      {true, false}  -> {:ok, Regex.replace(regex, string, regex_replacement, global: false)}
      {false, true}  -> {:ok, string}
      {false, false} -> {:error, "Can't find \"#{needle}\" and replace with \"#{replacement}\""}
      {true, true}   -> {:ok, string}
    end
  end

  defp update_file({:ok, content}, path) do
    path
    |> File.write(content)
    |> case do
         :ok   -> {:ok, path}
         error -> error
       end
  end
  defp update_file({:error, error}, _path), do: {:error, error}

  ################
  # Templates

  @template_files [
    registration: {:registration, ~w(add_login_field)}
  ]

  defp gen_coherence_assent_templates(%{templates: true, boilerplate: true, binding: binding, web_path: web_path} = config) do
    for {name, {opt, files}} <- @template_files do
      if validate_option(config, opt), do: copy_templates(binding, name, files, web_path)
    end
    config
  end
  defp gen_coherence_assent_templates(config), do: config

  defp copy_templates(binding, name, file_list, web_path) do
    Mix.Phoenix.copy_from paths(),
      "priv/boilerplate/templates/#{name}", binding, copy_templates_files(name, file_list, web_path)
  end
  defp copy_templates_files(name, file_list, web_path) do
    for fname <- file_list do
      fname = "#{fname}.html.eex"
      {:eex, fname, Path.join(web_path, "templates/coherence/#{name}/#{fname}")}
    end
  end

  ################
  # Instructions

  defp router_instructions(%{base: base}) do
    """
    Configure your router.ex file the following way:

    defmodule #{base}.Router do
      use #{base}Web, :router
      use Coherence.Router
      use CoherenceAssent.Router         # Add this

      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug :fetch_flash
        plug :protect_from_forgery
        plug :put_secure_browser_headers
      end

      pipeline :public do
        plug Coherence.Authentication.Session
      end

      pipeline :protected do
        plug Coherence.Authentication.Session, protected: true
      end

      scope "/" do
        pipe_through [:browser, :public]
        coherence_routes()
        coherence_assent_routes()        # Add this
      end

      scope "/" do
        pipe_through [:browser, :protected]
        coherence_routes :protected
      end
      ...
    end
    """
  end

  defp migrate_instructions(%{boilerplate: true, migrations: true}) do
    """
    Don't forget to run the new migrations and seeds with:
        $ mix ecto.setup
    """
  end
  defp migrate_instructions(_), do: ""

  defp config_instructions(_) do
    """
    You can configure the OAuth client information the following way:

    config :coherence_assent, :providers, [
      github: [
        client_id: "REPLACE_WITH_CLIENT_ID",
        client_secret: "REPLACE_WITH_CLIENT_SECRET",
        strategy: CoherenceAssent.Strategy.Github
      ]
    ]

    Handlers exists for Facebook, Github, Google and Twitter.
    """
  end

  defp print_instructions(%{silent: true} = config), do: config
  defp print_instructions(%{instructions: instructions} = config) do
    shell_info instructions, config
    shell_info router_instructions(config), config
    shell_info migrate_instructions(config), config
    shell_info config_instructions(config), config

    config
  end

  ################
  # Utilities

  defp do_default_config(config, opts) do
    @default_booleans
    |> list_to_atoms
    |> Enum.reduce(config, fn opt, acc ->
      Map.put acc, opt, Keyword.get(opts, opt, true)
    end)
  end

  defp list_to_atoms(list), do: Enum.map(list, &(String.to_atom(&1)))

  defp paths do
    [".", :coherence_assent]
  end

  ############
  # Migrations

  defp gen_migration_files(%{boilerplate: true, migrations: true, repo: repo} = config) do
    ensure_repo(repo, [])

    path =
     case config[:migration_path] do
       path when is_binary(path) -> path
       _                         -> migrations_path(repo)
     end

    create_directory path
    existing_migrations = to_string File.ls!(path)

    for {name, template} <- migrations() do
      %{repo: repo, existing_migrations: existing_migrations, name: name,
        path: path, template: template, config: config}
      |> create_migration_file
    end

    config
  end
  defp gen_migration_files(config), do: config

  defp next_migration_number(existing_migrations, pad_time \\ 0) do
    timestamp = NaiveDateTime.utc_now
                |> NaiveDateTime.add(pad_time, :second)
                |> NaiveDateTime.to_erl
                |> padded_timestamp

    if String.match? existing_migrations, ~r/#{timestamp}_.*\.exs/ do
      next_migration_number(existing_migrations, pad_time + 1)
    else
      timestamp
    end
  end

  defp create_migration_file(%{repo: repo, existing_migrations: existing_migrations,
                               name: name, path: path, template: template, config: config}) do
    unless String.match? existing_migrations, ~r/\d{14}_#{name}\.exs/ do
      file = Path.join(path, "#{next_migration_number(existing_migrations)}_#{name}.exs")
      create_file file, EEx.eval_string(template, [mod: Module.concat([repo, Migrations, camelize(name)])])
      shell_info "Migration file #{file} has been added.", config
    end
  end

  defp padded_timestamp({{y, m, d}, {hh, mm, ss}}), do: "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  defp pad(i) when i < 10, do: << ?0, ?0 + i >>
  defp pad(i), do: to_string(i)

  defp migrations do
    templates_path = :coherence_assent
                     |> Application.app_dir
                     |> Path.join("priv/templates/migrations")

    for filename <- File.ls!(templates_path) do
      {String.slice(filename, 0..-5), File.read!(Path.join(templates_path, filename))}
    end
  end

  ################
  # Installer Configuration

  defp do_config(opts, []) do
    do_config(opts, list_to_atoms(@default_options))
  end
  defp do_config(opts, bin_opts) do
    binding = Mix.Project.config
    |> Keyword.fetch!(:app)
    |> Atom.to_string
    |> Mix.Phoenix.inflect

    base = opts[:module] || binding[:base]
    opts = Keyword.put(opts, :base, base)
    repo = Coherence.Config.repo
    web_path = opts[:web_path] || Mix.Phoenix.web_path(Mix.Phoenix.otp_app())

    binding = Keyword.put binding, :base, base

    bin_opts
    |> Enum.map(&({&1, true}))
    |> Enum.into(%{})
    |> Map.put(:web_path, web_path)
    |> Map.put(:instructions, "")
    |> Map.put(:base, base)
    |> Map.put(:opts, bin_opts)
    |> Map.put(:binding, binding)
    |> Map.put(:module, opts[:module])
    |> Map.put(:repo, repo)
    |> Map.put(:migration_path, opts[:migration_path])
    |> Map.put(:silent, opts[:silent])
    |> do_default_config(opts)
  end

  defp parse_options(opts) do
    {opts_bin, opts} = reduce_options(opts)
    opts_bin = Enum.uniq(opts_bin)
    opts_names = Enum.map opts, &(elem(&1, 0))

    with  [] <- Enum.filter(opts_bin, &(not &1 in @switch_names)),
          [] <- Enum.filter(opts_names, &(not &1 in @switch_names)) do
            {opts_bin, opts}
    else
      list -> raise_option_errors(list)
    end
  end
  defp reduce_options(opts) do
    Enum.reduce opts, {[], []}, fn
      {:default, true}, {acc_bin, acc} ->
        {list_to_atoms(@default_options) ++ acc_bin, acc}
      {name, true}, {acc_bin, acc} when name in @all_options_atoms ->
        {[name | acc_bin], acc}
      {name, false}, {acc_bin, acc} when name in @all_options_atoms ->
        {acc_bin -- [name], acc}
      opt, {acc_bin, acc} ->
        {acc_bin, [opt | acc]}
    end
  end

  defp shell_info(_message, %{silent: true} = config), do: config
  defp shell_info(message, config) do
    Mix.shell.info message
    config
  end

  defp lib_path(path) do
    Path.join ["lib", to_string(Mix.Phoenix.otp_app()), path]
  end

  defp add_to_file_instructions({:error, _}, config, path, string) do
    config
    |> Map.merge(%{
      instructions:
    """
    #{config.instructions}

    WARNING: Could not update #{path}. Please add the following to the file:

    #{string}

    """
    })
  end
  defp add_to_file_instructions({:ok, _}, config, _path, _string),
    do: config
end
