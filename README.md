# CoherenceAssent

[![Build Status](https://travis-ci.org/danschultzer/coherence_assent.svg?branch=master)](https://travis-ci.org/danschultzer/coherence_assent)

Use Google, Github, Twitter, Facebook, Basecamp, or add your own strategy for authorization to your Coherence Phoenix app.

## Features

* Collects required login field if missing verified email from provider
* Multiple providers can be used for accounts
  * When removing auth: Validates user has password or another provider authentication
* Github, Google, Twitter, Facebook and Basecamp strategies included
* Updates Coherence templates automatically
* You can add your custom strategy with ease

## Installation

**Note:** This version requires Coherence v0.5. If you get dependency resolution failure with ecto when you install Coherence or coherence_assent, just run `mix deps.unlock ecto`.

Add CoherenceAssent to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    # ...
    {:coherence_assent, "~> 0.2.1"}
    # ...
  ]
end
```

Run `mix deps.get` to install it.

## Set up Coherence

You need to make sure the Coherence views and routes has been set up first. If this hasn't been done, follow the next steps.

Add all the Coherence files to your project:

```
mix coh.install --full --confirmable --invitable
```

Update routes:

```elixir
# lib/my_project_web/router.ex

defmodule MyProjectWeb.Router do
  use MyProjectWeb, :router
  use Coherence.Router                    # Add this

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Coherence.Authentication.Session # Add this
  end

  # Add this block
  pipeline :protected do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Coherence.Authentication.Session, protected: true
  end

  # ...

  # Add this block
  scope "/" do
    pipe_through :browser
    coherence_routes()
  end

  # Add this block
  scope "/" do
    pipe_through :protected
    coherence_routes :protected
  end

  # ...
end
```

## Getting started

Run to update all Coherence files:

```bash
mix coherence_assent.install
```

The install script will attempt to update the following files that Coherence have installed:

```
LIB_PATH/coherence/user.ex
WEB_PATH/templates/coherence/edit.html.eex
WEB_PATH/templates/coherence/new.html.eex
WEB_PATH/views/coherence/coherence_view_helpers.ex
WEB_PATH/coherence_messages.ex
```

If the files cannot be updated, install instructions will be printed instead. It's important that you update all files according to these instructions.

Set up routes:

```elixir
# lib/my_project_web/router.ex

defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Coherence.Router
  use CoherenceAssent.Router  # Add this

  # ...

  scope "/" do
    pipe_through [:browser]
    coherence_routes()
    coherence_assent_routes() # Add this
  end

  # ...
end
```

The following routes will now be available in your app:

```
coherence_assent_auth_path          GET    /auth/:provider            CoherenceAssent.AuthorizationController :new
coherence_assent_auth_path          GET    /auth/:provider/callback   CoherenceAssent.AuthorizationController :create
coherence_assent_registration_path  GET    /auth/:provider/new        CoherenceAssent.RegistrationController  :add_login_field
coherence_assent_registration_path  GET    /auth/:provider/create     CoherenceAssent.RegistrationController  :create
```

Remember to run the new migrations: `mix ecto.setup`

## Setting up a provider

Strategies for Twitter, Facebook, Google, Github and Basecamp are included. We'll go through how to set up the Github strategy.

First, register [a new app on Github](https://github.com/settings/applications/new) and add "http://localhost:4000/auth/github/callback" as callback URL. Then add the following to `config/config.exs` and add the client id and client secret:

```elixir
config :coherence_assent, :providers,
       [
         github: [
           client_id: "REPLACE_WITH_CLIENT_ID",
           client_secret: "REPLACE_WITH_CLIENT_SECRET",
           strategy: CoherenceAssent.Strategy.Github
        ]
      ]
```

Now start (or restart) your Phoenix app, and visit `http://localhost:4000/registrations/new`. You'll see a "Sign in with Github" link.

## Custom provider

You can add your own strategy. Here's an example of an OAuth 2.0 implementation:

```elixir
defmodule TestProvider do
  alias CoherenceAssent.Strategy.Helpers
  alias CoherenceAssent.Strategies.OAuth2, as: OAuth2Helper

  def authorize_url(conn, config) do
    OAuth2Helper.authorize_url(conn, set_config(config))
  end

  def callback(conn, config, params) do
    config = set_config(config)

    conn
    |> OAuth2Helper.callback(config, params)
    |> normalize
  end

  defp set_config(config) do
    [
      site: "http://localhost:4000/",
      authorize_url: "http://localhost:4000/oauth/authorize",
      token_url: "http://localhost:4000/oauth/access_token",
      user_url: "/user",
      authorization_params: [scope: "email profile"]
    ]
    |> Keyword.merge(config)
    |> Keyword.put(:strategy, OAuth2.Strategy.AuthCode)
  end

  defp normalize({:ok, %{conn: conn, client: client, user: user}}) do
    user = %{"uid"        => user["sub"],
             "name"       => user["name"],
             "email"      => user["email"]}
           |> Helpers.prune

    {:ok, %{conn: conn, client: client, user: user}}
  end
  defp normalize({:error, _} = error), do: error
end
```

## LICENSE

(The MIT License)

Copyright (c) 2017 Dan Schultzer & the Contributors Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
