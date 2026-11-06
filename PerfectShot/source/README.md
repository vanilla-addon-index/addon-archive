# PerfectShot
Vanialla World of Warcraft Screenshot Addon

# Function
Hides UI during the screenshot.

# How to use?
Go to the key binding dialog and bind three new keys:

* 'Screenshot with names' - Hide UI and show names on screenshot.
* 'Screenshot without names - Hide UI and hide names on screenshot.
* 'Screenshot without names / target name' - Hide UI and hide names and target name on screenshot.

# Chat command
To do a series of screenshots automatically:

* <code>/ps &lt;number screenshots&gt; &lt;delay in seconds&gt; [&lt;show names: 1&gt;]</code>

Takes X screenshots, after each screenshot the addon waits Y seconds. To show names append a '1' otherwise names are not shown (default) on screenshot.

You can cancel a series anytime via '/ps cancel'. Also if you program an new series it overrides any active series.

Examples
* <code>/ps 10 3</code> - Makes 10 screenshot, 3 seconds pause between each shot. Names off.
* <code>/ps 10 3 1</code> - Same, but names on.
* <code>/ps 10000 300</code> - Makes every 5 minutes one shot as long as you play :) 

