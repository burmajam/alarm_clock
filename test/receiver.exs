defmodule Receiver do
  use GenServer
  require Logger

  def start_link(parent_pid, opts \\ []), 
    do: GenServer.start_link __MODULE__, parent_pid, opts

  def init(parent_pid) do
    Logger.debug "Starting Receiver #{inspect self}"
    {:ok, parent_pid}
  end

  def handle_call({:alarm, _, msg}, _from, parent_pid) do
    send parent_pid, msg
    {:reply, :ok, parent_pid}
  end
end
