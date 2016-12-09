defmodule AlarmClock do
  use     GenServer
  require Logger

  def start_link(opts \\ []),
    do: GenServer.start_link(__MODULE__, :ok, opts)

  def init(:ok), 
    do: {:ok, nil}

  def set_alarm(server, target_pid, msg, in: ms),
    do: GenServer.call server, {:set_alarm, {target_pid, msg, in: ms}}


  def handle_call({:set_alarm, {target_pid, msg, in: ms}}, _from, state) do
    Logger.debug "Setting alarm for #{inspect target_pid} in #{inspect ms} miliseconds with message: #{inspect msg}"
    case :timer.send_after ms, {:alarm, target_pid, msg} do
      {:ok, _} -> {:reply, :ok,   state}
      error    -> {:reply, error, state}
    end
  end

  def handle_info({:alarm, target_pid, msg}, state) do
    send target_pid, msg
    {:noreply, state}
  end
end
