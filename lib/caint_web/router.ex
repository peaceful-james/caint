defmodule CaintWeb.Router do
  use CaintWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CaintWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CaintWeb do
    pipe_through :browser
    live "/", CaintLive, :index
    live "/:locale", CaintLive, :locale
  end
end
