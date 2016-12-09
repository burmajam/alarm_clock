defmodule AlarmClock do
  use     GenServer
  require Logger

  def start_link(opts \\ []),
    do: GenServer.start_link(__MODULE__, :ok, opts)

  def init(:ok), 
    do: {:ok, nil}

  def set_alarm_call(server, target_pid, msg, opts),
    do: GenServer.call server, {:set_alarm, {:call, target_pid, msg, opts}}


  def handle_call({:set_alarm, {call_type, target_pid, msg, opts}}, _from, state) do
    {:ok, ms} = Keyword.fetch opts, :in
    Logger.debug "Setting alarm for #{inspect target_pid} in #{inspect ms} miliseconds with message: #{inspect msg}"
    case :timer.send_after ms, {:alarm, call_type, target_pid, msg, opts} do
      {:ok, _} -> {:reply, :ok,   state}
      error    -> {:reply, error, state}
    end
  end

  def handle_info({:alarm, :call, target_pid, msg, opts}, state) do
    timeout = Keyword.get opts, :timeout, 5_000
    response = try do
      Logger.debug "Calling #{inspect target_pid} with #{inspect msg}"
      case GenServer.call(target_pid, msg, timeout) do
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
    {:noreply, state}
  end
  def handle_info(_, state), 
    do: {:noreply, state}
end
