defmodule Accounts.Release do
  @moduledoc """
  Database tasks for the release, which has no Mix. `bin/setup` runs `setup/0`, the
  release's `mix setup`:

      bin/accounts eval Accounts.Release.setup
  """
  alias EventStore.Tasks.{Create, Init}

  @app :accounts

  @doc """
  Creates and initializes the event store, creates and migrates the read models' database,
  then runs the seeds. Every step is idempotent, so it runs on each start.
  """
  def setup do
    load_app()
    setup_event_stores()
    migrate()
    seed()
  end

  @doc """
  Creates the event store's database and schema, then its tables (`mix event_store.setup`).
  """
  def setup_event_stores do
    load_app()
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:ssl)

    for event_store <- event_stores() do
      config = event_store.config()
      :ok = Create.exec(config)
      :ok = Init.exec(config)
    end
  end

  @doc """
  Creates the read models' database, then runs its migrations (`mix ecto.create`,
  `mix ecto.migrate`).
  """
  def migrate do
    load_app()

    for repo <- repos() do
      :ok = create_storage(repo)
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Runs `priv/repo/seeds.exs` with the application started, as `mix run` does.
  """
  # The path is fixed: the seeds shipped inside the release.
  # sobelow_skip ["RCE.CodeModule"]
  def seed do
    {:ok, _} = Application.ensure_all_started(@app)
    Code.eval_file(Application.app_dir(@app, "priv/repo/seeds.exs"))

    :ok = Application.stop(@app)
  end

  defp create_storage(repo) do
    case repo.__adapter__().storage_up(repo.config()) do
      :ok -> :ok
      {:error, :already_up} -> :ok
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp event_stores do
    Application.fetch_env!(@app, :event_stores)
  end

  defp load_app do
    Application.load(@app)
  end
end
