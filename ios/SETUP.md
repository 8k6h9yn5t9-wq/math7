# Math 7 for iPad: setup

This folder is the native iPad app. It uses the same problems as the web app (`../problems.js`), adds
Apple Pencil handwriting answers, and can lock Roblox until the daily goal is met.

There are two versions, picked from the scheme menu at the top of Xcode:

| Scheme | Needs | What you get |
|---|---|---|
| **Math7** | Free Apple ID | Everything except the Roblox lock. The install lasts 7 days, then you press Run again. |
| **Math7 with Roblox Lock** | Apple Developer Program ($99/year) | Everything, plus the Roblox lock. The install lasts a year. |

Progress is kept when you reinstall or switch versions.

---

## Part 1: first install (free Apple ID)

### 1. Set up Xcode (one time, about 10 minutes after the download)
1. Open **Xcode** from Applications. Agree to the license and enter your Mac password if asked.
2. When it asks which platforms to install, make sure **iOS** is checked and click **Download & Install**.
   If it doesn't ask, go to **Xcode › Settings › Components** and click **Get** next to iOS.
3. Go to **Xcode › Settings › Accounts**, click **+**, choose **Apple Account**, and sign in with **your** Apple ID
   (not your son's). You'll see "Your Name (Personal Team)".

### 2. Open the project
1. In Finder, open the `math7` folder, then `ios`, and double-click **Math7.xcodeproj**.
2. If Xcode asks whether to trust the project, click **Trust and Open**.

### 3. Pick your team
1. In the left sidebar, click the blue **Math7** icon at the very top.
2. Under **Targets**, click **Math7**, then the **Signing & Capabilities** tab.
3. Make sure **Automatically manage signing** is checked and set **Team** to "Your Name (Personal Team)".
4. If you see "Failed to register bundle identifier", open `Config/Settings.xcconfig` (left sidebar, Config folder)
   and change the letters at the end of `BUNDLE_ID_PREFIX` to anything else, like `com.math7practice.james42`.

### 4. Get the iPad ready
1. Unlock your son's iPad and connect it to the Mac with a USB-C cable. Tap **Trust** on the iPad and enter its passcode.
2. On the iPad, open **Settings › Privacy & Security**, scroll to the bottom, tap **Developer Mode**, turn it on,
   and let the iPad restart. Confirm **Turn On** after it restarts.
   (Developer Mode only shows up after the iPad has been connected to Xcode once. If you don't see it, do step 5 first,
   then come back.)

### 5. Run it
1. At the top of the Xcode window, make sure the scheme says **Math7**, and click the device name next to it.
   Pick your son's iPad from the list.
2. Click the **▶ Run** button (or press ⌘R). The first build takes a minute or two.
3. The first time, the iPad says the developer isn't trusted. On the iPad go to
   **Settings › General › VPN & Device Management**, tap your Apple ID under Developer App, and tap **Trust**.
4. Press **▶ Run** again. Math 7 opens on the iPad and stays on the home screen.

### Every 7 days
Free installs stop opening after 7 days. Connect the iPad, open the project and press **▶ Run**. Nothing is lost.

---

## Part 2: turn on the Roblox lock (after joining the Apple Developer Program)

1. Join at https://developer.apple.com/programs/ with your Apple ID. Approval usually takes a day or two.
2. In Xcode, change the scheme at the top to **Math7 with Roblox Lock**.
3. In **Signing & Capabilities**, set **Team** to your paid team (it no longer says Personal Team) for each of
   these three targets: **Math7Lock**, **Math7Monitor** and **Math7Shield**. Xcode turns on Family Controls and
   App Groups for you.
4. Connect the iPad and press **▶ Run**. This replaces the free version and keeps his progress.
5. On the iPad, open Math 7, tap **Parent**, enter your PIN, and scroll to **Game lock**:
   1. Tap **This is my child's iPad (Family Sharing)** and approve with **your** Apple Account.
   2. Tap **Choose apps** and pick **Roblox** (under Games). Also add **roblox.com** under Websites so it can't be played in Safari.
   3. Turn on **Lock these until the daily goal is met**.
   4. Choose what happens when the goal is met: unlock for the rest of the day, or a set number of minutes
      for each goal he completes (he taps **Unlock** when he's ready to play).
   5. Optional: pick a **bedtime** to lock games again every evening, and turn on **Don't allow deleting apps**.

### How it works for him
- Roblox shows a "Math first!" screen with how many problems are left.
- Only correct answers count (first or second try). "Show me how" doesn't count.
- When he reaches the goal, Roblox unlocks by itself. It locks again at midnight (and at bedtime, if set).
- Because his iPad uses a child account in your Family Sharing, he can't turn this off in Settings without you.

---

## Answering with Apple Pencil
- On each problem, choose **Write** (Pencil) or **Keys** (number pad). The app remembers the choice.
- Write the answer in the box. About a second after he stops, the app shows what it read. Then he taps **Check**.
- Negatives: write a minus sign in front, or tap **±**. Decimals: write the point clearly.
- Fractions: write the top number, a line under it, then the bottom number. `3/4` on one line works too.
  Mixed numbers like 2 ¾ work when the fraction part is stacked (they're turned into 11/4 automatically).
- If it can't read it, he can tap **Erase** and write bigger, or switch to **Keys**.
- The right side of the screen is scratch paper.
- With "Only Draw with Apple Pencil" on (iPad Settings › Apple Pencil), his palm and fingers won't leave marks.

## For developers
- `Math7/` app code (SwiftUI). `Math7Monitor/` re-locks games at midnight, at bedtime and when play time ends.
  `Math7Shield/` is the "Math first!" screen. `Shared/` is code used by the app and the monitor.
- Problems come from `../problems.js`, run with JavaScriptCore, so the web and iPad apps stay in sync.
- To rebuild the Xcode project after adding files: `gem install xcodeproj && ruby tools/generate_project.rb`.
