defmodule Caint.Mocks.MockDeeplApiImpl do
  @moduledoc false
  alias Caint.Deepl.Api
  alias Req.Response

  @spec batch_size() :: non_neg_integer()
  def batch_size, do: 50

  @spec usage() :: Api.result()
  def usage do
    {:ok,
     %Response{
       status: 200,
       headers: %{
         "content-type" => ["application/json"]
       },
       body: %{"character_count" => 250_000, "character_limit" => 500_000}
     }}
  end

  @spec translate(map()) :: Api.result()
  def translate(_data) do
    {:ok,
     %Response{
       status: 200,
       headers: %{
         "content-type" => ["application/json"]
       },
       body: %{
         "translations" => [
           %{"detected_source_language" => "EN", "text" => "0 التصنيفات"},
           %{"detected_source_language" => "EN", "text" => "1 فئة 1"},
           %{"detected_source_language" => "EN", "text" => "2 فئات"},
           %{"detected_source_language" => "EN", "text" => "3 فئات"},
           %{"detected_source_language" => "EN", "text" => "11 فئة"},
           %{"detected_source_language" => "EN", "text" => "100 فئة"}
         ]
       }
     }}
  end
end
