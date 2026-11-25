defmodule Caint.Deepl.RealApiImplTest do
  # Not async: tweaks retry settings in the application env.
  use ExUnit.Case, async: false

  alias Caint.Deepl.RealApiImpl

  setup do
    previous = Application.get_env(:caint, :deepl_max_retries)
    Application.put_env(:caint, :deepl_max_retries, 3)
    on_exit(fn -> Application.put_env(:caint, :deepl_max_retries, previous) end)
  end

  defp stub_responses(responses) do
    {:ok, agent} = Agent.start_link(fn -> responses end)
    test_pid = self()

    Req.Test.stub(RealApiImpl, fn conn ->
      send(test_pid, {:request, conn.method, conn.request_path})
      {status, body} = Agent.get_and_update(agent, fn [next | rest] -> {next, rest} end)

      case body do
        :transport_error -> Req.Test.transport_error(conn, :closed)
        body -> conn |> Plug.Conn.put_status(status) |> Req.Test.json(body)
      end
    end)
  end

  test "translate retries throttling (429) and server errors (5xx) and then succeeds" do
    stub_responses([
      {429, %{"message" => "Too many requests"}},
      {503, %{"message" => "Unavailable"}},
      {200, %{"translations" => [%{"text" => "Bonjour"}]}}
    ])

    assert {:ok, %Req.Response{status: 200, body: %{"translations" => [%{"text" => "Bonjour"}]}}} =
             RealApiImpl.translate(%{text: ["Hello"], target_lang: "FR"})

    for _ <- 1..3, do: assert_received({:request, "POST", "/v2/translate"})
  end

  test "translate retries transport errors" do
    stub_responses([{nil, :transport_error}, {200, %{"translations" => []}}])
    assert {:ok, %Req.Response{status: 200}} = RealApiImpl.translate(%{text: []})
  end

  test "gives up after max retries and returns the last response" do
    stub_responses(List.duplicate({429, %{"message" => "Too many requests"}}, 4))
    assert {:ok, %Req.Response{status: 429}} = RealApiImpl.translate(%{text: ["Hello"]})
    for _ <- 1..4, do: assert_received({:request, "POST", "/v2/translate"})
    refute_received {:request, _, _}
  end

  test "does not retry non-transient errors such as quota exceeded" do
    stub_responses([{456, %{"message" => "Quota exceeded"}}])
    assert {:ok, %Req.Response{status: 456}} = RealApiImpl.translate(%{text: ["Hello"]})
    assert_received {:request, "POST", "/v2/translate"}
    refute_received {:request, _, _}
  end

  test "usage" do
    stub_responses([{200, %{"character_count" => 1, "character_limit" => 2}}])
    assert {:ok, %Req.Response{body: %{"character_count" => 1}}} = RealApiImpl.usage()
    assert_received {:request, "GET", "/v2/usage"}
  end

  test "target_languages asks the v3 languages endpoint" do
    test_pid = self()

    Req.Test.stub(RealApiImpl, fn conn ->
      send(test_pid, {:request, conn.method, conn.request_path, conn.query_string})
      Req.Test.json(conn, [%{"lang" => "de", "usable_as_target" => true}])
    end)

    assert {:ok, %Req.Response{status: 200, body: [%{"lang" => "de"}]}} = RealApiImpl.target_languages()
    assert_received {:request, "GET", "/v3/languages", "resource=translate_text"}
  end

  describe "retry/2" do
    test "honours Retry-After with a little jitter, capped at the max delay" do
      request = Req.new()

      for _ <- 1..20 do
        assert {:delay, delay} =
                 RealApiImpl.retry(request, Req.Response.new(status: 429, headers: %{"retry-after" => ["2"]}))

        assert delay in 2000..2500
      end

      assert {:delay, 30_000} =
               RealApiImpl.retry(request, Req.Response.new(status: 429, headers: %{"retry-after" => ["9999"]}))
    end

    test "backs off exponentially with jitter" do
      previous = Application.get_env(:caint, :deepl_retry_base_delay_ms)
      Application.put_env(:caint, :deepl_retry_base_delay_ms, 1000)
      on_exit(fn -> Application.put_env(:caint, :deepl_retry_base_delay_ms, previous) end)

      delay_at = fn retry_count ->
        request = Req.Request.put_private(Req.new(), :req_retry_count, retry_count)
        {:delay, delay} = RealApiImpl.retry(request, Req.Response.new(status: 503))
        delay
      end

      for _ <- 1..20 do
        assert delay_at.(0) in 500..1000
        assert delay_at.(3) in 4000..8000
        assert delay_at.(10) in 15_000..30_000
      end
    end

    test "does not retry client errors" do
      for status <- [400, 403, 404, 456] do
        refute RealApiImpl.retry(Req.new(), Req.Response.new(status: status))
      end
    end
  end
end
