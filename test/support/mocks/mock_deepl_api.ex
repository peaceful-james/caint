defmodule Caint.Mocks.MockDeeplApiImpl do
  @moduledoc false
  alias Req.Response

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
end
