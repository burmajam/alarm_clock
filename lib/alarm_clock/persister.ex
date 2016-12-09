defmodule AlarmClock.Persister do
  require Logger

  @type call_type :: :call | :cast
  @type opts      :: [key: atom]
  @type alarm     :: {:alarm, call_type, pid, any, opts, integer}
  @type alarm_id  :: String.t

  @callback save_alarm(alarm :: alarm)         :: {:ok, alarm_id}
  @callback delete_alarm(alarm_id :: alarm_id) :: :ok | {:error, :not_found}
  @callback load_saved_alarms()                :: [{alarm_id, alarm}]

  def calculate_time(in_ms) do
    in_sec = round(in_ms / 1000)
    Logger.debug "Calculating time in #{in_sec} seconds..."
    now = Calendar.DateTime.now_utc
    alarm_time = now |> Calendar.DateTime.add!(in_sec)
    Logger.debug "Alarm time is #{inspect alarm_time}"
    alarm_time
  end

  def get_runnable_alarm({:alarm, call_type, target_pid, msg, opts, attempt}) do
    run_at = Keyword.fetch! opts, :at
    opts = case miliseconds_until(run_at) do
      {:ok, ms} ->
        Keyword.put opts, :in, ms
      {:warn, :passed, ms} -> 
        Keyword.put opts, :in, {:warn, :expired, ms}
    end
    {:alarm, call_type, target_pid, msg, opts, attempt}
  end

  def miliseconds_until(date_time) do
    Logger.debug "Calculating how much miliseconds there are until #{inspect date_time} ..."
    case Calendar.DateTime.diff(Calendar.DateTime.now_utc, date_time) do
      {:ok, seconds, useconds, :before} ->
        ms = abs (seconds * 1000) + round(useconds / 1000)
        Logger.debug "There are #{inspect ms} miliseconds left"
        {:ok, ms}
      {:ok, seconds, useconds, :after} ->
        ms = abs (seconds * 1000) + round(useconds / 1000)
        Logger.debug "It was #{inspect ms} miliseconds before!"
        {:warn, :passed, ms}
      error ->
        Logger.error "There's error in calculating time diff: #{inspect error}"
        {:error, error}
    end
  end
end
