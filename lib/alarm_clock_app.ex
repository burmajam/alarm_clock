defmodule AlarmClock.App do
  use     Application
  require Logger

  @request_sup AlarmClock.RequestSupervisor

  def start(_, _) do
    import Supervisor.Spec, warn: false

    default_settings = %{
                          timeout:     5_000,
                          retries:     :infinit,
                          retry_delay: 10_000,
                          persister:   AlarmClock.DetsPersister
                        }
    client_settings  = Application.get_env(:alarm_clock, :settings) |> Enum.into(%{})
    settings = Map.merge(default_settings, client_settings)

    children = [
      supervisor(Task.Supervisor, [[name: @request_sup]]),
      worker(    AlarmClock,      [settings, @request_sup]),
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    res = Supervisor.start_link(children, opts)
    Logger.info "Started AlarmClock with default settings: #{inspect settings}"
    res
  end
end
