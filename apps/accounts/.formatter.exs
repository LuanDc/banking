[
  import_deps: [:ecto, :ecto_sql, :phoenix],
  # commanded_ecto_projections exports no formatter config for its `project` macro.
  locals_without_parens: [project: 2, project: 3, validates: 2],
  subdirectories: ["priv/*/migrations"],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}", "priv/*/seeds.exs"]
]
