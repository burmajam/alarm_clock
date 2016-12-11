# AlarmClock

:timer.send_after/3 persistable. Allows scheduling message delivery to specified process in miliseconds
or at specified Calendar.DateTime. AlarmClock will make sure that messages are delivered using retry mechanism
and after it's own crash, since all messages can be persisted.

## Installation

  1. Add `alarm_clock` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:alarm_clock, "~> 0.0.1"}]
    end
    ```

  2. Ensure `alarm_clock` is started before your application:

    ```elixir
    def application do
      [applications: [:alarm_clock]]
    end
    ```

