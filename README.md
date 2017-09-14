# CoherenceAssent

[![Build Status](https://travis-ci.org/danschultzer/coherence_assent.svg?branch=master)](https://travis-ci.org/danschultzer/coherence_assent)

Use Google, Github, Twitter, Facebook, or add your own strategy for authorization to your Coherence Phoenix app.

## Features

* Collects required login field if missing verified email from provider
* Multiple providers can be used for accounts
  * When removing auth: Validates user has password or another provider authentication
* Github, Google, Twitter and Facebook strategies included
* Updates Coherence templates automatically
* You can add your custom strategy with ease

## Installation

Add CoherenceAssent to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    # ...
    {:coherence_assent, git: "https://github.com/danschultzer/coherence_assent.git"}
    # ...
  ]
end
```

Run `mix deps.get` to install it.

Run to update all coherence files:

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
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Coherence.Router
  use CoherenceAssent.Router  # Add this

  scope "/", MyAppWeb do
    pipe_through [:browser, :public]
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

## Setting up a provider

Add the following to `config/config.exs`:

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

Strategies for Twitter, Facebook, Google and Github are included. You can add your own strategy. Here's an example of an OAuth 2.0 implementation:

```elixir
defmodule TestProvider do
  alias CoherenceAssent.Strategy.Helpers
  alias CoherenceAssent.Strategies.OAuth2, as: OAuth2Helper

  def authorize_url(conn: conn, config: config) do
    config = config |> set_config
    OAuth2Helper.authorize_url(conn: conn, config: config)
  end

  def callback(conn: conn, config: config, params: params) do
    config = config |> set_config
    OAuth2Helper.callback(conn: conn, config: config, params: params)
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
