defmodule AlarmClockTest do
  use     ExUnit.Case, async: true
  require Logger
  doctest AlarmClock

  Code.require_file("test/receiver.exs")
  Code.require_file("test/alarm_persister.exs")


  setup_all do
    AlarmPersister.start_link
    {:ok, alarm_clock} = Application.get_env(:alarm_clock, :settings)
                          |> AlarmClock.start_link
    {:ok, receiver}    = Receiver.start_link self
    {:ok, alarm_clock: alarm_clock, receiver: receiver}
  end

  setup do
    {:ok, receiver}    = Receiver.start_link self
    {:ok, receiver: receiver}
  end

  test "It accepts alarm in miliseconds", ctx do
    Logger.info "It accepts alarm in miliseconds"
    :ok = AlarmClock.set_alarm_call ctx.alarm_clock, ctx.receiver, :msg, in: 50
    assert_receive :msg, 6000
  end

  test "Timeout for alarm can be set" do
    Logger.info "Timeout for alarm can be set"
    {:ok, alarm_clock} = AlarmClock.start_link retries: 2, retry_delay: 1_000, persister: AlarmPersister
    :ok = AlarmClock.set_alarm_call alarm_clock, self, :msg, in: 50, timeout: 500
    refute_receive :msg, 4000
  end

  test "It retries to deliver message" do
    Logger.info "It retries to deliver message"
    {:ok, alarm_clock} = AlarmClock.start_link retries: 2, retry_delay: 1_000, persister: AlarmPersister
    :ok = AlarmClock.set_alarm_call alarm_clock, Receiver, :msg, in: 50, timeout: 500
    refute_receive :msg
    Receiver.start_link self, name: Receiver
    assert_receive :msg, 4000
    :timer.sleep 100
  end

  test "Message is delivered even after crash", ctx do
    Logger.info "Message is delivered even after crash"
    {:ok, alarm_clock} = AlarmClock.start persister: AlarmPersister
    :ok = AlarmClock.set_alarm_call alarm_clock, ctx.receiver, :msg, in: 1_000
    Process.exit alarm_clock, :kill
    :timer.sleep 500
    AlarmClock.start persister: AlarmPersister
    assert_receive :msg, 6000
  end
end
