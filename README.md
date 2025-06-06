
<img width="521" src="https://github.com/user-attachments/assets/16dba94a-073a-4e1d-b70c-2695c1c23ee1" />

> MenuBarCountdown on macOS 15.5 (Menu bar customized with [Ice](https://github.com/jordanbaird/Ice))

# MenuBarCountdown
Display a countdown in the macOS menu bar

## Q&A

### What is This default endpoint?
`https://diamondgotcat.net/appledate.txt`

I originally created this software as a reminder to make sure I wasn't late for Apple announcements.

After repeated improvements, it has become an easy-to-use menu bar countdown item for anyone.

After all, this endpoint is the date and time endpoint for Apple Event (include WWDC), which is manually updated.

### Is an endpoint required?
The endpoint is required, but it does not have to be hosted by you.

I provides its own endpoint (`https://diamondgotcat.net/echo/?content=2025-06-10T17:00:00Z`) so that anyone can use it, even if they are not a developer.

## Note
If you are building it yourself, please note the following:
- To hide it from the Dock, add "LSUIElement" to Info.plist as Yes (Boolean, set to "1" in the file).
- This application requires outgoing connections to the Internet. Please allow "Outgoing Connections (Client)" in the App Sandbox feature.
