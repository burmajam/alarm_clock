defmodule AlarmClock.Mixfile do
  use Mix.Project

  def project do
    [app: :alarm_clock,
     version: "0.0.1",
     elixir: "~> 1.3",
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
      {:calendar, "~> 0.16.1"}
    ]
  end
end
