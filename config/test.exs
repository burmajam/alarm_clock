use Mix.Config

config :alarm_clock, :settings,
  name:        MyReminder,
  timeout:     5_000,
  retries:     3,
  retry_delay: 10_000

config :logger, :console,
  level:    :debug,
  format:   "$time [$level] $metadata$message\n",
  metadata: [:pid]
