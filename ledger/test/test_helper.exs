{:ok, _} = Application.ensure_all_started(:ex_machina)
Faker.start()

Mox.defmock(Ledger.Messaging.PublisherMock, for: Ledger.Messaging.Publisher)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Ledger.Repo, :manual)
