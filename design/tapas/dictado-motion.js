(() => {
  const $ = id => document.getElementById(id);
  const sentence = 'Leave a little room for the good ideas. We can make something useful, and make it feel good too.';
  const words = sentence.split(' ');
  const descriptions = {
    miga: ['La miga.', 'A small ink pill: voice level, Listening, and a stop control. Familiar, but much lighter.', 'Bottom center, above the Dock. Click the pill to start or finish.', 'Five colored strokes catch the rhythm. The pill keeps the same footprint from listening to delivery.', '188 × 40 px · one compact line'],
    pintxo: ['El pintxo.', 'Four ingredients, floating on their own. A tiny status label keeps it clear. Tap the pintxo to finish.', 'The pintxo is the control. Click it to start or finish; hover for more.', 'The ingredients do the listening. A little movement, a clear label, then a satisfied settle.', '82 × 78 px · no surrounding panel'],
    borde: ['El borde.', 'A sliver of ink tucked under the menu bar. Colored ingredients and one word tell you what is happening.', 'Top center. Always in the same place; the caption unfolds below it.', 'A tiny bookmark for your voice. It slips down a few pixels, then sits quietly at the edge.', '124 × 28 px · tucked into the edge']
  };
  let state = 'idle', placement = 'pintxo', count = 0, started = 0, frame = null, generation = 0, autoFinish = null, settleTimer = null, inserted = false;
  const labels = {idle:'Ready',listening:'Listening',finishing:'Finishing',delivered:'Listo ✓',recovery:'Words kept',empty:'Try again',cancelled:'Cancelled'};
  function clearTimers() { cancelAnimationFrame(frame); clearTimeout(autoFinish); clearTimeout(settleTimer); generation++; }
  function enter() { const panel = $('dictado'); panel.classList.remove('reenter'); void panel.offsetWidth; panel.classList.add('reenter'); }
  function render() {
    $('desktop').dataset.state = state;
    $('status').textContent = labels[state];
    $('recording-token').disabled = ['finishing','recovery'].includes(state);
    $('recording-token').setAttribute('aria-label', state === 'listening' ? 'Finish take' : state === 'finishing' ? 'Finishing your words' : state === 'recovery' ? 'Your words are kept below' : 'Start a take');
    $('menu-status').textContent = `Tapas · ${state === 'listening' ? '● Recording' : state === 'finishing' ? 'Finishing' : state === 'recovery' ? 'Words kept' : 'Ready'}`;
    $('live-wrap').classList.toggle('collapsed', !($('live-words').checked && ['listening','finishing'].includes(state)));
    $('live-text').textContent = words.slice(Math.max(0,count-10),count).join(' ') || 'Go on. We’re listening.';
    $('finish').hidden = state !== 'listening';
    $('cancel').hidden = state !== 'listening';
    $('again').hidden = !['delivered','empty','cancelled'].includes(state);
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
