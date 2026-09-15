/* Gráfico product prototype. Capture, permissions, inference and OS actions
   are simulated. Explicit export actions download sample Markdown files. */
'use strict';
const $ = selector => document.querySelector(selector);
const escapeHTML = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const state = {
  scene:'onboarding', scenario:'', mic:true, paste:true, models:true,
  setup:{step:0,progress:0,error:false,practice:'',done:false},
  dictado:{recording:false,finishing:false,text:'',note:'',error:null},
  acta:{phase:'ready',source:'Meet',audio:false,elapsed:0,lines:[],sourceLost:false,saveError:false,file:null,collapsed:false},
  prefs:{shortcut:'⌃ ⌥',overlay:true,history:true},
  home:{tab:'tools',query:'',file:null},
};
let sceneTimers=[],toastTimer,keysDown=false,serial=10,sessionGeneration=0;
const initialState=JSON.stringify(state);
const sampleText='A little less busy. A little more room for the good ideas.';
const conversation=[
  'Let’s keep the first version small and make it feel good to use.',
  'One shortcut should be enough to get a thought into the app in front of us.',
  'We can try it together on Friday and see what still gets in the way.',
  'The useful thing at the end is a file we can bring back into our work.',
];
const files=[
  {id:1,type:'dictado',title:'A thought for the morning',name:'dictado-2026-09-14-0938.md',time:'Today · 9:38',text:'Leave a little room for the ideas you haven’t had yet.',path:'~/Documents/tapas/dictado/'},
  {id:2,type:'dictado',title:'Nos vemos en la terraza',name:'dictado-2026-09-13-1800.md',time:'Yesterday · Spanish',text:'Nos vemos en la terraza a las seis. Llevo algo para picar.',path:'~/Documents/tapas/dictado/'},
];
const initialFiles=JSON.stringify(files);
const journeys={
  onboarding:{caption:'Start with a sentence. Permissions arrive with a reason; the pintxo assembles as you get ready.',status:'FIRST, A LITTLE TASTE.',flow:['Meet Tapas','Microphone','Paste','Prepare','Try it','Ready'],faults:[['mic-denied','Microphone denied'],['download-offline','Download interrupted']]},
  dictado:{caption:'Press, speak, press again. Words land in your app; a copy can stay on your shelf.',status:'DICTADO / SAY YOUR THING.',flow:['Ready','Listening','Finishing','Paste + save','Tuck away'],faults:[['paste-failed','Paste blocked'],['no-speech','No speech detected'],['mic-denied','Microphone unavailable']]},
  acta:{caption:'Choose the app and start explicitly. Pause, collapse, or switch tasks while the record stays available.',status:'ACTA / LAUNCH TOOL · DESIGN PREVIEW.',flow:['Choose source','App audio access','Record','Pause / resume','Finish','Keep the file'],faults:[['source-lost','App audio interrupted'],['save-failed','File could not be saved']]},
  home:{caption:'A compact home for your tools, recent files and preferences. Useful files remain the common thread.',status:'YOUR PLATE / ALL WITHIN REACH.',flow:['Tools','Recent files','Open / copy / export','Preferences'],faults:[]},
};
function schedule(fn,ms){sceneTimers.push(setTimeout(fn,ms));}
function clearSceneTimers(){sceneTimers.forEach(clearTimeout);sceneTimers=[];}
function toast(message){clearTimeout(toastTimer);$('#toast').textContent=message;$('#toast').classList.add('show');toastTimer=setTimeout(()=>$('#toast').classList.remove('show'),3400);}
function mini(){return '<span class="mini-mark" aria-hidden="true"><i></i><i></i><i></i><i></i></span>';}
function pintxo(motion='idle',assembly=4){return `<div class="pintxo-wrap" data-motion="${motion}" data-assembly="${assembly}" aria-hidden="true"><span class="pintxo"><i class="pick"></i><i class="bite a"></i><i class="bite b"></i><i class="bite c"></i><i class="bite d"></i></span></div>`;}
function glyph(type){const symbols={dictado:'≋',acta:'↔'};return `<span class="tool-glyph ${type}" aria-hidden="true">${symbols[type]}</span>`;}
function wave(){return `<span class="wave" aria-hidden="true">${[7,13,19,10,16,6,12].map((h,i)=>`<i style="--height:${h}px;--delay:${i*.1}s"></i>`).join('')}</span>`;}
function chrome(title,action='home'){return `<div class="window-bar"><span class="traffic" aria-hidden="true"><i></i><i></i><i></i></span><span>${title}</span><button data-action="${action}" aria-label="Close ${title}">×</button></div>`;}
function shortcutSelect(){return `<select id="shortcut" aria-label="Dictation shortcut"><option ${state.prefs.shortcut==='⌃ ⌥'?'selected':''}>⌃ ⌥</option><option ${state.prefs.shortcut==='Right ⌘'?'selected':''}>Right ⌘</option></select>`;}
function notch(){
  let label='';if(state.dictado.recording)label='Dictado · Listening';else if(state.dictado.finishing)label='Finishing';else if(state.acta.phase==='recording')label='Acta · '+formatTime(state.acta.elapsed);else if(state.acta.phase==='paused')label='Acta · Paused';
  $('#notch-label').textContent=label;$('#notch').classList.toggle('active',!!label);
}
function storeNote(){const input=$('#note-editor');if(input)state.dictado.note=input.value;}
function go(scene){
  if(!journeys[scene])scene='home';
  storeNote();clearSceneTimers();clearTimeout(toastTimer);$('#toast').classList.remove('show');$('#flight').innerHTML='';
  state.dictado.recording=false;state.dictado.finishing=false;state.dictado.error=null;
  state.scene=scene;state.scenario='';if(scene==='acta')state.acta.collapsed=false;
  document.querySelectorAll('[data-scene]').forEach(b=>{if(b.dataset.scene===scene)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');});
  const j=journeys[scene];$('#caption').textContent=j.caption;$('#desktop-status').textContent=j.status;$('#active-app').textContent=scene==='dictado'?'Notes':scene==='acta'?state.acta.source:'Finder';
  $('#flow-map').innerHTML=j.flow.map((s,i)=>`${i?'<i>→</i>':''}<span>${s}</span>`).join('');
  $('#scenario').innerHTML='<option value="">Everything works</option>'+j.faults.map(([id,label])=>`<option value="${id}">${label}</option>`).join('');$('#scenario').disabled=!j.faults.length;
  $('#scenario-description').textContent=j.faults.length?'See how Tapas helps you recover.':'Use search and preferences to explore.';
  history.replaceState(null,'',`#${scene}`);render();notch();renderCompanion();
}
function render(){({onboarding:renderSetup,dictado:renderDictado,acta:renderActa,home:renderHome}[state.scene])();}
function setupShell(body,assembly=4,motion='idle'){
  const step=state.setup.step;$('#scene').innerHTML=`<section class="window setup" aria-label="Dictado onboarding">${chrome('A first taste of Tapas','leave-setup')}<div class="setup-inner"><aside class="setup-art">${pintxo(motion,assembly)}<span class="label">SMALL TOOLS.<br>GOOD COMPANY.</span></aside><div class="setup-body">${body}</div></div><div class="setup-bottom"><span class="step-dots" aria-label="Step ${step+1} of 6">${[0,1,2,3,4,5].map(i=>`<i class="${step===i?'active':''}"></i>`).join('')}</span><span>LOCAL INTELLIGENCE. WITH GUSTO.</span></div></section>`;
}
function renderSetup(){
  const s=state.setup;
  if(s.step===0){setupShell(`<span class="eyebrow">YOUR FIRST TASTE OF TAPAS</span><h1>A small start.<br><em>A good habit.</em></h1><p class="subtext">A few clever tools, right here on your Mac. First up: turn a thought into words.</p><div class="feature-row">${glyph('dictado')}<div><strong>Dictado</strong><small>You say it. It lands where you type.</small></div></div><button class="button wide" data-action="setup-begin">Let’s make a start <span>→</span></button><p class="setup-footnote">No account. Voice processing stays on this Mac.</p>`);return;}
  if(s.step===1){const denied=state.scenario==='mic-denied';setupShell(`<span class="eyebrow">01 / A LITTLE PERMISSION</span><h1>Let’s hear<br><em>your thing.</em></h1><p class="subtext">Allow your microphone so Dictado can turn speech into text. It listens when you start a take.</p><div class="permission-row"><span>Microphone<small>${denied?'Not allowed yet.':'Used during your takes.'}</small></span>${glyph('dictado')}</div>${denied?'<div class="note-box error"><strong>Microphone access is off.</strong>Enable Tapas in Privacy & Security → Microphone, then return here.</div>':''}<button class="button wide" data-action="setup-mic">${denied?'Open microphone settings':'Allow microphone'} <span>→</span></button><p class="setup-footnote">Permission is simulated in this prototype.</p>`,1);return;}
  if(s.step===2){setupShell(`<span class="eyebrow">02 / PUT IT IN THE RIGHT PLACE</span><h1>Say it here.<br><em>Write anywhere.</em></h1><p class="subtext">Accessibility enables the shortcut across apps and lets Tapas paste where your cursor is.</p><div class="permission-row"><span>Tapas<small>Privacy & Security → Accessibility</small></span>${mini()}</div><button class="button blue wide" data-action="setup-paste">Enable in Settings <span>↗</span></button><button class="text-button" data-action="setup-skip-paste">Later. I’ll copy my words.</button><p class="setup-footnote">This preview simulates the settings change.</p>`,2);return;}
  if(s.step===3){setupShell(`<span class="eyebrow">03 / BRING THE BRAINS HOME</span><h1>A little prep.<br><em>Then we’re ready.</em></h1><p class="subtext">Bring the voice models onto your Mac. After setup, Dictado can work offline.</p><div class="progress-head"><span id="model-label">${s.error?'Download interrupted':s.progress===100?'Ready on this Mac':s.progress>=80?'Preparing the models':'Downloading voice models'}</span><span id="model-percent">${s.progress}%</span></div><div class="progress-track" role="progressbar" aria-label="Simulated model preparation" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${s.progress}"><i style="width:${s.progress}%"></i></div><p class="download-caption">One-time setup · Sample progress</p>${s.error?'<div class="note-box error"><strong>We lost the connection.</strong>Your progress is kept. Reconnect and try again.</div><button class="button wide" data-action="retry-download">Try again →</button>':`<button class="button wide" id="model-continue" data-action="setup-practice" ${s.progress<100?'disabled':''}>${s.progress<100?'Getting ready…':'Give it a try →'}</button>`}`,3,s.error?'idle':s.progress===100?'done':'working');if(!s.error&&s.progress<100)downloadTick();return;}
  if(s.step===4){setupShell(`<span class="eyebrow">04 / YOUR FIRST TASTE</span><h1>Go on.<br><em>Say a little.</em></h1><p class="subtext">Press once to start, again to finish.<br>We’ll lend you a sample thought for this preview.</p><label class="shortcut-row">Your shortcut ${shortcutSelect()}</label><div class="practice-pad ${s.practice?'':'empty'}" id="practice-text" aria-live="polite">${escapeHTML(s.practice||'“A little more room for the good ideas.”')}</div><button class="button wide" id="practice-button" data-action="practice">${state.dictado.recording?'Finish the thought':'Try a sample take'} <span>↗</span></button>${s.practice&&!state.dictado.recording?'<button class="text-button" data-action="setup-complete">That’s the idea. Continue →</button>':''}<p class="setup-footnote">${state.paste?'Your words will land in the app you’re using.':'Paste access is off. Finished words can be copied.'}</p>`,4,state.dictado.recording?'listening':s.practice?'done':'idle');return;}
  setupShell(`<span class="success-stamp">✓ READY WITH GUSTO</span><h1>Now, back<br><em>to your day.</em></h1><p class="subtext">Your next thought is one shortcut away.<br><span class="key">${state.prefs.shortcut}</span> to start. The same to finish.</p><div class="note-box"><strong>Your words have a home.</strong>Documents / tapas / dictado<br>Plain files for you and the tools you use.</div><button class="button blue wide" data-action="daily">Take it for a spin <span>→</span></button><button class="text-button" data-action="home">See what’s on the plate</button>`,4,'done');
}
function downloadTick(){schedule(()=>{if(state.scene!=='onboarding'||state.setup.step!==3||state.setup.error)return;const s=state.setup;s.progress=Math.min(100,s.progress+4);if(state.scenario==='download-offline'&&s.progress>=36){s.error=true;renderSetup();return;}$('#model-percent').textContent=s.progress+'%';$('.progress-track').setAttribute('aria-valuenow',s.progress);$('.progress-track i').style.width=s.progress+'%';$('#model-label').textContent=s.progress>=80?'Preparing the models':'Downloading voice models';if(s.progress===100){state.models=true;$('#model-label').textContent='Ready on this Mac';$('#model-continue').disabled=false;$('#model-continue').textContent='Give it a try →';$('.setup-art .pintxo-wrap').dataset.motion='done';}else downloadTick();},135);}
function practice(){
  if(state.dictado.recording){clearSceneTimers();state.dictado.recording=false;if(!state.setup.practice)toast('No words yet. Try the sample again.');renderSetup();notch();return;}
  clearSceneTimers();state.setup.practice='';state.dictado.recording=true;renderSetup();$('#practice-text').textContent='Listening…';notch();
  ['A little more room','A little more room for the good ideas.'].forEach((text,i)=>schedule(()=>{if(!state.dictado.recording)return;state.setup.practice=text;$('#practice-text').classList.remove('empty');$('#practice-text').textContent=text;},500+i*850));
}
function renderDictado(){
  const a=state.acta;const recordingMeeting=a.phase==='recording';
  $('#scene').innerHTML=`<section class="window desktop-note" aria-label="Sample Notes app">${chrome('Notes')}<div class="note-content"><small>MONDAY · A LITTLE ROOM TO THINK</small><h2>Things worth making.</h2><p>A place for the ideas that turn up<br>when the day has a little space.</p><textarea id="note-editor" aria-label="Sample note" placeholder="Your next thought goes here…">${escapeHTML(state.dictado.note)}</textarea></div></section><aside class="dictado-aside">${pintxo()}<span class="eyebrow">DICTADO / EVERY DAY</span><h2>A thought.<br><em>Without the typing.</em></h2><p><span class="key">${state.prefs.shortcut}</span> to start and finish.<br>Esc to cancel.</p><button class="button" id="record-button" data-action="record">${recordingMeeting?'Pause Acta & talk':'Start a take'} ↗</button>${recordingMeeting?'<div class="note-box">Acta will pause for this take. Resume it from the meeting status when you’re ready.</div>':''}</aside><div id="hud-host"></div>`;
}
function record(){
  if(state.dictado.finishing)return;if(state.dictado.recording){finishTake();return;}
  if(!state.mic||state.scenario==='mic-denied'){showHUD('Microphone access is off.','Enable access, then start your take.','<button data-action="recover-mic">Open microphone settings ↗</button>');return;}
  if(!state.models){showHUD('A little preparation first.','The voice models need to be ready.','<button data-action="resume-setup">Continue setup →</button>');return;}
  if(state.acta.phase==='recording'){state.acta.phase='paused';renderCompanion();toast('Acta is paused. Resume it after this take.');}
  storeNote();clearSceneTimers();state.dictado.recording=true;state.dictado.text='';state.dictado.error=null;$('#record-button').textContent='Finish take ↵';$('.dictado-aside .pintxo-wrap').dataset.motion='listening';notch();
  if(state.prefs.overlay)$('#hud-host').innerHTML=`<section class="dictation-hud" aria-label="Dictado listening"><div class="hud-top">${glyph('dictado')} DICTADO / LISTENING ${wave()}</div><p class="hud-copy" id="live-words" aria-live="polite">Go on. Your thought goes here.</p><div class="hud-bottom"><span><span class="key">${state.prefs.shortcut}</span> to finish</span><button data-action="cancel-take">Esc · Cancel</button></div></section>`;
  if(state.scenario==='no-speech')return;
  const words=sampleText.split(' ');for(let i=0;i<words.length;i+=4)schedule(()=>{if(!state.dictado.recording)return;state.dictado.text=words.slice(0,i+4).join(' ');if($('#live-words'))$('#live-words').textContent=state.dictado.text;},450+(i/4)*700);
}
function showHUD(title,detail,action){$('#hud-host').innerHTML=`<section class="dictation-hud" aria-label="Dictado result"><div class="hud-top">${glyph('dictado')} DICTADO</div><p class="hud-copy">${escapeHTML(title)}</p><div class="hud-bottom"><span>${escapeHTML(detail)}</span>${action}</div></section>`;}
function finishTake(){
  clearSceneTimers();state.dictado.recording=false;$('#record-button').textContent='Start a take ↗';
  if(!state.dictado.text){$('.dictado-aside .pintxo-wrap').dataset.motion='idle';notch();showHUD('No words came through.','Nothing saved. Try again when you’re ready.','<button data-action="retry-take">Try again →</button>');return;}
  state.dictado.finishing=true;$('#record-button').disabled=true;$('.dictado-aside .pintxo-wrap').dataset.motion='working';notch();if($('#live-words'))$('#live-words').textContent='Finishing your thought…';
  schedule(()=>{
    state.dictado.finishing=false;$('#record-button').disabled=false;$('.dictado-aside .pintxo-wrap').dataset.motion='done';notch();
    if(state.prefs.history)addFile('dictado','Dictation · just now',state.dictado.text);
    if(!state.paste||state.scenario==='paste-failed'){showHUD(state.dictado.text,'Your words are kept. Paste access is unavailable.','<button data-action="manual-paste">Place in sample note →</button>');return;}
    landTake();
  },650);
}
function landTake(){const editor=$('#note-editor');state.dictado.note=editor.value+(editor.value?'\n':'')+state.dictado.text;editor.value=state.dictado.note;$('#hud-host').innerHTML='';$('#flight').innerHTML=state.dictado.text.split(' ').filter((_,i)=>i%3===0).map((word,i)=>`<span class="flying-word" style="--delay:${i*.05}s">${escapeHTML(word)}</span>`).join('');toast('✓ In your note.'+(state.prefs.history?' A copy is on your shelf.':''));schedule(()=>{$('#flight').innerHTML='';},1200);}
function cancelTake(){clearSceneTimers();state.dictado.recording=false;state.dictado.finishing=false;state.dictado.text='';notch();if(state.scene==='onboarding'){state.setup.practice='';renderSetup();}else{storeNote();renderDictado();}toast('Take cancelled. Nothing saved.');}
function addFile(type,title,text){const file={id:++serial,type,title,text,time:'Just now',name:`${type}-sample-${serial}.md`,path:`~/Documents/tapas/${type}/`};files.unshift(file);return file;}
function formatTime(seconds){return `${String(Math.floor(seconds/60)).padStart(2,'0')}:${String(seconds%60).padStart(2,'0')}`;}

function renderActa(){
  const a=state.acta;const running=['recording','paused'].includes(a.phase);
  let body='';
  if(a.phase==='ready')body=`<span class="eyebrow">A LITTLE ROOM FOR THE CONVERSATION</span><h3>Be here.<br>Keep the words.</h3><p class="subtext">Choose the meeting app. Acta records its audio and your microphone when you start.</p><label class="source-picker"><span>Meeting app<small>Choose the source yourself.</small></span><select id="meeting-source"><option ${a.source==='Meet'?'selected':''}>Meet</option><option ${a.source==='Zoom'?'selected':''}>Zoom</option><option ${a.source==='Teams'?'selected':''}>Teams</option></select></label><div class="source-picker"><span>Your microphone<small>${state.mic?'Ready for your voice.':'Microphone permission needed.'}</small></span>${state.mic?'<span class="check">✓</span>':'<button class="text-button" data-action="acta-mic">Allow</button>'}</div><div class="source-picker"><span>App audio access<small>${a.audio?'Ready for the conversation.':'Required before the first meeting.'}</small></span>${a.audio?'<span class="check">✓</span>':'<button class="text-button" data-action="acta-audio">Allow</button>'}</div>${!a.audio?'<div class="note-box">Allow the app’s audio to be captured. This preview simulates the permission.</div>':''}<button class="button blue wide" data-action="acta-start" ${!a.audio||!state.mic?'disabled':''}>Start Acta <span>→</span></button><p class="privacy-caption">Start when everyone is ready to be recorded.<br>Sample meeting · no audio captured in this preview.</p>`;
  if(running)body=`<div class="acta-live-top"><div><span class="time" id="meeting-time">${formatTime(a.elapsed)}</span><br><small>${a.phase==='paused'?'PAUSED · NO AUDIO CAPTURE':'RECORDING ON THIS MAC'}</small></div>${glyph('acta')}</div><div class="audio-meter ${a.phase==='paused'?'paused':''}"><div><span>Your microphone</span><span>${a.phase==='paused'?'Paused':'Active'}</span></div><div class="meter-track"><i style="--level:68%"></i></div></div><div class="audio-meter app ${a.phase==='paused'?'paused':''} ${a.sourceLost?'missing':''}"><div><span>${a.source} audio</span><span>${a.sourceLost?'Unavailable':a.phase==='paused'?'Paused':'Active'}</span></div><div class="meter-track"><i style="--level:85%"></i></div></div>${a.sourceLost?`<div class="note-box warning"><strong>${a.source} audio stopped.</strong>Your microphone ${a.phase==='paused'?'is paused':'is still being captured'}. Return to the meeting app or reconnect its audio.<button class="text-button" data-action="acta-reconnect">Reconnect app audio</button></div>`:''}<div class="live-transcript" id="meeting-transcript" aria-live="polite"><small>LIVE TRANSCRIPT / PREVIEW</small>${a.lines.map(l=>`<p>${escapeHTML(l.text)}</p>`).join('')||'<p>The conversation will appear here.</p>'}</div><div class="actions"><button class="button secondary" data-action="acta-pause">${a.phase==='paused'?'Resume':'Pause'}</button><button class="button blue" data-action="acta-finish">Finish & keep →</button></div><p class="privacy-caption">${a.phase==='paused'?'Resume explicitly when you’re ready.':'You can collapse this card and keep working.'}<br>Speaker attribution is not part of this preview.</p>`;
  if(a.phase==='finishing')body=`${pintxo('working')}<h3>Keeping the<br>good part.</h3><p class="subtext">Finishing the transcript and preparing your file.</p>`;
  if(a.phase==='finished')body=`<div class="receipt"><span class="eyebrow">TAPAS / ACTA / ONE GOOD CONVERSATION</span><h3>A conversation,<br>worth keeping.</h3><p>${escapeHTML(a.source)} catch-up<br>${formatTime(a.elapsed)} recorded · Sample transcript</p><hr><div class="filename">${escapeHTML(a.file?.name||'acta-sample.md')}</div><p class="file-ready">${a.saveError?'Not saved yet':'✓ On your shelf · Markdown'}</p></div>${a.saveError?'<div class="note-box error"><strong>The file couldn’t be saved.</strong>Your transcript is still here. Retry or export a copy.<button class="text-button" data-action="acta-retry-save">Try saving again →</button></div>':''}<button class="button blue wide" data-action="acta-export">${a.saveError?'Export a copy':'Take the transcript'} <span>↗</span></button><button class="text-button" data-action="acta-open-file">Read the transcript</button><p class="privacy-caption">A local file for you, Claude, Codex or Cursor.<br>Export downloads a sample Markdown file.</p><button class="text-button" data-action="acta-new">Start another meeting</button>`;
  $('#scene').innerHTML=`<aside class="meeting-context"><span class="eyebrow">ACTA / LAUNCH TOOL</span><h2>Stay for<br><em>the conversation.</em></h2><p>A little more sobremesa. A useful record when it’s time to get back to work.</p><span class="badge blue">DESIGN PREVIEW</span><div class="conversation"><div class="conversation-line"><small>THE CONVERSATION</small><p>A little less software.<br>A little more feeling.</p></div><div class="conversation-line"><small>THE THING YOU KEEP</small><p>Words you can return to.<br>A file you can use.</p></div></div></aside>${a.collapsed?'<section class="acta-card"><div class="acta-card-body"><h3>Acta is nearby.</h3><p class="subtext">The compact status stays visible while you work.</p><button class="button blue wide" data-action="acta-expand">Open the meeting →</button></div></section>':`<section class="acta-card" aria-label="Acta meeting capture"><div class="acta-card-head">${glyph('acta')}<span>Acta</span>${running?'<button class="text-button" data-action="acta-collapse">Collapse ↗</button>':'<span class="badge blue">CONCEPT</span>'}</div><div class="acta-card-body">${body}</div></section>`}`;
  renderCompanion();
}
function startMeeting(){if(!state.mic||!state.acta.audio)return;Object.assign(state.acta,{phase:'recording',elapsed:0,lines:[],sourceLost:state.scenario==='source-lost',saveError:false,file:null});renderActa();notch();}
function finishMeeting(){
  const a=state.acta;const generation=sessionGeneration;a.phase='finishing';a.collapsed=false;renderActa();notch();
  // Finalization is independent of scene navigation, just like a background job.
  setTimeout(()=>{if(a.phase!=='finishing'||generation!==sessionGeneration)return;a.phase='finished';a.saveError=!!a.failSave||state.scenario==='save-failed';const text=a.lines.map(l=>`[${formatTime(l.at)}] ${l.text}`).join('\n\n')||'No speech was captured in this sample meeting.';a.file={id:++serial,type:'acta',title:a.source+' catch-up',name:`acta-sample-${serial}.md`,path:'~/Documents/tapas/acta/',time:'Just now',text};if(!a.saveError)files.unshift(a.file);if(state.scene==='acta')renderActa();else toast(a.saveError?'Acta needs help saving. Open the meeting to recover.':'✓ Acta is saved on your shelf.');renderCompanion();},650);
}
function renderCompanion(){
  const a=state.acta;const active=['recording','paused','finishing'].includes(a.phase);if(!active||state.scene==='acta'&&!a.collapsed){$('#acta-companion').innerHTML='';return;}
  $('#acta-companion').innerHTML=`<aside class="companion ${a.phase==='paused'?'paused':''}" aria-label="Acta background status">${glyph('acta')}<span><strong>${a.phase==='paused'?'Acta is paused':a.phase==='finishing'?'Keeping your transcript':'Acta is recording'}</strong><small id="companion-time">${formatTime(a.elapsed)} · ${a.source}</small></span><button data-action="acta-expand">Open ↗</button></aside>`;
}
setInterval(()=>{
  const a=state.acta;if(a.phase!=='recording')return;a.elapsed++;
  if(a.elapsed===2||(a.elapsed%5===0&&a.lines.length<conversation.length)){a.lines.push({at:a.elapsed,text:conversation[a.lines.length]});const live=$('#meeting-transcript');if(live){live.innerHTML='<small>LIVE TRANSCRIPT / PREVIEW</small>'+a.lines.map(l=>`<p>${escapeHTML(l.text)}</p>`).join('');live.scrollTop=live.scrollHeight;}}
  if($('#meeting-time'))$('#meeting-time').textContent=formatTime(a.elapsed);if($('#companion-time'))$('#companion-time').textContent=formatTime(a.elapsed)+' · '+a.source;notch();
},1000);

function renderHome(){
  const h=state.home;$('#scene').innerHTML=`<aside class="home-aside"><span class="eyebrow">SMALL TOOLS. SHARED HOME.</span><h2>What’s on<br><em>your plate?</em></h2><p>A thought, a conversation, a moment worth keeping. Everything has a place.</p><code>~/Documents/tapas/</code></aside><section class="window home-window" aria-label="Your Tapas plate"><div class="home-heading"><div><h2>Your plate.</h2><p><span class="status-dot"></span>${state.mic&&state.models?'Dictado is ready':'Dictado needs setup'} · ${state.prefs.shortcut}</p></div>${mini()}</div><nav class="home-tabs" aria-label="Plate views">${[['tools','Tools'],['history','Recent'],['settings','Preferences']].map(([id,label])=>`<button data-tab="${id}" class="${h.tab===id?'active':''}" ${h.tab===id?'aria-current="page"':''}>${label}</button>`).join('')}</nav><div class="home-body" id="home-body"></div><div class="home-footer"><span>Local files · sample library</span><button data-action="folder-info">About your folder ↗</button></div></section>`;
  if(h.file){renderFile(h.file);return;}
  if(h.tab==='tools'){
    $('#home-body').innerHTML=`<div class="featured-tool"><div class="title-row">${glyph('dictado')}<span class="badge">${state.models&&state.mic?'READY TO SERVE':'SETUP NEEDED'}</span></div><h3>Dictado</h3><p>A thought, a message, a whole paragraph.<br>Say it where you want to write it.</p><button class="button wide" data-action="${state.models&&state.mic?'daily':'resume-setup'}">${state.models&&state.mic?'Start a take':'Finish setup'} <span>${state.prefs.shortcut}</span></button></div><button class="tool-row" data-action="acta">${glyph('acta')}<span><strong>Acta</strong><small>Be there. Keep the conversation.</small></span><span class="badge blue">DESIGN PREVIEW</span></button>`;return;
  }
  if(h.tab==='history'){$('#home-body').innerHTML=`<label class="search-box">⌕<input id="history-query" type="search" aria-label="Search recent files" placeholder="Find a thought…" value="${escapeHTML(h.query)}"></label><div id="history-list"></div>`;renderHistory();return;}
  $('#home-body').innerHTML=`<div class="setting-row"><span>Shortcut<small>Press once to start. Again to finish.</small></span>${shortcutSelect()}</div>${[['overlay','Show live words','A small overlay while you speak.'],['history','Save a history','Keep a Markdown file after each take.']].map(([id,title,description])=>`<div class="setting-row"><span>${title}<small>${description}</small></span><button class="switch" role="switch" aria-label="${title}" aria-checked="${state.prefs[id]}" data-pref="${id}"></button></div>`).join('')}<div class="setting-row"><span>Paste into apps<small>Accessibility permission · simulated</small></span><button class="switch" role="switch" aria-label="Paste into apps" aria-checked="${state.paste}" data-pref="paste"></button></div><div class="setting-row"><span>Languages<small>25 supported European languages</small></span><span style="font-size:9px">Automatic</span></div><button class="text-button" data-action="resume-setup">Revisit setup</button><p class="privacy-caption">Powered by Desert Ant Labs<br>Preferences apply to this preview until reload.</p>`;
}
function renderHistory(){const found=files.filter(f=>(f.title+' '+f.text+' '+f.type).toLowerCase().includes(state.home.query.toLowerCase()));$('#history-list').innerHTML=found.length?found.map(f=>`<button class="history-row" data-file="${f.id}">${glyph(f.type)}<span><strong>${escapeHTML(f.title)}</strong><small>${f.type} · ${f.time}</small></span><span class="arrow">↗</span></button>`).join(''):'<div class="empty-state">No matching notes.<br>Try another word.</div>';}
function renderFile(file){$('#home-body').innerHTML=`<article class="file-detail"><button class="text-button" data-action="back-files">← Recent files</button><h3>${escapeHTML(file.title)}</h3><small>${escapeHTML(file.path+file.name)}</small><pre>${escapeHTML(file.text)}</pre><div class="actions"><button class="button" data-action="copy-file">Copy text</button><button class="button secondary" data-action="export-file">Export .md ↗</button></div><p class="privacy-caption">Bring the file to your assistant as context.</p></article>`;}
function openFile(file){state.home.tab='history';state.home.file=file;go('home');}
async function copyText(text){try{await navigator.clipboard.writeText(text);toast('Copied. Ready to use where you need it.');}catch{toast('Clipboard unavailable. Export the note to keep a copy.');}}
function exportFile(file){const url=URL.createObjectURL(new Blob([`# ${file.title}\n\n${file.text}\n\n---\nTapas Gráfico prototype · Sample content\n`],{type:'text/markdown;charset=utf-8'}));const link=document.createElement('a');link.href=url;link.download=file.name;link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);toast('Sample Markdown file exported.');}

function resumeSetup(){state.setup.step=!state.mic?1:!state.models?3:4;go('onboarding');}
function clearScenario(){state.scenario='';$('#scenario').value='';}
document.addEventListener('click',event=>{
  const button=event.target.closest('button');if(!button)return;
  if(button.dataset.scene){go(button.dataset.scene);return;}
  if(button.dataset.tab){state.home.tab=button.dataset.tab;state.home.file=null;renderHome();return;}
  if(button.dataset.file){state.home.file=files.find(f=>f.id===Number(button.dataset.file));renderHome();return;}
  if(button.dataset.pref){const key=button.dataset.pref;if(key==='paste')state.paste=!state.paste;else state.prefs[key]=!state.prefs[key];button.setAttribute('aria-checked',key==='paste'?state.paste:state.prefs[key]);return;}
  switch(button.dataset.action){
    case 'home':go('home');break;
    case 'daily':go('dictado');break;
    case 'acta':go('acta');break;
    case 'leave-setup':if(state.dictado.recording){clearSceneTimers();state.dictado.recording=false;}go('home');toast('Setup can be continued from your plate.');break;
    case 'resume-setup':resumeSetup();break;
    case 'setup-begin':state.setup={step:1,progress:0,error:false,practice:'',done:false};state.mic=false;state.paste=false;state.models=false;renderSetup();break;
    case 'setup-mic':state.mic=true;clearScenario();state.setup.step=2;renderSetup();break;
    case 'setup-paste':state.paste=true;state.setup.step=3;renderSetup();break;
    case 'setup-skip-paste':state.paste=false;state.setup.step=3;renderSetup();break;
    case 'retry-download':clearSceneTimers();state.setup.error=false;clearScenario();renderSetup();break;
    case 'setup-practice':if(!state.models)return;state.setup.step=4;renderSetup();break;
    case 'practice':practice();break;
    case 'setup-complete':state.setup.done=true;state.setup.step=5;renderSetup();break;
    case 'record':record();break;
    case 'recover-mic':state.mic=true;clearScenario();toast('Demo: microphone access enabled.');record();break;
    case 'retry-take':clearScenario();record();break;
    case 'cancel-take':cancelTake();break;
    case 'manual-paste':landTake();break;
    case 'acta-mic':state.mic=true;renderActa();break;
    case 'acta-audio':state.acta.audio=true;renderActa();break;
    case 'acta-start':startMeeting();break;
    case 'acta-pause':state.acta.phase=state.acta.phase==='paused'?'recording':'paused';renderActa();notch();break;
    case 'acta-finish':finishMeeting();break;
    case 'acta-collapse':state.acta.collapsed=true;renderActa();break;
    case 'acta-expand':if(state.scene!=='acta')go('acta');else{state.acta.collapsed=false;renderActa();}break;
    case 'acta-reconnect':state.acta.sourceLost=false;clearScenario();renderActa();toast('App audio reconnected in the preview.');break;
    case 'acta-retry-save':state.acta.saveError=false;state.acta.failSave=false;clearScenario();if(!files.some(f=>f.id===state.acta.file.id))files.unshift(state.acta.file);renderActa();toast('✓ Transcript saved on your shelf.');break;
    case 'acta-export':if(state.acta.file)exportFile(state.acta.file);break;
    case 'acta-open-file':if(state.acta.file)openFile(state.acta.file);break;
    case 'acta-new':state.acta.phase='ready';state.acta.file=null;state.acta.saveError=false;state.acta.failSave=false;renderActa();notch();break;
    case 'back-files':state.home.file=null;state.home.tab='history';renderHome();break;
    case 'copy-file':if(state.home.file)copyText(state.home.file.text);break;
    case 'export-file':if(state.home.file)exportFile(state.home.file);break;
    case 'folder-info':toast('Native location: ~/Documents/tapas/. This preview uses sample files in memory.');break;
  }
});
document.addEventListener('input',event=>{
  if(event.target.id==='history-query'){state.home.query=event.target.value;renderHistory();}
  if(event.target.id==='note-editor')state.dictado.note=event.target.value;
});
document.addEventListener('change',event=>{
  const target=event.target;
  if(target.id==='shortcut'){state.prefs.shortcut=target.value;toast(`Shortcut set to ${target.value}.`);}
  if(target.id==='meeting-source'){state.acta.source=target.value;$('#active-app').textContent=target.value;}
  if(target.id==='scenario'){
    state.scenario=target.value;
    if(state.scenario==='mic-denied'){state.mic=false;if(state.dictado.recording)cancelTake();if(state.scene==='onboarding')renderSetup();}
    if(state.scenario==='download-offline'&&state.setup.step===3){clearSceneTimers();renderSetup();}
    if(state.scene==='acta'){state.acta.sourceLost=state.scenario==='source-lost';state.acta.failSave=state.scenario==='save-failed';renderActa();}
    $('#scenario-description').textContent=state.scenario?'Scenario armed. Try the next action.':'See how Tapas helps you recover.';
  }
});
document.addEventListener('keydown',event=>{
  if(event.key==='Escape'&&state.dictado.recording){event.preventDefault();cancelTake();return;}
  const chord=state.prefs.shortcut==='⌃ ⌥'?event.ctrlKey&&event.altKey:event.code==='MetaRight';
  if(chord&&!event.repeat&&!keysDown){keysDown=true;if(state.scene==='dictado'){event.preventDefault();record();}else if(state.scene==='onboarding'&&state.setup.step===4){event.preventDefault();practice();}}
});
document.addEventListener('keyup',event=>{if(!(event.ctrlKey&&event.altKey)||event.code==='MetaRight')keysDown=false;});
window.addEventListener('blur',()=>{keysDown=false;});
$('#notch').addEventListener('click',()=>go('home'));
$('#display-toggle').addEventListener('click',()=>{const on=$('#desktop').classList.toggle('notchless');$('#display-toggle').setAttribute('aria-pressed',on);$('#display-toggle').textContent=on?'▱ Back to MacBook':'▱ Notchless display';});
$('#reset-demo').addEventListener('click',()=>{sessionGeneration++;clearSceneTimers();Object.assign(state,JSON.parse(initialState));files.splice(0,files.length,...JSON.parse(initialFiles));serial=10;go('onboarding');});
window.addEventListener('hashchange',()=>{const scene=location.hash.slice(1);go(journeys[scene]?scene:'home');});
const initialJourney=location.hash.slice(1);
go(initialJourney?(journeys[initialJourney]?initialJourney:'home'):'onboarding');
