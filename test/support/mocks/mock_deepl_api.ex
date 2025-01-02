defmodule Caint.Mocks.MockDeeplApiImpl do
  @moduledoc false
  @behaviour Caint.Deepl.Api

  alias Caint.Deepl.Api
  alias Req.Response

  @impl Api
  def batch_size, do: 50

  @impl Api
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

  @impl Api
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
