# Reference implementation — do not read this first

`elevator.sv` here is the complete 5-state machine: `IDLE / MOVING / DOOR_OPEN / DWELL /
DOOR_SHUT`, with a 4-bit `pending` call queue and a 4-bit `dwell` timer.

Open it **after** your own version passes all six checks in `make sim`. Then compare. Sensible
differences to argue about:

- This one clears `pending[floor]` in `DOOR_OPEN`, so a button pressed while the doors are
  already open is remembered for a second trip. Clearing in `DOOR_SHUT` instead would swallow
  it. Neither is wrong; they are different elevators.
- It serves the **lowest** pending floor, always. A real elevator keeps going in the direction
  it was already travelling (the SCAN algorithm) so nobody on floor 3 waits forever.
- `DOOR_SHUT` does nothing except go to `IDLE`. It exists so `door_open` falls one tick before
  the machine is free again, which is what a Moore output is for.

To measure it without overwriting your own work:

```bash
mkdir -p /tmp/ref/src && cp solutions/elevator.sv /tmp/ref/src/ && cp config.json /tmp/ref/
cd /tmp/ref && librelane --run-tag ref config.json
```
