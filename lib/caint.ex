defmodule Caint do
  @moduledoc """
  Translate PO files
  """

  @env Application.compile_env(:caint, :env)
  @spec env() :: :dev | :test | :prod
  def env, do: Application.get_env(:caint, :env) || @env
end
