Make the following changes:

    - Update submisison, checkpoint screen based on the html:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PRIMUS // HEAT EDITION</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Chakra+Petch:ital,wght@0,400;0,600;0,700;1,700&display=swap" rel="stylesheet">
    
    <style>
        :root {
            /* NFS HEAT PALETTE */
            --neon-red: #ff0055;
            --neon-cyan: #00f0ff;
            --neon-purple: #bd00ff;
            --bg-dark: #050508;
            --bg-panel: rgba(20, 20, 30, 0.85);
            --text-white: #ffffff;
            --text-dim: #889;
            --grid-color: rgba(255, 255, 255, 0.1);
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            background-color: var(--bg-dark);
            /* The Dotted Grid Background from Image 1 */
            background-image: radial-gradient(var(--grid-color) 1px, transparent 1px);
            background-size: 6px 6px;
            font-family: 'Chakra Petch', sans-serif;
            color: var(--text-white);
            display: flex;
            justify-content: center;
            min-height: 100vh;
            overflow-x: hidden;
        }

        /* Mobile Container */
        .app-container {
            width: 100%;
            max-width: 420px;
            background: linear-gradient(180deg, rgba(10,10,15,0.9) 0%, rgba(20,20,25,0.95) 100%);
            display: flex;
            flex-direction: column;
            position: relative;
            border-left: 1px solid rgba(255,255,255,0.1);
            border-right: 1px solid rgba(255,255,255,0.1);
            box-shadow: 0 0 50px rgba(0, 240, 255, 0.1);
            padding-bottom: 20px;
        }

        /* --- HEADER --- */
        header {
            padding: 20px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 1px solid rgba(255,255,255,0.1);
        }

        .back-btn {
            font-size: 1.2rem;
            color: var(--text-dim);
            cursor: pointer;
        }

        .title-block {
            text-align: left;
            flex-grow: 1;
            padding-left: 20px;
        }

        .sub-label {
            font-size: 0.7rem;
            color: var(--neon-cyan);
            letter-spacing: 2px;
            font-weight: 700;
            text-transform: uppercase;
            text-shadow: 0 0 5px var(--neon-cyan);
        }

        h1 {
            font-size: 2rem;
            font-style: italic;
            font-weight: 900;
            text-transform: uppercase;
            line-height: 0.9;
            letter-spacing: 1px;
        }

        /* --- TIMER SECTION --- */
        .dashboard-stats {
            padding: 20px;
            position: relative;
        }

        .stat-label {
            font-size: 0.7rem;
            color: var(--neon-red);
            font-weight: 700;
            text-transform: uppercase;
            margin-bottom: 5px;
        }

        .timer-display-row {
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .big-timer {
            font-size: 3.5rem;
            font-weight: 700;
            font-variant-numeric: tabular-nums;
            letter-spacing: -2px;
            text-shadow: 2px 2px 0px rgba(255,0,85,0.2);
        }

        .play-btn {
            width: 50px;
            height: 50px;
            background: var(--neon-red);
            border: none;
            color: white;
            font-size: 1.2rem;
            display: flex;
            align-items: center;
            justify-content: center;
            clip-path: polygon(10% 0, 100% 0, 100% 90%, 90% 100%, 0 100%, 0 10%);
            cursor: pointer;
            box-shadow: 0 0 15px var(--neon-red);
            transition: transform 0.1s;
        }
        .play-btn:active { transform: scale(0.95); }

        /* The Hazard Stripe Bar */
        .hazard-bar {
            height: 12px;
            width: 100%;
            margin-top: 10px;
            background: repeating-linear-gradient(
                -45deg,
                #000,
                #000 10px,
                var(--neon-cyan) 10px,
                var(--neon-cyan) 20px
            );
            border: 1px solid white;
            position: relative;
        }
        
        .hazard-text {
            position: absolute;
            top: -20px;
            right: 0;
            font-size: 0.6rem;
            background: white;
            color: black;
            padding: 2px 4px;
            font-weight: bold;
            transform: skewX(-10deg);
        }

        /* --- LIST SECTION --- */
        .section-header {
            padding: 10px 20px;
            font-size: 0.8rem;
            color: var(--text-dim);
            text-transform: uppercase;
            letter-spacing: 1px;
            border-bottom: 1px solid rgba(255,255,255,0.05);
        }

        .task-list {
            padding: 10px 20px;
        }

        .task-card {
            background: rgba(255, 255, 255, 0.03);
            border-left: 4px solid var(--text-dim);
            padding: 15px;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            transition: all 0.3s ease;
            cursor: pointer;
            /* Angled corners similar to NFS UI */
            clip-path: polygon(0 0, 100% 0, 100% 85%, 95% 100%, 0 100%); 
        }

        .task-card:hover {
            background: rgba(255, 255, 255, 0.08);
            border-left-color: var(--neon-cyan);
        }

        .task-card.active {
            border-left-color: var(--neon-cyan);
            box-shadow: -10px 0 20px -10px rgba(0, 240, 255, 0.3);
        }

        .task-card.completed {
            opacity: 0.5;
            text-decoration: line-through;
            border-left-color: #333;
        }

        .task-content {
            display: flex;
            align-items: center;
            gap: 15px;
        }

        .status-icon {
            width: 12px;
            height: 12px;
            transform: rotate(45deg);
            background: var(--text-dim);
            box-shadow: 0 0 5px var(--text-dim);
        }

        .task-card.active .status-icon {
            background: var(--neon-cyan);
            box-shadow: 0 0 8px var(--neon-cyan);
        }

        .task-text {
            font-weight: 600;
            letter-spacing: 0.5px;
            text-transform: uppercase;
        }

        /* --- INPUTS --- */
        .input-group {
            padding: 0 20px 20px 20px;
        }
        
        .add-step-row {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
        }

        input[type="text"], textarea {
            width: 100%;
            background: rgba(0,0,0,0.3);
            border: 1px solid #333;
            color: white;
            padding: 12px;
            font-family: 'Chakra Petch', sans-serif;
            text-transform: uppercase;
            outline: none;
            transition: 0.3s;
        }

        input[type="text"]:focus, textarea:focus {
            border-color: var(--neon-cyan);
            background: rgba(0, 240, 255, 0.05);
        }

        .ghost-label {
            border-left: 2px solid var(--neon-cyan);
            padding-left: 10px;
            margin-bottom: 5px;
            margin-top: 15px;
            font-size: 0.7rem;
            color: var(--text-dim);
            text-transform: uppercase;
        }

        textarea {
            resize: none;
            height: 80px;
            border-top: 2px solid rgba(255,255,255,0.1);
        }

        .timeline-box {
            height: 100px;
            border: 1px solid #333;
            background: rgba(0,0,0,0.5);
            position: relative;
        }
        
        .timeline-line {
            position: absolute;
            top: 50%;
            left: 10px;
            right: 10px;
            height: 1px;
            background: #333;
        }

        /* --- FOOTER BUTTONS --- */
        .footer-actions {
            display: flex;
            gap: 10px;
            padding: 20px;
            margin-top: auto;
        }

        .action-btn {
            flex: 1;
            padding: 15px;
            font-family: 'Chakra Petch', sans-serif;
            font-weight: 800;
            text-transform: uppercase;
            font-size: 1.1rem;
            border: none;
            cursor: pointer;
            position: relative;
            /* Heavy slant for NFS look */
            transform: skewX(-10deg); 
            transition: 0.2s;
        }

        /* Un-skew text inside buttons */
        .action-btn span {
            display: block;
            transform: skewX(10deg); 
        }

        .btn-complete {
            background: rgba(0, 240, 255, 0.1);
            border: 2px solid var(--neon-cyan);
            color: var(--neon-cyan);
        }

        .btn-complete:hover {
            background: var(--neon-cyan);
            color: black;
            box-shadow: 0 0 20px var(--neon-cyan);
        }

        .btn-terminate {
            background: rgba(255, 0, 85, 0.1);
            border: 2px solid var(--neon-red);
            color: var(--neon-red);
        }

        .btn-terminate:hover {
            background: var(--neon-red);
            color: white;
            box-shadow: 0 0 20px var(--neon-red);
        }

        /* Glitch Decor on active item */
        .glitch-deco {
            position: absolute;
            right: 10px;
            top: 10px;
            color: rgba(255,255,255,0.2);
            font-size: 2rem;
            font-weight: 900;
            opacity: 0.1;
            pointer-events: none;
        }

    </style>
</head>
<body>

    <div class="app-container">
        <!-- Header -->
        <header>
            <div class="back-btn">&#8592;</div>
            <div class="title-block">
                <div class="sub-label">PASSION</div>
                <h1>PRIMUS</h1>
            </div>
            <div class="back-btn">&#9998;</div> <!-- Pencil Icon -->
        </header>

        <!-- Timer Area -->
        <section class="dashboard-stats">
            <div class="stat-label">TIME LOGGED TODAY</div>
            <div class="stat-label" style="color:white; opacity:0.7">CURRENT SESSION</div>
            
            <div class="timer-display-row">
                <div class="big-timer" id="timer">08:32</div>
                <button class="play-btn" id="toggleBtn">
                    <span style="font-size: 1.5rem;">&#10074;&#10074;</span>
                </button>
            </div>

            <!-- Stylized Hazard Bar -->
            <div class="hazard-bar">
                <div class="hazard-text">OVERFLOW 5.0 PX</div>
            </div>
        </section>

        <!-- List Section -->
        <div class="section-header">Tactical Execution (How)</div>
        <section class="task-list">
            
            <!-- Active Item -->
            <div class="task-card active" onclick="toggleTask(this)">
                <div class="task-content">
                    <div class="status-icon"></div>
                    <span class="task-text">Update Task Card</span>
                </div>
                <div style="color:var(--text-dim)">&#8942;</div>
                <div class="glitch-deco">A+</div>
            </div>

            <!-- Normal Item -->
            <div class="task-card" onclick="toggleTask(this)">
                <div class="task-content">
                    <div class="status-icon"></div>
                    <span class="task-text">Update Task Info</span>
                </div>
                <div style="color:var(--text-dim)">&#8942;</div>
            </div>

             <!-- Normal Item -->
             <div class="task-card" onclick="toggleTask(this)">
                <div class="task-content">
                    <div class="status-icon"></div>
                    <span class="task-text">Fix Why Edit</span>
                </div>
                <div style="color:var(--text-dim)">&#8942;</div>
            </div>

             <!-- Completed Item -->
             <div class="task-card completed" onclick="toggleTask(this)">
                <div class="task-content">
                    <div class="status-icon"></div>
                    <span class="task-text">Fix Data</span>
                </div>
                <div style="color:var(--text-dim)">&#8942;</div>
            </div>

        </section>

        <!-- Inputs Section -->
        <div class="input-group">
            <div class="add-step-row">
                <div style="display:flex; align-items:center; border:1px solid #333; padding:10px; color:#555;">&#9745;</div>
                <input type="text" placeholder="ADD STEP...">
                <button style="background:var(--neon-cyan); border:none; width:40px; color:black; font-weight:bold;">+</button>
            </div>

            <div class="ghost-label">Strategic Intent (Why)</div>
            <textarea placeholder="Reason for action..."></textarea>

            <div class="ghost-label">Expected Outcome (What)</div>
            <textarea placeholder="Result or Reward..."></textarea>
        </div>

        <div class="section-header">Session Timeline</div>
        <div style="padding: 0 20px 20px;">
            <div class="timeline-box">
                <div class="timeline-line"></div>
                <div style="position:absolute; bottom:5px; left:10px; font-size:0.6rem; color:#555;">11:00</div>
            </div>
        </div>

        <!-- Footer Buttons -->
        <footer class="footer-actions">
            <button class="action-btn btn-complete">
                <span>&#128190; Complete</span>
            </button>
            <button class="action-btn btn-terminate">
                <span>&#128465; Terminate</span>
            </button>
        </footer>

    </div>

    <script>
        // Simple functionality for prototype feel

        // 1. Timer logic
        let isRunning = true;
        let seconds = 32;
        let minutes = 8;
        const timerEl = document.getElementById('timer');
        const toggleBtn = document.getElementById('toggleBtn');

        setInterval(() => {
            if(isRunning) {
                seconds++;
                if(seconds > 59) {
                    seconds = 0;
                    minutes++;
                }
                // Format with leading zeros
                const m = minutes < 10 ? '0' + minutes : minutes;
                const s = seconds < 10 ? '0' + seconds : seconds;
                timerEl.innerText = `${m}:${s}`;
            }
        }, 1000);

        toggleBtn.addEventListener('click', () => {
            isRunning = !isRunning;
            if(isRunning) {
                toggleBtn.innerHTML = '<span style="font-size: 1.5rem;">&#10074;&#10074;</span>'; // Pause Icon
                toggleBtn.style.background = 'var(--neon-red)';
            } else {
                toggleBtn.innerHTML = '<span style="font-size: 1.5rem;">&#9658;</span>'; // Play Icon
                toggleBtn.style.background = '#444';
            }
        });

        // 2. Task toggling styling
        function toggleTask(element) {
            // Simply toggle active state for visual demo
            // In a real app, this would handle completion logic
            
            // If it's already completed, do nothing or undo
            if(element.classList.contains('completed')) return;

            // Remove active from others
            document.querySelectorAll('.task-card').forEach(el => {
                if(el !== element) el.classList.remove('active');
            });

            element.classList.toggle('active');
        }

    </script>
</body>
</html>
```

Make sure to give the exact design and fonts

    - Update task card based on this html, in a similar way:

```html

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Active Contracts // HEX-HEAT</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@500;700;900&family=Beaufort+for+LOL:wght@700&display=swap" rel="stylesheet">
    
    <style>
        :root {
            /* LOL HEXTECH PALETTE */
            --hex-gold: #C8AA6E;
            --hex-gold-dim: #785a28;
            --hex-cyan: #0AC8B9;
            --hex-cyan-glow: #00FFEA;
            --hex-dark: #010A13;
            --hex-panel: #1E2328;
            --hex-border: #463714;
            
            /* NFS ACCENTS */
            --nfs-bg: #050508;
            
            --card-height: 100px;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            background-color: var(--nfs-bg);
            /* Grid texture from previous step */
            background-image: 
                radial-gradient(rgba(200, 170, 110, 0.1) 1px, transparent 1px),
                linear-gradient(to bottom, rgba(0,0,0,0.8), rgba(0,10,20,0.9));
            background-size: 20px 20px, 100% 100%;
            font-family: 'Chakra Petch', sans-serif;
            color: white;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }

        .container {
            width: 100%;
            max-width: 480px;
            padding: 20px;
        }

        /* --- HEADER --- */
        .section-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding-left: 10px;
            border-left: 3px solid var(--hex-cyan);
        }

        .header-title {
            font-size: 0.9rem;
            letter-spacing: 2px;
            font-weight: 700;
            color: var(--hex-gold);
            text-transform: uppercase;
            text-shadow: 0 0 10px rgba(200, 170, 110, 0.3);
        }

        .add-btn {
            color: var(--hex-cyan);
            font-size: 1.5rem;
            background: none;
            border: none;
            cursor: pointer;
            text-shadow: 0 0 10px var(--hex-cyan);
        }

        /* --- CARD STYLES --- */
        .contract-card {
            position: relative;
            height: var(--card-height);
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            padding: 0 20px;
            transition: all 0.3s ease;
            cursor: pointer;
            
            /* The Background & Border Logic */
            background: linear-gradient(90deg, rgba(30,35,40,0.9) 0%, rgba(10,10,15,0.8) 100%);
            
            /* Complex shape: Chamfered corners like LoL UI */
            clip-path: polygon(
                15px 0, 100% 0, 
                100% calc(100% - 15px), calc(100% - 15px) 100%, 
                0 100%, 0 15px
            );
        }

        /* To create the border effect with clip-path, we use a pseudo element or box-shadow trick. 
           Here we use an inner shadow to simulate the border since clip-path cuts off real borders */
        .contract-card::before {
            content: '';
            position: absolute;
            inset: 0;
            box-shadow: inset 0 0 0 1px var(--hex-border);
            pointer-events: none;
            z-index: 1;
        }

        /* --- INACTIVE CARD --- */
        .contract-card.inactive .icon-container {
            border-color: var(--hex-gold-dim);
        }
        
        .contract-card.inactive .card-title {
            color: #aaa;
        }

        /* --- ACTIVE CARD (THE PRIMUS) --- */
        .contract-card.active {
            background: linear-gradient(90deg, rgba(1, 20, 30, 0.95) 0%, rgba(5, 10, 15, 0.9) 100%);
        }

        /* The glowing border for active card */
        .contract-card.active::before {
            box-shadow: inset 0 0 0 2px var(--hex-cyan), inset 0 0 20px rgba(10, 200, 185, 0.2);
        }

        /* Corner accents for the active card */
        .corner-accent {
            position: absolute;
            width: 8px;
            height: 8px;
            background: var(--hex-cyan);
            z-index: 2;
            box-shadow: 0 0 10px var(--hex-cyan);
        }
        .tl { top: 0; left: 15px; } /* Top Left near cut */
        .br { bottom: 0; right: 15px; } /* Bottom Right near cut */


        /* --- ICON / RING AREA --- */
        .icon-wrapper {
            position: relative;
            width: 60px;
            height: 60px;
            display: flex;
            align-items: center;
            justify-content: center;
            margin-right: 20px;
        }

        /* The League "Match Found" Ring */
        .progress-ring {
            position: absolute;
            top: 0;
            left: 0;
            width: 60px;
            height: 60px;
            transform: rotate(-90deg);
        }

        .progress-ring circle {
            fill: transparent;
            stroke-width: 3;
        }

        .ring-bg {
            stroke: rgba(255,255,255,0.1);
        }

        .ring-active {
            stroke: var(--hex-cyan);
            stroke-dasharray: 175; /* approx Circumference of r=28 */
            stroke-dashoffset: 40; /* Partial fill */
            stroke-linecap: round;
            filter: drop-shadow(0 0 5px var(--hex-cyan));
            animation: spinLoad 4s linear infinite;
        }

        @keyframes spinLoad {
            0% { stroke-dashoffset: 175; }
            50% { stroke-dashoffset: 0; }
            100% { stroke-dashoffset: -175; }
        }

        .contract-icon {
            font-size: 1.2rem;
            color: white;
            z-index: 2;
        }

        /* --- TEXT CONTENT --- */
        .card-content {
            flex-grow: 1;
            display: flex;
            flex-direction: column;
            justify-content: center;
            z-index: 2;
        }

        .card-title {
            font-size: 1.1rem;
            font-weight: 900;
            letter-spacing: 1px;
            text-transform: uppercase;
            margin-bottom: 4px;
        }

        .active .card-title {
            color: white;
            text-shadow: 0 0 10px rgba(255,255,255,0.5);
        }

        .status-text {
            font-size: 0.7rem;
            color: var(--hex-gold);
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .active .status-text {
            color: var(--hex-cyan);
        }

        /* --- ACTIONS / BUTTON --- */
        .action-area {
            text-align: right;
            z-index: 2;
        }

        .timer {
            font-size: 0.8rem;
            color: #888;
            margin-bottom: 8px;
            font-family: monospace;
        }
        
        .active .timer {
            color: var(--hex-cyan);
            text-shadow: 0 0 5px var(--hex-cyan);
        }

        /* The "Accept" Button Style */
        .hex-btn {
            background: linear-gradient(to bottom, #1e2328, #13171a);
            border: 1px solid var(--hex-gold-dim);
            color: var(--hex-gold);
            width: 80px;
            height: 30px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 0.7rem;
            font-weight: 700;
            letter-spacing: 1px;
            cursor: pointer;
            position: relative;
            
            /* The specific "Accept" button shape */
            clip-path: polygon(
                10% 0, 90% 0, 
                100% 50%, 90% 100%, 
                10% 100%, 0% 50%
            );
            transition: 0.2s;
        }

        .hex-btn:hover {
            filter: brightness(1.2);
            color: white;
            border-color: var(--hex-gold);
        }

        /* Active "Pause" Button Styling (Cyan) */
        .hex-btn.active-btn {
            background: rgba(10, 200, 185, 0.15);
            border: 1px solid var(--hex-cyan);
            color: var(--hex-cyan);
            box-shadow: 0 0 10px rgba(10, 200, 185, 0.2);
        }

        .hex-btn.active-btn:hover {
            background: var(--hex-cyan);
            color: #000;
            box-shadow: 0 0 15px var(--hex-cyan);
        }

        /* --- DECORATIONS --- */
        /* Smoke/Mist Effect behind the active card */
        .mist-fx {
            position: absolute;
            top: 50%;
            left: 50%;
            width: 120%;
            height: 150%;
            transform: translate(-50%, -50%);
            background: radial-gradient(circle, rgba(10, 200, 185, 0.1) 0%, transparent 70%);
            z-index: 0;
            pointer-events: none;
            opacity: 0;
            transition: opacity 0.5s;
        }

        .contract-card.active .mist-fx {
            opacity: 1;
        }

    </style>
</head>
<body>

    <div class="container">
        <!-- Header -->
        <div class="section-header">
            <div class="header-title">Active Contracts</div>
            <button class="add-btn">+</button>
        </div>

        <!-- Inactive Card: Furiously Happy -->
        <div class="contract-card inactive">
            <div class="icon-wrapper">
                <!-- Static Ring for inactive -->
                <svg class="progress-ring">
                    <circle class="ring-bg" stroke="#444" stroke-width="2" fill="transparent" r="26" cx="30" cy="30" />
                </svg>
                <div class="contract-icon" style="color: #666;">&#9876;</div>
            </div>

            <div class="card-content">
                <div class="card-title">Furiously Happy</div>
                <div class="status-text">Pending</div>
            </div>

            <div class="action-area">
                <div class="timer">00:00</div>
                <button class="hex-btn">
                    START
                </button>
            </div>
        </div>

        <!-- Active Card: PRIMUS (Matches Image 1 Style) -->
        <div class="contract-card active">
            <!-- Decoration Accents -->
            <div class="corner-accent tl"></div>
            <div class="corner-accent br"></div>
            <div class="mist-fx"></div>

            <div class="icon-wrapper">
                <!-- Animated Ring (The "Match Found" Circle) -->
                <svg class="progress-ring">
                    <circle class="ring-bg" r="26" cx="30" cy="30" />
                    <circle class="ring-active" r="26" cx="30" cy="30" />
                </svg>
                <!-- Flame Icon -->
                <div class="contract-icon" style="text-shadow: 0 0 10px var(--hex-cyan);">&#128293;</div>
            </div>

            <div class="card-content">
                <div class="card-title">PRIMUS</div>
                <div class="status-text">In Progress</div>
            </div>

            <div class="action-area">
                <div class="timer">46:44</div>
                <!-- Styled like the "ACCEPT!" button -->
                <button class="hex-btn active-btn">
                    RESUME
                </button>
            </div>
        </div>

    </div>

</body>
</html>
```

    - In analytics, add a button newr WEEKLY REPORT to get the list of archived weekly reports and review them
    - Update screensize limit:
        - Limit the max width for app screen so that it will work in desktop as same as phone with a max width


Make sure there wont be any screensize error, our ideal screen is 720x1520 with 271 dpi

After applying the changes recreate project_snapshot.txt only for new files and files with changes, each time improve modularity of the program by introducing new component files (only on modified or new files), don't modify system files like pubspec, if we need new packages, or file path changes, removal etc, give the command for bash


Thoroughly check for ui sizing errors before writing the code
Note: as output only give project_snapshot and commands if needed
