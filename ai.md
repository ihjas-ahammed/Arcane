Make the following changes:

    - Update AI Prompts:
        Add the following element to Startup Note, Briefing and Insight:
            Make it work in an optimistic way, like yk something bad happened and let AI help in finding something good from it
            ALso make sure all this reports get access to previous data, as for both berifing it should have access to entire reflections, as for insight give access to last week reflections
            but make sure the output focus on the present
        
        Update briefing:
            Allow it to mention people names, both main and weekly
    Update startup report:
            Replace the system status by using another progress bar:
                Relative increase and decrease in the xp of each well-being elements (since it was calculated only for last 7 days data)

    Update wellbeing info alert:
            Along with 7-DAY MOMENTUM, below it add a graph of current well being card (decrease and increase in last 7 days) (similar to our work-sleep curved graph)

    Remove firestore recovery backup (because it didnt work because of quota issue anyway)
        
    


Make sure there wont be any screensize error, our ideal screen is 720x1520 with 271 dpi
When adding a new ui, create very compact design based on the theme of jurassic world evolution

After applying the changes recreate project_snapshot.txt only for new files and files with changes, each time improve modularity of the program by introducing new component files (only on modified or new files), don't modify system files like pubspec, if we need new packages, or file path changes, removal etc, give the command for bash


Thoroughly check for ui sizing errors before writing the code
Note: as output only give project_snapshot and commands if needed
