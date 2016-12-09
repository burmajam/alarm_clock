defmodule AlarmClock do
  use GenServer

  def start_link(opts \\ []),
    do: GenServer.start_link(__MODULE__, :ok, opts)

  def init(:ok) do
    {:ok, nil}
  end
end
