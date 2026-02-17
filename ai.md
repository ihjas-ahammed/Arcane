Make the following changes:

    * Fix ai schedule prediction:
        The refernce for last sevendays, should be session logs instead of reflection logs:
            - add a new time ['session'] for getLast7DaysData in app provider, this session should go through all tasks that is completed within last 7 days and also all incomplete takss and access the session logs of each task and then chose the ones from last seven days and return it to the prompt

Make sure there wont be any screensize error, our ideal screen is 720x1520 with 271 dpi

After applying the changes recreate project_snapshot.txt only for new files and files with changes, each time improve modularity of the program by introducing new component files (only on modified or new files), don't modify system files like pubspec, if we need new packages, or file path changes, removal etc, give the command for bash


Thoroughly check for ui sizing errors before writing the code
Note: as output only give project_snapshot and commands if needed
