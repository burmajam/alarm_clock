defmodule AlarmClock do
  use     GenServer
  require Logger

  def start_link(opts \\ []),
    do: GenServer.start_link(__MODULE__, opts, opts)

  def init(opts) do 
    opts = %{
      timeout:     Keyword.get(opts, :timeout,      5_000),
      retries:     Keyword.get(opts, :retries,          3),
      retry_delay: Keyword.get(opts, :retry_delay, 10_000)
    }
    {:ok, %{opts: opts}}
  end

  def set_alarm_call(server, target_pid, msg, opts),
    do: GenServer.call server, {:set_alarm, {:call, target_pid, msg, opts}}


  def handle_call({:set_alarm, {call_type, target_pid, msg, opts}}, _from, state) do
    {:ok, ms} = Keyword.fetch opts, :in
    Logger.debug "Setting alarm for #{inspect target_pid} in #{inspect ms} miliseconds with message: #{inspect msg}"
    case :timer.send_after ms, {:alarm, call_type, target_pid, msg, opts, 1} do
      {:ok, _} -> {:reply, :ok,   state}
      error    -> {:reply, error, state}
    end
  end

  def handle_info({:alarm, :call, target_pid, msg, opts, attempt}, state) do
    settings = get_settings opts, state.opts
    case deliver(target_pid, msg, settings, attempt) do
      {:error, {:timeout, _}} -> 
        :timer.send_after settings.retry_delay, {:alarm, :call, target_pid, msg, opts, attempt + 1}
      {:error, {:noproc, _}}  -> 
        :timer.send_after settings.retry_delay, {:alarm, :call, target_pid, msg, opts, attempt + 1}
      _                       -> 
        :ok
    end
    {:noreply, state}
  end
  def handle_info(_, state), 
    do: {:noreply, state}

  defp get_settings(overriden_opts, state_opts) do
    timeout =     Keyword.get overriden_opts, :timeout,     state_opts.timeout
    retries =     Keyword.get overriden_opts, :retries,     state_opts.retries
    retry_delay = Keyword.get overriden_opts, :retry_delay, state_opts.retry_delay
    %{ 
      timeout:     timeout, 
      retries:     retries, 
      retry_delay: retry_delay 
    }
  end

  defp deliver(target_pid, msg, %{retries: retries}=settings, attempt) when attempt <= retries do
    try do
      Logger.debug "Calling #{inspect target_pid} with #{inspect msg}"
      case GenServer.call(target_pid, msg, settings.timeout) do
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
  defp deliver(target_pid, msg, _settings, attempt) do
    Logger.error "Delivery of message #{inspect msg} to #{inspect target_pid} didn't succeed in #{attempt - 1} attempts"
  end
end
