defmodule AlarmClockTest do
  use     ExUnit.Case
  require Logger
  doctest AlarmClock

  setup do
    {:ok, alarm_clock} = AlarmClock.start_link
    {:ok, alarm_clock: alarm_clock}
  end

  test "it's alive", ctx, 
    do: assert Process.alive?(ctx.alarm_clock)

  test "it accepts reminders in miliseconds", ctx do
    Logger.info "it accepts reminders in miliseconds"
    :ok = AlarmClock.set_alarm ctx.alarm_clock, self, :msg, in: 50
    assert_receive :msg
  end
end
