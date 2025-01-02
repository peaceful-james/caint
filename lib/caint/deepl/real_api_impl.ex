defmodule Caint.Deepl.RealApiImpl do
  @moduledoc """
  --header 'Authorization: DeepL-Auth-Key [yourAuthKey]' \
  --header 'Content-Type: application/json' \
  """
  @behaviour Caint.Deepl.Api

  alias Caint.Deepl.Api

  @impl Api
  @batch_size 50
  def batch_size, do: @batch_size

  @impl Api
  def usage do
    api_url()
    |> Path.join("usage")
    |> Req.get(auth: auth_header())
  end

  @impl Api
  def translate(data) do
    api_url()
    |> Path.join("translate")
    |> Req.post(auth: auth_header(), json: data)
  end

  defp api_url, do: Application.get_env(:caint, :deepl_api_url)
  defp api_key, do: Application.get_env(:caint, :deepl_api_key)
  defp auth_header, do: "DeepL-Auth-Key #{api_key()}"
end
