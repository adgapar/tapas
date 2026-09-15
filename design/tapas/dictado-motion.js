(() => {
  const $ = id => document.getElementById(id);
  const sentence = 'Leave a little room for the good ideas. We can make something useful, and make it feel good too.';
  const words = sentence.split(' ');
  const descriptions = {
    plato: ['El plato.', 'Warm paper, a soft landing, a little space to breathe. The default I’d ship.', 'A steady place to glance. Clear of the menu bar, lifted above the Dock.', 'The pintxo opens like a breath. On delivery, the four pieces nest back onto their pick.'],
    pin: ['El pin.', 'Ink against the desktop. A compact signal near the menu bar, with words unfolding underneath.', 'Strong peripheral presence. It can compete with browser tabs and top-of-screen controls.', 'It unfolds from the top edge. The saffron and cobalt ingredients glow against the ink.'],
    ticket: ['El ticket.', 'A tiny paper receipt at the edge of your work. More room for words, with a tear-line finish.', 'A companion for longer thoughts. It occupies more space and can overlap sidebars.', 'It slips in from the right, then straightens. A perforated line separates words from controls.']
  };
  let state = 'idle', placement = 'plato', count = 0, started = 0, frame = null, generation = 0, autoFinish = null, settleTimer = null, inserted = false;
  const labels = {idle:'Ready when you are.',listening:'Listening.',finishing:'One moment…',delivered:'Thought delivered.',recovery:'Your words are safe.',empty:'Nothing heard.',cancelled:'Take cancelled.'};
  function clearTimers() { cancelAnimationFrame(frame); clearTimeout(autoFinish); clearTimeout(settleTimer); generation++; }
  function enter() { const panel = $('dictado'); panel.classList.remove('reenter'); void panel.offsetWidth; panel.classList.add('reenter'); }
  function render() {
    $('desktop').dataset.state = state;
    $('status').textContent = labels[state];
    $('menu-status').textContent = `Tapas · ${state === 'listening' ? '● Recording' : state === 'finishing' ? 'Finishing' : state === 'recovery' ? 'Words kept' : 'Ready'}`;
    $('live-wrap').classList.toggle('collapsed', !($('live-words').checked && ['listening','finishing'].includes(state)));
    $('live-text').textContent = words.slice(0,count).join(' ') || 'Go on. We’re listening.';
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
    $('timer').hidden = !['listening','finishing'].includes(state);
  }
  function tick(now) {
    if (state !== 'listening') return;
    const elapsed = Math.max(0, (now-started)/1000);
    $('timer').textContent = `${String(Math.floor(elapsed/60)).padStart(2,'0')}:${String(Math.floor(elapsed%60)).padStart(2,'0')}`;
    const next = $('outcome').value === 'empty' ? 0 : Math.min(words.length, Math.floor(Math.max(0,elapsed-.5)*3.6));
    if (next !== count) { count = next; $('live-text').textContent = words.slice(0,count).join(' ') || 'Go on. We’re listening.'; }
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
    const info=descriptions[placement]; ['option-title','option-description','placement-caption','motion-detail'].forEach((id,i)=>$(id).textContent=info[i]); enter();
  });});
  document.addEventListener('keydown',e=>{if(e.repeat || e.metaKey || e.ctrlKey || e.altKey)return;if(e.code==='Escape'){cancel();return;}if(e.target.closest('input,textarea,select,button,a,[contenteditable]'))return;if(e.code==='Space'){e.preventDefault();state==='listening'?finish():start();}});
  render();
})();
