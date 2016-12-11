defmodule AlarmClock.Mixfile do
  use Mix.Project

  def project do
    [app: :alarm_clock,
     version: "0.0.1",
     elixir: "~> 1.3",
     package: package,
     description: description,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [
      applications: [:logger, :calendar]
    ]
  end

  defp deps do
    [
      {:calendar, "~> 0.14"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp package do
    %{
       maintainers: ["Milan Burmaja"],
       links: %{ "GitHub" => "https://github.com/burmajam/alarm_clock"},
       licenses: ["MIT"],
       files: ~w(lib mix.exs README*) }
  end

  defp description do
    """
    :timer.send_after/3 persistable. Allows scheduling message delivery to specified process in miliseconds
    or at specified Calendar.DateTime. AlarmClock will make sure that messages are delivered using retry mechanism
    and after it's own crash, since all messages can be persisted.
    """
  end
end
