defmodule Caint.Deepl.RealApiImpl do
  @moduledoc """
  Talks to the DeepL HTTP API with `Req`.

  DeepL throttles rapid-fire requests (HTTP 429) and occasionally has hiccups (5xx, dropped
  connections). Those are retried quietly with exponential backoff and jitter, honouring any
  `Retry-After` header. Other errors (bad key, quota exceeded, ...) are returned straight away.

  Tunable via application config (defaults shown):

      config :caint,
        deepl_max_retries: 8,
        deepl_retry_base_delay_ms: 1_000,
        deepl_retry_max_delay_ms: 30_000,
        # Extra options merged into every `Req` request, e.g. `plug: {Req.Test, ...}` in tests
        deepl_req_options: []
  """
  @behaviour Caint.Deepl.Api

  alias Caint.Deepl.Api

  require Logger

  @batch_size 50
  @retryable_statuses [408, 429, 500, 502, 503, 504, 529]

  @impl Api
  def batch_size, do: @batch_size

  @impl Api
  def usage do
    Req.get(new_request(), url: "usage")
  end

  @impl Api
  def translate(data) do
    Req.post(new_request(), url: "translate", json: data)
  end

  defp new_request do
    [
      base_url: Application.get_env(:caint, :deepl_api_url),
      auth: "DeepL-Auth-Key #{Application.get_env(:caint, :deepl_api_key)}",
      retry: &retry/2,
      max_retries: Application.get_env(:caint, :deepl_max_retries, 8),
      retry_log_level: false
    ]
    |> Req.new()
    |> Req.merge(Application.get_env(:caint, :deepl_req_options, []))
  end

  @doc false
  # Req retry callback: `{:delay, ms}` to retry, `false` to give up.
  @spec retry(Req.Request.t(), Req.Response.t() | Exception.t()) :: false | {:delay, non_neg_integer()}
  def retry(request, response_or_exception) do
    if retryable?(response_or_exception) do
      retry_count = Req.Request.get_private(request, :req_retry_count, 0)
      delay = retry_after(response_or_exception) || backoff(retry_count)
      Logger.info("DeepL: #{describe(response_or_exception)}, retrying in #{delay}ms (retry #{retry_count + 1})")
      {:delay, delay}
    else
      false
    end
  end

  defp retryable?(%Req.Response{status: status}), do: status in @retryable_statuses
  defp retryable?(%Req.TransportError{}), do: true
  defp retryable?(%Req.HTTPError{}), do: true
  defp retryable?(_), do: false

  # Never retry sooner than DeepL asks, but add up to 25% jitter: batches that were throttled
  # together are told the same Retry-After, and would otherwise all retry at the same instant.
  defp retry_after(%Req.Response{} = response) do
    case Req.Response.get_retry_after(response) do
      delay when is_integer(delay) and delay >= 0 -> min(delay + :rand.uniform(div(delay, 4) + 1) - 1, max_delay())
      _ -> nil
    end
  end

  defp retry_after(_exception), do: nil

  # Exponential backoff with "equal jitter": half the delay is fixed, half is random.
  # Jitter stops concurrent batches that were throttled together from retrying in lockstep.
  defp backoff(retry_count) do
    base = Application.get_env(:caint, :deepl_retry_base_delay_ms, 1_000)
    capped = min(base * Integer.pow(2, retry_count), max_delay())
    half = div(capped, 2)
    half + :rand.uniform(half + 1) - 1
  end

  defp max_delay, do: Application.get_env(:caint, :deepl_retry_max_delay_ms, 30_000)

  defp describe(%Req.Response{status: status}), do: "got HTTP #{status}"
  defp describe(exception), do: "got #{Exception.message(exception)}"
end
