use Mix.Config

config :alarm_clock, :settings,
  persister:   AlarmPersister,
  timeout:     5_000,
  retry_delay: 10_000

config :logger, :console,
  level:    :debug,
  format:   "$time [$level] $metadata$message\n",
  metadata: [:pid]
