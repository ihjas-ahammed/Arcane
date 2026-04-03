Make the following changes:

    - Auto load from cloud:
        When I open the app, if the storage data seems new (reset), try checking if the user have data on database and load it (only if it seems reset) this is to fix app from resetting on web in each run

    - Remove postpone button from day planner  (since halt does the same action, we dont need that)


    - Upgrade to project:
        Add an option to upgrade task to project:
            - the previous time spend will be the projects initial time data
            - sub routines will turn to substeps
            - Do this by adding a button below Finish and Delete

Make sure there wont be any screensize error, our ideal screen is 720x1520 with 271 dpi
When adding a new ui, create very compact design based on the theme of jurassic world evolution

After applying the changes recreate project_snapshot.txt only for new files and files with changes, each time improve modularity of the program by introducing new component files (only on modified or new files), don't modify system files like pubspec, if we need new packages, or file path changes, removal etc, give the command for bash


Thoroughly check for ui sizing errors before writing the code
Note: as output only give project_snapshot and commands if needed
