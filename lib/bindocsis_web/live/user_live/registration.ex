defmodule BindocsisWeb.UserLive.Registration do
  use BindocsisWeb, :live_view

  alias Bindocsis.Accounts
  alias Bindocsis.Accounts.Registration
  alias Bindocsis.Accounts.User
  alias BindocsisWeb.Plugs.RateLimit
  alias BindocsisWeb.RateLimiter

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            Register for an account
            <:subtitle>
              Already registered?
              <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
                Log in
              </.link>
              to your account now.
            </:subtitle>
          </.header>
        </div>

        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            required
            phx-mounted={JS.focus()}
          />

          <.button phx-disable-with="Creating account..." class="btn btn-primary w-full">
            Create an account
          </.button>
        </.form>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: BindocsisWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    if Registration.enabled?() do
      changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)

      {:ok,
       socket
       |> assign(:client_ip, RateLimit.socket_ip(socket))
       |> assign_form(changeset), temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Registration is closed on this server.")
       |> redirect(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    with :ok <- RateLimiter.check({:register_ip, socket.assigns.client_ip}, 5, :timer.hours(1)),
         {:ok, user} <- Accounts.register_user(user_params) do
      {:ok, _} =
        Accounts.deliver_login_instructions(
          user,
          &url(~p"/users/log-in/#{&1}")
        )

      {:noreply,
       socket
       |> put_flash(
         :info,
         "An email was sent to #{user.email}, please access it to confirm your account."
       )
       |> push_navigate(to: ~p"/users/log-in")}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, _retry_ms} ->
        {:noreply,
         put_flash(socket, :error, "Too many registration attempts. Please try again later.")}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_email(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
