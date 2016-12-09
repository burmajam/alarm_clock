defmodule AlarmPersister do
  @behaviour AlarmClock.Persister
  use GenServer

  def start_link,
    do: Agent.start_link(fn -> %{} end, name: __MODULE__)

  def load_saved_alarms do
    Agent.get __MODULE__, &Enum.map(&1, fn {alarm_id, alarm} -> 
      {alarm_id, AlarmClock.Persister.get_runnable_alarm(alarm)} 
    end)
  end

  def save_alarm({:alarm, call_type, target_pid, msg, opts, attempt}=alarm) do
    alarm_id = :crypto.hash(:sha256, inspect(alarm))
    alarm = if Keyword.get(opts, :at) do
      alarm
    else
      in_ms = Keyword.fetch! opts, :in
      opts  = opts ++ [at: AlarmClock.Persister.calculate_time(in_ms)]
      {:alarm, call_type, target_pid, msg, opts, attempt}
    end
    :ok = Agent.update(__MODULE__, &Map.put(&1, alarm_id, alarm))
    {:ok, alarm_id}
  end

  def delete_alarm(alarm_id) do
    if Agent.get_and_update(__MODULE__, &Map.pop(&1, alarm_id)),
      do: :ok,
      else: {:error, :key_not_found, alarm_id}
  end
end
