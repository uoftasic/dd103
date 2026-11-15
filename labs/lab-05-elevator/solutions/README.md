# Reference implementation

Open this only after your own version passes all eight checks in `make sim`.

`elevator.sv` here is the complete 5-state machine (`IDLE / MOVING / DOOR_OPEN / DWELL /
DOOR_SHUT`), with a 4-bit `pending` call queue and a 4-bit `dwell` timer. Compare it with yours;
these are the differences we think are worth arguing about:

- This version clears `pending[floor]` in `DOOR_OPEN`, so a button pressed while the doors are
  already open is remembered for a second trip. Clearing it in `DOOR_SHUT` instead would
  swallow that press. Neither choice is wrong; they just make different elevators.
- It always serves the lowest pending floor. A real elevator keeps going in the direction it was
  already travelling (the SCAN algorithm), so that nobody on floor 3 waits forever.
- `DOOR_SHUT` does nothing except go to `IDLE`. It's there so that `door_open` falls one tick
  before the machine is free again, which is what a Moore output is for.

To harden the reference design without overwriting your own work, copy it and the config to a
scratch directory and run LibreLane there:

```bash
mkdir -p /tmp/ref/src && cp solutions/elevator.sv /tmp/ref/src/ && cp config.json /tmp/ref/
cd /tmp/ref && librelane --run-tag ref config.json
```
