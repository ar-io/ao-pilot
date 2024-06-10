Target = Target or "GaQrvEMKBpkjofgnBi_B3IgIDmY_XYelVLB6GcRGrHc"
Handlers.add(
  "CronTick", -- handler name
  Handlers.utils.hasMatchingTag("Action", "Cron"), -- handler pattern to identify cron message
  function () -- handler task to execute on cron message
    ao.send({Target=Target, Action= "Tick"})
  end
)
