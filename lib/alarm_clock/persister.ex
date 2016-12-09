defmodule AlarmClock.Persister do
  @type alarm    :: any
  @type alarm_id :: String.t

  @callback save_alarm(alarm :: alarm_id)   :: :ok | any
  @callback delete_alarm(alarm :: alarm_id) :: :ok | {:error, :not_found}
  @callback load_saved_alarms()             :: [{alarm_id, alarm}]
end
