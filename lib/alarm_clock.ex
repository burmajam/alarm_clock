defmodule AlarmClock do
  use     GenServer
  require Logger

  def start(opts \\ []),
    do: GenServer.start(__MODULE__, opts, opts)

  def start_link(opts \\ []),
    do: GenServer.start_link(__MODULE__, opts, opts)

  def set_alarm_call(server, target_pid, msg, opts),
    do: GenServer.call server, {:set_alarm, {:call, target_pid, msg, opts}}



  def init(opts) do 
    settings = %{
      timeout:     Keyword.get(opts, :timeout,                         5_000),
      retries:     Keyword.get(opts, :retries,                      :infinit),
      retry_delay: Keyword.get(opts, :retry_delay,                    10_000),
      persister:   Keyword.get(opts, :persister,    AlarmClock.DetsPersister)
    }
    Logger.info "Started AlarmClock [name: #{inspect opts[:name]}] with default settings: #{inspect settings}"
    load_saved_alarms settings.persister
    {:ok, %{settings: settings}}
  end

  def handle_call({:set_alarm, {call_type, target_pid, msg, opts}}, _from, state) do
    at = Keyword.get opts, :at
    {:ok, ms} = if at do
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
    Logger.debug "Setting alarm for #{inspect target_pid} in #{inspect ms} miliseconds with message: #{inspect msg}"
    message = {:alarm, call_type, target_pid, msg, opts, 1}
    {:ok, alarm_id} = state.settings.persister.save_alarm message
    case :timer.send_after ms, {message, alarm_id, :on_time} do
      {:ok, _} -> {:reply, :ok,   state}
      error    -> {:reply, error, state}
    end
  end

  def handle_info({{:alarm, :call, target_pid, msg, opts, attempt}, alarm_id, on_time?}, state) do
    settings = get_settings opts, state.settings
    case deliver(target_pid, msg, settings, attempt, on_time?) do
      {:error, {:timeout, _}} -> 
        :timer.send_after settings.retry_delay, {{:alarm, :call, target_pid, msg, opts, attempt + 1}, alarm_id, {:expired, :unknown}}
        Logger.warn "Alarm scheduled for redelivery"
      {:error, {:noproc, _}}  -> 
        :timer.send_after settings.retry_delay, {{:alarm, :call, target_pid, msg, opts, attempt + 1}, alarm_id, {:expired, :unknown}}
        Logger.warn "Alarm scheduled for redelivery"
      _other                  -> 
        state.settings.persister.delete_alarm alarm_id
        :ok
    end
    {:noreply, state}
  end
  def handle_info(_, state), 
    do: {:noreply, state}

  defp get_settings(overridden_opts, state_opts) do
    timeout =     Keyword.get overridden_opts, :timeout,     state_opts.timeout
    retries =     Keyword.get overridden_opts, :retries,     state_opts.retries
    retry_delay = Keyword.get overridden_opts, :retry_delay, state_opts.retry_delay
    %{ 
      timeout:     timeout, 
      retries:     retries, 
      retry_delay: retry_delay 
    }
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
        send self, {alarm, alarm_id, {:expired, ms_ago}}
      ms -> 
        :timer.send_after ms, {alarm, alarm_id, :on_time}
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
