Mox.defmock(Caint.Deepl.MockApiImpl, for: Caint.Deepl.Api)
Application.put_env(:caint, :deepl_api_impl, Caint.Deepl.MockApiImpl)
ExUnit.start()
