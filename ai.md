Make the following changes:

Update notification:
    First of all, make usure if schdule notification service works correct way
    Then make following changes:
        1. Bring schedules to UI:
            When I set a reminder I wouldnt know if it was set because there was no ui for seeing scheduled reminders so add a screen in which I can view and edit all scdhuled reminders
            i. Add scheduled planner:
                a. Update planner to specfify reminder time for each task
                b. Use notification service to get reminders
        2. Update ongoing task notification:
            i. Add button to check next checkpoint (if nested check the lowest one in the hierarchy)
            ii. Add a toast to see which one is checked
            iii. For next two sections, change the button label to UNDO CHECK

        3. Process Notify:
            i. Show progress bars if possible (the default progress we have in missions screen)

Make sure there wont be any screensize error, our ideal screen is 720x1520 with 271 dpi
When adding a new ui, create very compact design based on the theme of jurassic world evolution

After applying the changes recreate project_snapshot.txt only for new files and files with changes, each time improve modularity of the program by introducing new component files (only on modified or new files), don't modify system files like pubspec, if we need new packages, or file path changes, removal etc, give the command for bash


Thoroughly check for ui sizing errors before writing the code
Note: as output only give project_snapshot and commands if needed
