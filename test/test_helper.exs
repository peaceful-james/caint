alias Caint.Deepl.MockApiImpl

Mox.defmock(MockApiImpl, for: Caint.Deepl.Api)
Application.put_env(:caint, :deepl_api_impl, MockApiImpl)
ExUnit.start()
