(() => {
  const $ = id => document.getElementById(id);
  const sentence = 'Leave a little room for the good ideas. We can make something useful, and make it feel good too.';
  const words = sentence.split(' ');
  const descriptions = {
    pintxo: ['El pintxo.', 'A floating companion could suit Acta’s longer conversations. This is a shape exploration; the controls here still play a sample Dictado take.', 'Companion exploration for Acta. A clear presence, with room to grow into meeting status.', 'For Acta, keep the ingredients together as a companion. Reserve the compact voice transformation for short Dictado takes.', '82 × 78 px · possible Acta companion'],
    borde: ['El borde.', 'A tiny edge signal for a quick thought. The same four ingredients unfold into voice bars, then return to the pintxo.', 'Dictado stays at the top edge. Its four ingredients turn into the voice signal.', 'Saffron, cobalt, paprika, olive. Four ingredients at rest; the same four ingredients in motion.', '124 × 28 px · selected for Dictado']
  };
  let state = 'idle', placement = 'borde', count = 0, started = 0, frame = null, generation = 0, autoFinish = null, settleTimer = null, inserted = false;
  const labels = {idle:'Ready',listening:'Listening',finishing:'Finishing',delivered:'Listo ✓',recovery:'Words kept',empty:'Try again',cancelled:'Cancelled'};
  function clearTimers() { cancelAnimationFrame(frame); clearTimeout(autoFinish); clearTimeout(settleTimer); generation++; }
  function enter() { const panel = $('dictado'); panel.classList.remove('reenter'); void panel.offsetWidth; panel.classList.add('reenter'); }
  function render() {
    $('desktop').dataset.state = state;
    $('popup-anchor').hidden = ['idle','cancelled'].includes(state);
    document.querySelector('.popup-footer').hidden = state !== 'listening';
    $('morph-demo').dataset.state = state;
    $('morph-label').textContent = state === 'listening' ? 'The same pieces, listening' : state === 'finishing' ? 'Gathering back onto the pick' : state === 'delivered' ? 'Listo. Back together.' : 'Pintxo, at rest';
    $('replay-morph').disabled = state === 'recovery';
    $('status').textContent = labels[state];
    $('recording-token').disabled = ['finishing','recovery'].includes(state);
    $('recording-token').setAttribute('aria-label', state === 'listening' ? 'Finish take' : state === 'finishing' ? 'Finishing your words' : state === 'recovery' ? 'Your words are kept below' : 'Start a take');
    $('menu-status').textContent = state === 'listening' ? 'Tapas · ● Recording' : state === 'finishing' ? 'Tapas · Finishing' : state === 'recovery' ? 'Tapas · Words kept' : 'Tapas';
    $('live-wrap').classList.toggle('collapsed', !($('live-words').checked && ['listening','finishing'].includes(state)));
    $('live-text').textContent = words.slice(Math.max(0,count-10),count).join(' ') || 'Go on. We’re listening.';
    $('finish').hidden = state !== 'listening';
    $('cancel').hidden = state !== 'listening';
    $('again').hidden = state !== 'empty';
    $('hint').textContent = ({idle:'A thought away.',listening:'Space to finish',finishing:'Gathering your words',delivered:'In your sample note. Listo.',recovery:'Nothing lost. Take your time.',empty:'No words added to your note.',cancelled:'Nothing saved.'})[state];
    $('recovery').hidden = !['recovery','empty'].includes(state);
    $('recovery-description').textContent = state === 'empty' ? 'Try another take when you’re ready. Your recording signal will stay visible.' : 'The destination wasn’t available. Your words stay here until you place them.';
    $('retained').textContent = state === 'recovery' ? words.slice(0,count).join(' ') : '';
    $('retry').hidden = state !== 'recovery';
    $('toggle').disabled = ['finishing','recovery'].includes(state);
    $('replay').disabled = state === 'recovery';
    $('toggle').innerHTML = state === 'listening' ? 'Finish this thought <span>■</span>' : state === 'finishing' ? 'Finishing… <span>···</span>' : state === 'recovery' ? 'Place the retained words first' : 'Start a take <span>↗</span>';
    $('timer').hidden = true;
  }
  function tick(now) {
    if (state !== 'listening') return;
    const elapsed = Math.max(0, (now-started)/1000);
    $('timer').textContent = `${String(Math.floor(elapsed/60)).padStart(2,'0')}:${String(Math.floor(elapsed%60)).padStart(2,'0')}`;
    const next = $('outcome').value === 'empty' ? 0 : Math.min(words.length, Math.floor(Math.max(0,elapsed-.5)*3.6));
    if (next !== count) { count = next; $('live-text').textContent = words.slice(Math.max(0,count-10),count).join(' ') || 'Go on. We’re listening.'; }
    frame = requestAnimationFrame(tick);
  }
  function start(auto = false) {
    if (state === 'finishing' || state === 'recovery') return;
    clearTimers(); state = 'listening'; count = 0; inserted = false; started = performance.now(); $('timer').textContent='00:00'; render(); enter(); frame=requestAnimationFrame(tick);
    if (auto) autoFinish=setTimeout(finish,7400);
  }
  function land() {
    if (!inserted) { const text=words.slice(0,count).join(' '); $('note').value += ($('note').value.trim() ? '\n\n' : '')+text; inserted=true; }
    state='delivered'; render();
    const take=generation;
    settleTimer=setTimeout(()=>{if(take===generation && state==='delivered'){state='idle';render();}},1600);
  }
  function finish() {
    if(state!=='listening') return;
    clearTimers(); state='finishing'; render(); const take=generation;
    settleTimer=setTimeout(()=>{if(take!==generation)return; if($('outcome').value==='empty'||count===0){state='empty';render();}else if($('outcome').value==='recovery'){state='recovery';render();}else land();},1100);
  }
  function cancel(){if(state!=='listening')return;clearTimers();state='cancelled';count=0;render();}
  $('recording-token').addEventListener('click',()=>state==='listening'?finish():start());
  $('toggle').addEventListener('click',()=>state==='listening'?finish():start());
  $('finish').addEventListener('click',finish); $('cancel').addEventListener('click',cancel); $('again').addEventListener('click',()=>start()); $('retry').addEventListener('click',()=>{if(state==='recovery')land();});
  $('replay').addEventListener('click',()=>{if(state==='recovery')return;clearTimers();state='idle';start(true);});
  $('replay-morph').addEventListener('click',()=>{if(state==='recovery')return;clearTimers();state='idle';start(true);});
  $('notched-display').addEventListener('change',()=>{ $('desktop').dataset.notched = String($('notched-display').checked); });
  $('live-words').addEventListener('change',render);
  const reduced=matchMedia('(prefers-reduced-motion: reduce)'); $('quiet-motion').checked=reduced.matches;
  $('quiet-motion').addEventListener('change',()=>document.body.classList.toggle('quiet-motion',$('quiet-motion').checked));
  reduced.addEventListener('change',e=>{if(e.matches){$('quiet-motion').checked=true;document.body.classList.add('quiet-motion');}});
  document.body.classList.toggle('quiet-motion',reduced.matches);
  document.querySelectorAll('[data-placement]').forEach(button=>{if(button.tagName!=='BUTTON')return;button.addEventListener('click',()=>{
    placement=button.dataset.placement; $('desktop').dataset.placement=placement;
    document.querySelectorAll('.placement').forEach(b=>{b.classList.toggle('selected',b===button);b.setAttribute('aria-pressed',String(b===button));});
    const info=descriptions[placement]; ['option-title','option-description','placement-caption','motion-detail','footprint'].forEach((id,i)=>$(id).textContent=info[i]); enter();
  });});
  document.addEventListener('keydown',e=>{if(e.repeat || e.metaKey || e.ctrlKey || e.altKey)return;if(e.code==='Escape'){cancel();return;}if(e.target.closest('input,textarea,select,button,a,[contenteditable]'))return;if(e.code==='Space'){e.preventDefault();state==='listening'?finish():start();}});
  render();
})();
