Make the following changes:

    - From now on Use Pro Models, to generate daily breifing, startup note, person info 
    - Update person info,
        - Make it compact, as given in the html below, update prompt in the same way
     
Person Info

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Character Profile: Ayisha</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Rajdhani:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --spidey-red: #d02b3e;
            --spidey-cyan: #00f0ff;
            --spidey-cyan-dim: #006b72;
            --bg-dark: #08111a;
            --bg-panel: #0b1623;
            --text-white: #e6e6e6;
            --text-grey: #8a9ba8;
            --border-glow: 0 0 5px rgba(0, 240, 255, 0.4);
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            background-color: #000;
            color: var(--text-white);
            font-family: 'Rajdhani', sans-serif;
            height: 100vh;
            /* Use dvh for mobile browsers to handle address bars correctly */
            height: 100dvh; 
            display: flex;
            justify-content: center;
            align-items: center;
            overflow: hidden;
            background-image: radial-gradient(circle at center, #132030 0%, #000000 100%);
        }

        /* Main Container */
        .ui-container {
            width: 100%;
            max-width: 600px;
            height: 85vh;
            background-color: var(--bg-panel);
            border: 1px solid #1f2f40;
            display: flex;
            flex-direction: column;
            position: relative;
            box-shadow: 0 0 30px rgba(0,0,0,0.9);
        }

        /* --- Header Section --- */
        .header {
            display: flex;
            height: 70px; /* Slightly shorter for cleaner look without portrait */
            border-bottom: 1px solid #1f2f40;
            flex-shrink: 0;
        }

        .header-red {
            background-color: var(--spidey-red);
            width: 15px; /* Minimal red strip */
            height: 100%;
            position: relative;
        }

        .header-stats {
            flex-grow: 1;
            background: linear-gradient(90deg, #162433 0%, var(--bg-panel) 100%);
            display: flex;
            align-items: center;
            padding: 0 20px;
            gap: 15px;
        }

        .level-box {
            text-align: center;
            min-width: 40px;
        }
        .level-label {
            font-size: 10px;
            color: var(--spidey-cyan);
            letter-spacing: 1px;
            text-transform: uppercase;
        }
        .level-num {
            font-size: 28px;
            font-weight: 700;
            color: var(--spidey-cyan);
            line-height: 1;
            text-shadow: var(--border-glow);
        }

        .xp-bar-container {
            flex-grow: 1;
            display: flex;
            flex-direction: column;
            justify-content: center;
        }
        
        .xp-bar-bg {
            height: 6px;
            width: 100%;
            background-color: #1f2f40;
            margin-bottom: 5px;
            position: relative;
        }
        
        .xp-bar-fill {
            position: absolute;
            left: 0;
            top: 0;
            height: 100%;
            width: 75%;
            background-color: var(--spidey-cyan);
            box-shadow: var(--border-glow);
        }

        .xp-text {
            font-size: 11px;
            color: var(--text-white);
            letter-spacing: 0.5px;
        }

        /* --- Name Band --- */
        /* Adjusted margin since portrait is gone */
        .name-band {
            margin: 20px 0 10px 0;
            padding: 12px 0;
            text-align: center;
            position: relative;
            border-top: 1px solid var(--spidey-cyan-dim);
            border-bottom: 1px solid var(--spidey-cyan-dim);
            background: rgba(0, 240, 255, 0.05);
            flex-shrink: 0;
        }

        .name-band::before, .name-band::after {
            content: '';
            position: absolute;
            width: 100%;
            height: 1px;
            background: linear-gradient(90deg, transparent 0%, var(--spidey-cyan) 50%, transparent 100%);
            left: 0;
            opacity: 0.5;
        }
        .name-band::before { top: -1px; }
        .name-band::after { bottom: -1px; }

        .char-name {
            font-size: 24px;
            font-weight: 700;
            color: var(--spidey-cyan);
            text-transform: uppercase;
            letter-spacing: 2px;
            text-shadow: 0 0 10px rgba(0, 240, 255, 0.4);
        }

        /* --- Info Content --- */
        .content-area {
            flex-grow: 1; /* Fills remaining space */
            padding: 10px 30px 30px 30px;
            overflow-y: auto;
            /* Smooth scrolling for mobile */
            -webkit-overflow-scrolling: touch; 
            scrollbar-width: thin;
            scrollbar-color: var(--spidey-cyan-dim) var(--bg-panel);
        }

        /* Custom scrollbar */
        .content-area::-webkit-scrollbar {
            width: 4px;
        }
        .content-area::-webkit-scrollbar-track {
            background: #0b1623;
        }
        .content-area::-webkit-scrollbar-thumb {
            background-color: var(--spidey-cyan-dim);
            border-radius: 2px;
        }

        .section-header {
            font-size: 16px;
            color: var(--spidey-cyan);
            margin-bottom: 15px;
            margin-top: 10px;
            display: flex;
            align-items: center;
            text-transform: uppercase;
            font-weight: 700;
            letter-spacing: 1px;
        }

        .section-header::after {
            content: '';
            flex-grow: 1;
            height: 1px;
            background: linear-gradient(90deg, var(--spidey-cyan-dim), transparent);
            margin-left: 10px;
        }

        .data-grid {
            display: grid;
            grid-template-columns: 1fr;
            gap: 8px;
            margin-bottom: 20px;
        }

        .data-row {
            font-size: 16px;
            display: flex;
            justify-content: space-between;
            border-bottom: 1px solid rgba(255,255,255,0.05);
            padding-bottom: 4px;
        }

        .label {
            color: var(--text-grey);
            font-weight: 500;
            font-size: 14px;
            text-transform: uppercase;
        }

        .value {
            color: var(--text-white);
            text-align: right;
            font-weight: 600;
        }

        .long-text {
            color: var(--text-white);
            font-size: 15px;
            line-height: 1.6;
            margin-bottom: 20px;
            opacity: 0.9;
            text-align: justify;
        }

        .highlight {
            color: var(--spidey-cyan);
            font-weight: 700;
        }

        .sub-header {
            color: var(--text-grey);
            font-size: 12px;
            text-transform: uppercase;
            margin-top: 25px;
            margin-bottom: 10px;
            letter-spacing: 1px;
            font-weight: 700;
            border-left: 3px solid var(--spidey-red);
            padding-left: 10px;
        }

        ul {
            list-style-type: none;
            padding-left: 5px;
        }
        
        li {
            margin-bottom: 12px;
            font-size: 15px;
            color: #ccc;
            line-height: 1.4;
            position: relative;
            padding-left: 15px;
        }

        li::before {
            content: '>';
            position: absolute;
            left: 0;
            color: var(--spidey-cyan-dim);
            font-weight: bold;
        }

        /* --- Mobile Optimization --- */
        @media (max-width: 600px) {
            body {
                background: var(--bg-panel); /* Remove radial gradient on mobile for performance/clean look */
            }

            .ui-container {
                height: 100dvh; /* Full screen height */
                max-width: 100%;
                border: none;
                box-shadow: none;
            }

            .header {
                height: 60px;
            }

            .level-num {
                font-size: 24px;
            }

            .char-name {
                font-size: 20px;
            }

            .content-area {
                padding: 10px 20px 40px 20px; /* Extra bottom padding for touch scrolling */
            }
            
            .long-text, li {
                font-size: 14px;
            }
        }
    </style>
</head>
<body>

    <div class="ui-container">
        <!-- HEADER -->
        <div class="header">
            <div class="header-red"></div>
            <div class="header-stats">
                <div class="level-box">
                    <div class="level-label">LVL</div>
                    <div class="level-num">2</div>
                </div>
                <div class="xp-bar-container">
                    <div class="xp-bar-bg">
                        <div class="xp-bar-fill"></div>
                    </div>
                    <div class="xp-text">NEET PREP / 2650 XP</div>
                </div>
            </div>
        </div>

        <!-- MAIN TITLE -->
        <div class="name-band">
            <div class="char-name">Ayisha / The Realist</div>
        </div>

        <!-- INFO BODY -->
        <div class="content-area">
            <div class="section-header">Core Stats</div>
            
            <div class="data-grid">
                <div class="data-row">
                    <span class="label">Relation</span>
                    <span class="value">Emotional Anchor</span>
                </div>
                <div class="data-row">
                    <span class="label">Status</span>
                    <span class="value">Calibration Phase</span>
                </div>
                <div class="data-row">
                    <span class="label">Updated</span>
                    <span class="value">Mar 05, 2026</span>
                </div>
                <div class="data-row">
                    <span class="label">Role</span>
                    <span class="value">Student (NEET)</span>
                </div>
            </div>

            <div class="section-header">Dossier</div>

            <div class="sub-header">PSYCHOLOGICAL PROFILE</div>
            <div class="long-text">
                Pragmatic, supportive, and emotionally intelligent. Serves as a grounding force. Highly goal-oriented (NEET preparation). Unlike 'Fathima', Ayisha is characterized by reliability and belief in user's potential. Possesses strong self-worth; becomes distant if efforts are overlooked.
            </div>

            <div class="sub-header">INTERACTION HISTORY</div>
            <ul>
                <li><span class="highlight">The Reliable Second:</span> Consistent study partner. Managed Duolingo account during NSS camp.</li>
                <li><span class="highlight">The Anchor (2025-26):</span> Primary confidante regarding Fathima. Provided "therapist-like" perspective.</li>
                <li><span class="highlight">The Realization (Feb 26):</span> User breakthrough; prioritized Ayisha over unreciprocated connections.</li>
            </ul>

            <div class="sub-header">COMMUNICATION TIPS</div>
            <ul>
                <li><span class="highlight">Limit 'Fathima-Talk':</span> Focus on shared projects and *her* goals. Avoid romantic drama dumping.</li>
                <li><span class="highlight">Respect Boundaries:</span> Keep daytime interactions brief (Focus Mode). Do not disturb study time.</li>
                <li><span class="highlight">Value Directness:</span> Take her advice ("stop chasing shadows") seriously.</li>
            </ul>
        </div>
    </div>

</body>
</html>
```


Make sure there wont be any screensize error, our ideal screen is 720x1520 with 271 dpi

After applying the changes recreate project_snapshot.txt only for new files and files with changes, each time improve modularity of the program by introducing new component files (only on modified or new files), don't modify system files like pubspec, if we need new packages, or file path changes, removal etc, give the command for bash


Thoroughly check for ui sizing errors before writing the code
Note: as output only give project_snapshot and commands if needed
