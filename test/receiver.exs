defmodule Receiver do
  use GenServer
  require Logger

  def start_link(parent_pid, opts \\ []), 
    do: GenServer.start_link __MODULE__, parent_pid, opts

  def init(parent_pid) do
    Logger.debug "Starting Receiver #{inspect self()}"
    {:ok, parent_pid}
  end

  def handle_call({:alarm, _, :long_running_msg}, _from, parent_pid) do
    ms = 3_000
    Logger.debug "It takes #{inspect ms} ms for receiver to respond to alarm"
    :timer.sleep ms
    send parent_pid, :long_running_msg
    Logger.debug "Long running alarm message executed"
    {:reply, :ok, parent_pid}
  end

  def handle_call({:alarm, _, msg}, _from, parent_pid) do
    send parent_pid, msg
    Logger.debug "Message executed"
    {:reply, :ok, parent_pid}
  end
end
