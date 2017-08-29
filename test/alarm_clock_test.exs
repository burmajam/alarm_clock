defmodule AlarmClockTest do
  use     ExUnit.Case, async: true
  require Logger
  doctest AlarmClock

  Code.require_file("test/receiver.exs")
  Code.require_file("test/alarm_persister.exs")


  #  setup_all do
  #    AlarmPersister.start_link
  #    {:ok, receiver} = Receiver.start_link self()
  #    {:ok, receiver: receiver}
  #  end

  setup do
    AlarmPersister.start_link
    #{:ok, receiver} = Receiver.start_link self()
    #{:ok, receiver: receiver}
    :ok
  end

  test "It accepts alarm in miliseconds" do
    Logger.info "It accepts alarm in miliseconds"
    {:ok, receiver} = Receiver.start_link self()
    :ok = AlarmClock.set_alarm_call receiver, :msg, in: 50
    assert_receive :msg, 6000
    :timer.sleep 10
  end

  test "Timeout for alarm can be set" do
    Logger.info "Timeout for alarm can be set"
    :ok = AlarmClock.set_alarm_call self(), :msg, in: 50, retries: 2, retry_delay: 1_000, timeout: 500
    refute_receive :msg, 4000
    :timer.sleep 10
  end

  test "It retries to deliver message infinitely by default" do
    Logger.info "It retries to deliver message infinitely by default"
    :ok = AlarmClock.set_alarm_call Receiver, :msg, in: 1_000, timeout: 500, retry_delay: 2_000
    refute_receive :msg
    :timer.sleep 5_000
    Receiver.start_link self(), name: Receiver
    assert_receive :msg, 4000
    :timer.sleep 10
  end

  test "Message is delivered even after crash" do
    Logger.info "Message is delivered even after crash"
    {:ok, receiver} = Receiver.start_link self()
    :ok = AlarmClock.set_alarm_call receiver, :msg, in: 1_000
    AlarmClock.Facade
    |> Process.whereis
    |> Process.exit(:kill)
    assert_receive :msg, 6000
    :timer.sleep 10
  end

  test "It deletes timer when it successfully delivered message" do
    Logger.info "It deletes timer when it successfully delivered message"
    {:ok, receiver} = Receiver.start_link self()
    :ok = AlarmClock.set_alarm_call receiver, :msg, in: 50
    assert [_one_alarm_persisted] = AlarmPersister.load_saved_alarms
    assert_receive :msg, 6000
    :timer.sleep 10 #Wait a bit 'till alarm is removed
    assert [] = AlarmPersister.load_saved_alarms
  end

  test "It accepts alarm with specified (localized) time" do
    Logger.info "It accepts alarm with specified (localized) time"
    {:ok, at} = Calendar.DateTime.now!("Europe/Belgrade") 
                |> Calendar.DateTime.add(1)
    {:ok, receiver} = Receiver.start_link self()
    :ok = AlarmClock.set_alarm_call receiver, :msg, at: at
    assert_receive :msg, 6000
    :timer.sleep 10
  end

  test "Localized time message is delivered even after crash" do
    Logger.info "Localized time message is delivered even after crash"
    {:ok, at} = Calendar.DateTime.now!("Europe/Belgrade") 
                |> Calendar.DateTime.add(1)
    {:ok, receiver} = Receiver.start_link self()
    :ok = AlarmClock.set_alarm_call receiver, :msg, at: at
    AlarmClock.Facade
    |> Process.whereis
    |> Process.exit(:kill)
    assert_receive :msg, 6000
    :timer.sleep 10
  end

  test "It can accept new alarm even when other alarm is waiting for target response" do
    Logger.info "It can accept new alarm even when other alarm is waiting for target response"
    {:ok, receiver} = Receiver.start_link self()
    :ok = AlarmClock.set_alarm_call receiver, :long_running_msg, in: 50, timeout: 5_000
    :timer.sleep 100
    :ok = AlarmClock.set_alarm_call receiver, :msg, in: 500
    assert_receive :msg, 6000
    assert_receive :long_running_msg, 6000
    :timer.sleep 10
  end
end
