defmodule BindocsisWeb.ErrorHTML do
  @moduledoc """
  Error pages for the standalone Bindocsis web interface.
  """

  use Phoenix.Component

  def render("404.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" class="h-full">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Page Not Found - Bindocsis</title>
        <style>
          body {
            background-color: #111827;
            color: #f3f4f6;
            font-family: system-ui, -apple-system, sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
          }
          .container {
            text-align: center;
            padding: 2rem;
          }
          h1 {
            font-size: 6rem;
            font-weight: bold;
            color: #3b82f6;
            margin: 0;
          }
          h2 {
            font-size: 1.5rem;
            color: #9ca3af;
            margin: 1rem 0;
          }
          a {
            display: inline-block;
            margin-top: 2rem;
            padding: 0.75rem 1.5rem;
            background-color: #3b82f6;
            color: white;
            text-decoration: none;
            border-radius: 0.5rem;
            font-weight: 500;
          }
          a:hover {
            background-color: #2563eb;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>404</h1>
          <h2>Page not found</h2>
          <p>The page you're looking for doesn't exist.</p>
          <a href="/">Go to Dashboard</a>
        </div>
      </body>
    </html>
    """
  end

  def render("500.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" class="h-full">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Server Error - Bindocsis</title>
        <style>
          body {
            background-color: #111827;
            color: #f3f4f6;
            font-family: system-ui, -apple-system, sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
          }
          .container {
            text-align: center;
            padding: 2rem;
          }
          h1 {
            font-size: 6rem;
            font-weight: bold;
            color: #ef4444;
            margin: 0;
          }
          h2 {
            font-size: 1.5rem;
            color: #9ca3af;
            margin: 1rem 0;
          }
          a {
            display: inline-block;
            margin-top: 2rem;
            padding: 0.75rem 1.5rem;
            background-color: #3b82f6;
            color: white;
            text-decoration: none;
            border-radius: 0.5rem;
            font-weight: 500;
          }
          a:hover {
            background-color: #2563eb;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>500</h1>
          <h2>Something went wrong</h2>
          <p>An internal server error occurred.</p>
          <a href="/">Go to Dashboard</a>
        </div>
      </body>
    </html>
    """
  end

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
