## Cron Handler

This process is responsible for sending messages to the AO/IO contract on a cron basis to ensure state is properly ticked throughout Epochs.

### Loading in AOS

Example loading in AOS:

```bash
aos devnet-tick-state --cron 1-hour
```

The `Target` object can be manually modified by running.

```bash
aos> Target="" -- insert process ID to tick
```
