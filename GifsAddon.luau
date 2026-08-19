<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Eurovision Voting System</title>
  <!-- Firebase SDKs -->
  <script src="https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js"></script>
  <script src="https://www.gstatic.com/firebasejs/9.22.0/firebase-database-compat.js"></script>
  <style>
    :root {
      --bg-color: #0b0b1a;
      --card-bg: #161633;
      --accent-pink: #ff007f;
      --accent-blue: #00f0ff;
      --text-color: #ffffff;
    }
    body {
      background-color: var(--bg-color);
      color: var(--text-color);
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      margin: 0;
      padding: 20px;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .screen { width: 100%; max-width: 500px; text-align: center; }
    .hidden { display: none !important; }
    
    h1 { color: var(--accent-blue); text-shadow: 0 0 10px var(--accent-blue); font-size: 2.2rem; }
    .btn {
      background: linear-gradient(45deg, var(--accent-pink), var(--accent-blue));
      border: none; color: white; padding: 12px 24px; font-weight: bold;
      border-radius: 25px; cursor: pointer; margin: 10px; font-size: 16px;
      box-shadow: 0 0 15px rgba(255,0,127,0.4);
      transition: transform 0.1s;
    }
    .btn:active { transform: scale(0.95); }
    
    .country-row {
      display: flex; justify-content: space-between; align-items: center;
      background: var(--card-bg); margin: 8px 0; padding: 10px 15px;
      border-radius: 8px; border: 1px solid #2a2a5a;
    }
    .country-info { display: flex; align-items: center; gap: 10px; }
    .flag { width: 30px; height: 20px; object-fit: cover; border-radius: 3px; }
    
    .counter-btn {
      background: var(--accent-pink); border: none; color: white;
      width: 32px; height: 32px; border-radius: 50%; font-weight: bold; cursor: pointer;
      font-size: 16px;
    }
    .instructions { color: #aaa; font-size: 14px; margin-bottom: 15px; }
    .error-msg { color: #ff3366; font-weight: bold; margin: 10px 0; }
    
    .staff-footer { margin-top: 40px; padding: 20px; }
    .modal {
      position: fixed; top: 0; left: 0; width: 100%; height: 100%;
      background: rgba(0,0,0,0.9); display: flex; justify-content: center; align-items: center;
    }
    .modal-content { background: var(--card-bg); padding: 25px; border-radius: 12px; border: 1px solid var(--accent-blue); width: 85%; max-width: 400px; }
    input[type="password"] { padding: 10px; border-radius: 5px; border: 1px solid var(--accent-blue); background: #000; color: #fff; text-align: center; }
  </style>
</head>
<body>

  <!-- Screen 1: Welcome -->
  <div id="screen-welcome" class="screen">
    <h1>EUROVISION VOTING</h1>
    <button class="btn" onclick="goToLanguage()">Vote Now</button>
  </div>

  <!-- Screen 2: Language Selection -->
  <div id="screen-language" class="screen hidden">
    <h2>Select Language / Selecciona Idioma</h2>
    <button class="btn" onclick="selectLanguage('es')">Español</button>
    <button class="btn" onclick="selectLanguage('en')">English</button>
    <button class="btn" onclick="selectLanguage('fr')">Français</button>
  </div>

  <!-- Screen 3: Voting Panel -->
  <div id="screen-voting" class="screen hidden">
    <h2>Votación</h2>
    <p id="instruction-text" class="instructions"></p>
    <p id="counter-status" style="font-weight: bold; color: var(--accent-blue); font-size: 1.1rem;"></p>
    <p id="error-display" class="error-msg"></p>

    <div id="country-list"></div>

    <button class="btn" onclick="submitVote()" style="margin-top:20px; font-size: 1.2rem;">Vote</button>
  </div>

  <!-- Staff Footer Button -->
  <div class="staff-footer">
    <button onclick="openStaffModal()" style="background:none; border:1px solid #555; color:#888; padding:5px 10px; border-radius:4px; cursor:pointer;">Staff</button>
  </div>

  <!-- Staff Modal -->
  <div id="staff-modal" class="modal hidden">
    <div class="modal-content">
      <h3>Acceso Staff</h3>
      <div id="staff-auth">
        <input type="password" id="staff-pass" placeholder="Contraseña"><br><br>
        <button class="btn" onclick="checkStaffPass()">Entrar</button>
        <button class="btn" style="background:#555;" onclick="closeStaffModal()">Cancelar</button>
      </div>
      <div id="staff-results" class="hidden">
        <h3>Resultados Globales</h3>
        <ul id="results-list" style="text-align:left; list-style:none; padding:0;"></ul>
        <button class="btn" onclick="closeStaffModal()">Cerrar</button>
      </div>
    </div>
  </div>

  <script>
    // Configuración Firebase (Reemplaza con tus claves si creas tu propio proyecto)
    const firebaseConfig = {
      databaseURL: "https://eurovision-votes-default-rtdb.firebaseio.com/"
    };
    if (!firebase.apps.length) { firebase.initializeApp(firebaseConfig); }
    const db = firebase.database();

    // Países con banderas de Flagcdn
    const countries = [
      { name: "España", code: "es" },
      { name: "Francia", code: "fr" },
      { name: "Italia", code: "it" },
      { name: "Reino Unido", code: "gb" },
      { name: "Alemania", code: "de" },
      { name: "Suecia", code: "se" },
      { name: "Ucrania", code: "ua" }
    ];

    let votes = {};
    let currentLang = 'es';

    // Generación de sonidos mediante Web Audio API (Sin archivos externos)
    const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    function playBeep(freq) {
      if (audioCtx.state === 'suspended') { audioCtx.resume(); }
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.frequency.value = freq;
      osc.type = 'sine';
      gain.gain.setValueAtTime(0.1, audioCtx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + 0.15);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start();
      osc.stop(audioCtx.currentTime + 0.15);
    }

    const translations = {
      es: {
        instr: "Debes repartir exactamente 20 votos entre un mínimo de 4 países.",
        rem: "Votos restantes: ",
        errMin: "Debes votar al menos a 4 países diferentes.",
        errTotal: "Debes repartir exactamente los 20 votos.",
        alreadyVoted: "Ya has votado desde este dispositivo."
      },
      en: {
        instr: "You must distribute exactly 20 votes among at least 4 countries.",
        rem: "Remaining votes: ",
        errMin: "You must vote for at least 4 different countries.",
        errTotal: "You must distribute exactly 20 votes.",
        alreadyVoted: "You have already voted from this device."
      },
      fr: {
        instr: "Vous devez distribuer exactement 20 votes entre au moins 4 pays.",
        rem: "Votes restants: ",
        errMin: "Vous devez voter pour au moins 4 pays différents.",
        errTotal: "Vous devez distribuer exactement les 20 votes.",
        alreadyVoted: "Vous avez déjà voté depuis cet appareil."
      }
    };

    function goToLanguage() {
      if (localStorage.getItem('hasVoted')) {
        alert(translations[currentLang].alreadyVoted);
        return;
      }
      document.getElementById('screen-welcome').classList.add('hidden');
      document.getElementById('screen-language').classList.remove('hidden');
    }

    function selectLanguage(lang) {
      currentLang = lang;
      document.getElementById('screen-language').classList.add('hidden');
      document.getElementById('screen-voting').classList.remove('hidden');
      initVoting();
    }

    function initVoting() {
      document.getElementById('instruction-text').innerText = translations[currentLang].instr;
      const listContainer = document.getElementById('country-list');
      listContainer.innerHTML = '';
      
      countries.forEach(c => {
        votes[c.name] = 0;
        const row = document.createElement('div');
        row.className = 'country-row';
        row.innerHTML = `
          <div class="country-info">
            <img src="https://flagcdn.com/w40/${c.code}.png" class="flag" alt="${c.name}">
            <span>${c.name}</span>
          </div>
          <div>
            <button class="counter-btn" onclick="changeVote('${c.name}', -1)">-</button>
            <span id="count-${c.name}" style="margin: 0 10px;">0</span>
            <button class="counter-btn" onclick="changeVote('${c.name}', 1)">+</button>
          </div>
        `;
        listContainer.appendChild(row);
      });
      updateCounterDisplay();
    }

    function changeVote(country, delta) {
      const totalUsed = Object.values(votes).reduce((a, b) => a + b, 0);
      if (delta > 0 && totalUsed >= 20) return;
      if (votes[country] + delta < 0) return;

      votes[country] += delta;
      document.getElementById(`count-${country}`).innerText = votes[country];
      playBeep(delta > 0 ? 600 : 400); // Sonido alto para (+), grave para (-)
      updateCounterDisplay();
    }

    function updateCounterDisplay() {
      const totalUsed = Object.values(votes).reduce((a, b) => a + b, 0);
      document.getElementById('counter-status').innerText = `${translations[currentLang].rem} ${20 - totalUsed}`;
    }

    function submitVote() {
      const activeCountries = Object.values(votes).filter(v => v > 0).length;
      const totalVotes = Object.values(votes).reduce((a, b) => a + b, 0);
      const errorEl = document.getElementById('error-display');

      if (activeCountries < 4) {
        errorEl.innerText = translations[currentLang].errMin;
        return;
      }
      if (totalVotes !== 20) {
        errorEl.innerText = translations[currentLang].errTotal;
        return;
      }

      // Guardar bloqueo local
      localStorage.setItem('hasVoted', 'true');

      // Enviar a la base de datos en tiempo real
      for (let c in votes) {
        if (votes[c] > 0) {
          db.ref('votes/' + c).transaction(current => (current || 0) + votes[c]);
        }
      }

      playBeep(880);
      alert("¡Gracias por votar / Thank you for voting!");
      location.reload();
    }

    /* Lógica Staff */
    function openStaffModal() { document.getElementById('staff-modal').classList.remove('hidden'); }
    function closeStaffModal() { document.getElementById('staff-modal').classList.add('hidden'); }
    
    function checkStaffPass() {
      if (document.getElementById('staff-pass').value === '14mayo') {
        document.getElementById('staff-auth').classList.add('hidden');
        document.getElementById('staff-results').classList.remove('hidden');
        
        // Leer votos globales en tiempo real
        db.ref('votes').on('value', snapshot => {
          const data = snapshot.val() || {};
          const list = document.getElementById('results-list');
          list.innerHTML = '';
          countries.forEach(c => {
            const count = data[c.name] || 0;
            list.innerHTML += `<li style="padding:4px 0;"><strong>${c.name}:</strong> ${count} votos</li>`;
          });
        });
      } else {
        alert('Contraseña incorrecta');
      }
    }
  </script>
</body>
</html>