defmodule Caint.Deepl.Api do
  @moduledoc false

  alias Caint.Deepl.RealApiImpl

  @type result :: {:ok, Req.Response.t()} | {:error, Exception.t()}

  @callback batch_size() :: non_neg_integer()
  @callback usage() :: result()
  @callback translate(map()) :: result()

  @spec batch_size() :: non_neg_integer()
  def batch_size, do: impl().batch_size()
  @spec usage() :: result()
  def usage, do: impl().usage()
  @spec translate(map()) :: result()
  def translate(data), do: impl().translate(data)

  defp impl, do: Application.get_env(:caint, :deepl_api_impl) || RealApiImpl
end
