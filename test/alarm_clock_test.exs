defmodule AlarmClockTest do
  use     ExUnit.Case
  require Logger
  doctest AlarmClock

  setup do
    {:ok, alarm_clock} = AlarmClock.start_link
    {:ok, alarm_clock: alarm_clock}
  end

  test "it's alive", ctx do
    assert Process.alive?(ctx.alarm_clock)
  end
end
