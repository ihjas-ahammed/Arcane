Make the following changes:

    - Update task card:
        - Give the advanced circular progress bar instaed of radio button:
            - Its maximum is the avarage time usage of current submission for last seven days, calculated based on session log
    
    - Use insights from the ui of screenshot and also the theme: valorant protcol

    - Fix data issues:
        - Auto recalibrate time logs everytime after cloud sync
        - Save the daily breifing and system startup report to the database at /daily/briefing and /daily/report with day 
        - Also make it possible user can chose to save weekly briefing

    - Update prompt: update system startup prompt in a way it talks more like a human friend who you can talk in the morning but still keep the primary as to give advice about the following

Make sure there wont be any screensize error, our ideal screen is 720x1520 with 271 dpi

After applying the changes recreate project_snapshot.txt only for new files and files with changes, each time improve modularity of the program by introducing new component files (only on modified or new files), don't modify system files like pubspec, if we need new packages, or file path changes, removal etc, give the command for bash


Thoroughly check for ui sizing errors before writing the code
Note: as output only give project_snapshot and commands if needed
