defmodule BindocsisWeb.UserLive.Login do
  use BindocsisWeb, :live_view

  alias Bindocsis.Accounts
  alias Bindocsis.Accounts.Registration
  alias BindocsisWeb.Plugs.RateLimit
  alias BindocsisWeb.RateLimiter

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm space-y-4">
        <div class="text-center">
          <.header>
            <p>Log in</p>
            <:subtitle>
              <%= if @current_scope do %>
                You need to reauthenticate to perform sensitive actions on your account.
              <% else %>
                <%= if @registration_enabled do %>
                  Don't have an account? <.link
                    navigate={~p"/users/register"}
                    class="font-semibold text-brand hover:underline"
                    phx-no-format
                  >Sign up</.link> for an account now.
                <% end %>
              <% end %>
            </:subtitle>
          </.header>
        </div>

        <div :if={local_mail_adapter?()} class="alert alert-info">
          <.icon name="hero-information-circle" class="size-6 shrink-0" />
          <div>
            <p>You are running the local mail adapter.</p>
            <p>
              To see sent emails, visit <.link href="/dev/mailbox" class="underline">the mailbox page</.link>.
            </p>
          </div>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form_magic"
          action={~p"/users/log-in"}
          phx-submit="submit_magic"
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="email"
            required
            phx-mounted={JS.focus()}
          />
          <.button class="btn btn-primary w-full">
            Log in with email <span aria-hidden="true">→</span>
          </.button>
        </.form>

        <div class="divider">or</div>

        <.form
          :let={f}
          for={@form}
          id="login_form_password"
          action={~p"/users/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="email"
            required
          />
          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="current-password"
          />
          <.button class="btn btn-primary w-full" name={@form[:remember_me].name} value="true">
            Log in and stay logged in <span aria-hidden="true">→</span>
          </.button>
          <.button class="btn btn-primary btn-soft w-full mt-2">
            Log in only this time
          </.button>
        </.form>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok,
     assign(socket,
       form: form,
       trigger_submit: false,
       registration_enabled: Registration.enabled?(),
       client_ip: RateLimit.socket_ip(socket)
     )}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    # Email-bombing / enumeration guard (issue #13): a few links per address
    # per 15 minutes, and a per-IP ceiling. Both are checked before any
    # lookup so the response is identical for known and unknown emails.
    normalized = email |> String.trim() |> String.downcase() |> String.slice(0, 160)

    with :ok <- RateLimiter.check({:magic_email, normalized}, 3, :timer.minutes(15)),
         :ok <- RateLimiter.check({:magic_ip, socket.assigns.client_ip}, 20, :timer.minutes(15)) do
      case Accounts.get_user_by_email(email) do
        nil ->
          :ok

        user ->
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )
      end

      {:noreply,
       socket
       |> put_flash(:info, "If your email is in our system, login instructions have been sent.")
       |> push_navigate(to: ~p"/users/log-in")}
    else
      {:error, _retry_ms} ->
        {:noreply,
         socket
         |> put_flash(:error, "Too many login requests. Please try again later.")
         |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  defp local_mail_adapter? do
    Application.get_env(:bindocsis, Bindocsis.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
