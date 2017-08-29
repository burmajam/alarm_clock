defmodule AlarmClock do
  use     GenServer
  require Logger

  @facade_name AlarmClock.Facade

  def start_link(settings, request_sup),
    do: GenServer.start_link(__MODULE__, {settings, request_sup}, name: @facade_name)

  def set_alarm_call(target_pid, msg, opts),
    do: GenServer.call @facade_name, {:set_alarm, {:call, target_pid, msg, opts}}

  def load_saved_alarms,
    do: GenServer.cast @facade_name, :load_saved_alarms

  def init({settings, request_sup}) do
    Logger.info "AlarmClock.Facade started"
    {:ok, %{settings: settings, request_sup: request_sup}}
  end

  def handle_call(msg, from, state) do
    Task.Supervisor.start_child(state.request_sup, fn -> 
      result = execute msg, state.settings
      GenServer.reply from, result
    end)
    {:noreply, state}
  end

  def handle_cast(:load_saved_alarms, state) do
    load_saved_alarms state.settings.persister
    {:noreply, state}
  end

  def handle_info({{:alarm, type, target_pid, msg, opts, attempt}, alarm_id, on_time?}, state) do
    Task.Supervisor.start_child(state.request_sup, fn -> 
      execute {{:alarm, type, target_pid, msg, opts, attempt}, alarm_id, on_time?}, state.settings
    end)
    {:noreply, state}
  end
  def handle_info(_, state), 
    do: {:noreply, state}

  defp execute({:set_alarm, {call_type, target_pid, msg, opts}}, settings) do
    at = Keyword.get opts, :at
    response = if at do
      case Calendar.DateTime.diff(Calendar.DateTime.now_utc, at) do
        {:ok, seconds, useconds, :before} ->
          ms = abs (seconds * 1000) + round(useconds / 1000)
          Logger.debug "There are #{inspect ms} miliseconds left"
          {:ok, ms}
        error ->
          Logger.error "There's error in calculating time diff: #{inspect error}"
          {:error, error}
      end
    else
      Keyword.fetch opts, :in
    end
    case response do
      {:ok, ms} ->
        Logger.debug "Setting alarm for #{inspect target_pid} in #{inspect ms} miliseconds with message: #{inspect msg}"
        message = {:alarm, call_type, target_pid, msg, opts, 1}
        {:ok, alarm_id} = settings.persister.save_alarm message
        case :timer.send_after ms, @facade_name, {message, alarm_id, :on_time} do
          {:ok, _} -> :ok
          error    -> error
        end
      error -> error
    end
  end

  defp execute({{:alarm, :call, target_pid, msg, opts, attempt}, alarm_id, on_time?}, settings) do
    settings = get_settings opts, settings
    case deliver(target_pid, msg, settings, attempt, on_time?) do
      {:error, {:timeout, _}} -> 
        :timer.send_after settings.retry_delay, @facade_name, {{:alarm, :call, target_pid, msg, opts, attempt + 1}, alarm_id, {:expired, :unknown}}
        Logger.warn "Target timeouts with response! Alarm scheduled for redelivery"
      {:error, {:noproc, _}}  -> 
        :timer.send_after settings.retry_delay, @facade_name, {{:alarm, :call, target_pid, msg, opts, attempt + 1}, alarm_id, {:expired, :unknown}}
        Logger.warn "No target process! Alarm scheduled for redelivery"
      _other                  -> 
        settings.persister.delete_alarm alarm_id
        :ok
    end
  end

  defp get_settings(overridden_settings, state_settings) do
    client_settings  = overridden_settings |> Enum.into(%{})
    Map.merge state_settings, client_settings
  end

  defp deliver(target_pid, msg, %{retries: retries}=settings, attempt, on_time?) when attempt <= retries do
    try do
      Logger.debug "Calling #{inspect target_pid} with #{inspect msg}"
      case GenServer.call(target_pid, {:alarm, on_time?, msg}, settings.timeout) do
        :ok   -> 
          Logger.debug "Everything looks ok"
        other -> 
          Logger.warn  "Delivery not successful: #{inspect other}"
          {:error, other}
      end
    catch
      :exit, reason ->
        Logger.warn "Calling server failed with: #{inspect reason}"
        {:error, reason}
    end
  end
  defp deliver(target_pid, msg, _settings, attempt, _) do
    Logger.error "Delivery of message #{inspect msg} to #{inspect target_pid} didn't succeed in #{attempt - 1} attempts"
  end

  defp load_saved_alarms(persister) do
    ensure_implements persister, AlarmClock.Persister
    persister.load_saved_alarms
      |> Enum.each(&recover_alarm/1)
  end

  defp recover_alarm({alarm_id, {_,_,_,_,opts,_}=alarm}) do
    Logger.debug "Recovering alarm #{inspect alarm}"
    case Keyword.fetch!(opts, :in) do
      {:warn, :expired, ms_ago} -> 
        Logger.warn "Message expired #{inspect ms_ago} mseconds ago! Delivering it now!"
        send self(), {alarm, alarm_id, {:expired, ms_ago}}
      ms -> 
        :timer.send_after ms, @facade_name, {alarm, alarm_id, :on_time}
    end
  end

  defp ensure_implements(module, behaviour) do
    all = Keyword.take(module.__info__(:attributes), [:behaviour])
    unless [behaviour] in Keyword.values(all) do
      Mix.raise "Expected #{inspect module} to implement #{inspect behaviour} " <>
                "in order to make alarms durable"
    end
  end
end
