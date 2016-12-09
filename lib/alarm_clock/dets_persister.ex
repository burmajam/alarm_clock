defmodule AlarmClock.DetsPersister do
  @behaviour AlarmClock.Persister

  def load_saved_alarms do
    [:a]
  end

  def save_alarm(_alarm) do
    {:ok, 1}
  end

  def delete_alarm(_alarm_id) do
    :ok
  end
end
