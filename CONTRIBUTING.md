# Contributing

The most useful thing right now is a report from another machine with an MT7925 (any laptop with the Filogic 360 card). Open an issue with the laptop model, the macOS build, the OpenCore version, the MtkBt version, and `ioreg -rc MtkBt -l | grep MtkBt` (counters and state only, never keys or addresses). If Bluetooth comes up but behaves oddly afterwards, that is probably `bluetoothd` and the firmware, not the loader; see LegionBtFix.

Pull requests: keep them small and say how you tested them. I read and test every PR before merging. AI-assisted PRs are fine as long as you can explain the change, which is the same bar I hold my own code to.

Anything ported from Linux `btmtk.c` names the function it came from in a comment. Keep it that way.
