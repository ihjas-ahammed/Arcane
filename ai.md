Make the following changes:

    - Update level calculation:
        I have some doubts on how level was calculated :D, just confirm that:
            - It should only be based on XP gain of last seven days
            - limit should be slightly exponentially increasing each levels, mention this on README (with eqn. )

    - Fix subroutine progress, fix that it is not getting calcuated and shown in the progressbar when subroutine or tatctical execution has subcheckpoints


    - Habit Control:
        Create a habit control tool in settings
        based on the below:

        Here's a framework grounded in *Atomic Habits* principles for your habit control feature — specifically targeting reduction/elimination of unconscious behaviors like mindless social media use.

    The core idea from the book: **habits are driven by a cue → craving → response → reward loop**. To break bad habits, you attack one of these four stages.So the **4 fundamental requirements** for your feature, mapped to each stage:

    **① Cue removal** — The app should let you hide or rearrange triggers. Think: "scheduled grayscale" during focus hours, or a widget that replaces your SNS shortcut with your routine task.

    **② Friction boost (craving)** — Add a mandatory delay before opening a flagged app — even 10 seconds forces conscious choice instead of autopilot. You could show a prompt: *"Why are you opening this?"*

    **③ Usage cap (response)** — Hard daily limits per app or category. Not just a warning — a lock that requires effort to override (e.g., a cooldown or a reason entry). The harder the override, the better.

    **④ Accountability log (reward)** — Strip the dopamine by making the cost visible. Show "you spent 47 min on Instagram today" with a streak counter for clean days. Seeing a broken streak is itself a deterrent — that's the *unsatisfying* lever.

    The key insight from Atomic Habits: **willpower alone fails — design the environment instead.** Your feature should make the bad behavior *structurally harder*, not just guilt the user after the fact.

    and the flow chart given
    

Make sure there wont be any screensize error, our ideal screen is 720x1520 with 271 dpi
When adding a new ui, create very compact design based on the theme of jurassic world evolution

After applying the changes recreate project_snapshot.txt only for new files and files with changes, each time improve modularity of the program by introducing new component files (only on modified or new files), don't modify system files like pubspec, if we need new packages, or file path changes, removal etc, give the command for bash


Thoroughly check for ui sizing errors before writing the code
Note: as output only give project_snapshot and commands if needed
