defmodule AccountsWeb.ErrorJSON do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on JSON requests.

  See config/config.exs.
  """

  # If you want to customize a particular status code,
  # you may add your own clauses, such as:
  #
  # def render("500.json", _assigns) do
  #   %{errors: %{detail: "Internal Server Error"}}
  # end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  # An error a controller returns on purpose, with the code openapi.yaml documents (README, D12).
  def render("error.json", %{code: code, detail: detail, fields: fields}) do
    %{errors: %{code: code, detail: detail, fields: fields}}
  end

  def render("error.json", %{code: code, detail: detail}) do
    %{errors: %{code: code, detail: detail}}
  end

  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
