{:ok, _} = Application.ensure_all_started(:ex_machina)
Faker.start()

Mox.defmock(Accounts.Messaging.PublisherMock, for: Accounts.Messaging.Publisher)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Accounts.Repo, :manual)
