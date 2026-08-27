<?php
session_start();
$loggedIn = isset($_SESSION['bank_account_id']);
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>ALBU BANK ONLINE</title>
<style>
*{box-sizing:border-box}body{margin:0;font-family:Arial,Helvetica,sans-serif;background:#eef2f7;color:#172033}.wrap{max-width:1050px;margin:40px auto;padding:0 18px}.brand{font-weight:800;font-size:28px;letter-spacing:.5px;margin-bottom:22px}.card{background:#fff;border-radius:18px;box-shadow:0 10px 30px rgba(0,0,0,.08);padding:26px}.login{max-width:430px;margin:70px auto}.sub{color:#667085;margin-top:-10px;margin-bottom:24px}label{display:block;margin:14px 0 7px;font-weight:700}input,textarea,button{width:100%;padding:12px 14px;border:1px solid #d0d5dd;border-radius:10px;font-size:15px}textarea{min-height:90px;resize:vertical}button{cursor:pointer;background:#2a7ae2;color:#fff;border:none;font-weight:700}.danger{background:#c62828}.muted{color:#667085}.hidden{display:none}.top{display:flex;justify-content:space-between;gap:15px;align-items:center;margin-bottom:18px}.top button{width:auto;padding:10px 14px}.balance{font-size:40px;font-weight:800;margin:8px 0 4px}.pill{display:inline-block;padding:5px 10px;border-radius:999px;background:#ecfdf3;color:#027a48;font-weight:700;font-size:12px}.grid{display:grid;grid-template-columns:1fr 1fr;gap:18px;margin-top:18px}.row{display:flex;justify-content:space-between;gap:12px;padding:12px 0;border-bottom:1px solid #eaecf0}.tx{max-height:420px;overflow:auto}.error{background:#fef3f2;color:#b42318;border:1px solid #fecdca;padding:11px 13px;border-radius:10px;margin:12px 0}.success{background:#ecfdf3;color:#027a48;border:1px solid #abefc6;padding:11px 13px;border-radius:10px;margin:12px 0}.small{font-size:13px}@media(max-width:760px){.grid{grid-template-columns:1fr}.balance{font-size:32px}}
</style>
</head>
<body>
<div class="wrap">
  <div class="brand">ALBU BANK ONLINE</div>

  <section id="loginBox" class="card login <?= $loggedIn ? 'hidden' : '' ?>">
    <h2>Sign in</h2>
    <div class="sub">Use your ALBU Bank account ID and 4-digit PIN.</div>
    <div id="loginMsg"></div>
    <label>Account ID</label>
    <input id="loginAccount" placeholder="ACC-000001" autocomplete="username">
    <label>PIN</label>
    <input id="loginPin" type="password" inputmode="numeric" maxlength="4" placeholder="••••" autocomplete="current-password">
    <button onclick="login()">Sign in</button>
  </section>

  <section id="bankBox" class="<?= $loggedIn ? '' : 'hidden' ?>">
    <div class="card top">
      <div>
        <div class="muted small">ACCOUNT</div>
        <div id="accountName" style="font-size:22px;font-weight:800">Loading...</div>
        <div id="accountId" class="muted">—</div>
      </div>
      <button onclick="logout()">Logout</button>
    </div>

    <div class="grid">
      <div class="card">
        <div class="muted small">CURRENT BALANCE</div>
        <div id="balance" class="balance">$0.00</div>
        <span id="status" class="pill">ACTIVE</span>
        <div id="balanceMsg" class="muted small" style="margin-top:12px"></div>
      </div>

      <div class="card">
        <h3>Transfer money</h3>
        <div id="transferMsg"></div>
        <label>Destination account</label>
        <input id="destination" placeholder="ACC-000002">
        <label>Amount</label>
        <input id="amount" type="number" min="0.01" step="0.01" placeholder="100.00">
        <label>Description</label>
        <textarea id="description" placeholder="Optional"></textarea>
        <button onclick="transfer()">Send transfer</button>
      </div>
    </div>

    <div class="card" style="margin-top:18px">
      <div class="top"><h3 style="margin:0">Transaction history</h3><button onclick="loadAll()" style="width:auto">Refresh</button></div>
      <div id="tx" class="tx muted">Loading...</div>
    </div>

    <div class="card" style="margin-top:18px">
      <h3>Card</h3>
      <div class="row"><span class="muted">Card ID</span><strong id="cardId">—</strong></div>
      <div class="row"><span class="muted">Status</span><strong id="cardStatus">—</strong></div>
      <button class="danger" onclick="blockCard()">Block card</button>
      <p class="muted small">Blocking a card is immediate. A bank operator can change its status later.</p>
    </div>
  </section>
</div>
<script>
async function req(body, method='POST'){
  const r=await fetch('api.php',{method,headers:{'Content-Type':'application/json'},body:method==='POST'?JSON.stringify(body):undefined});
  return await r.json();
}
function show(el,type,text){el.innerHTML=text?`<div class="${type}">${escapeHtml(text)}</div>`:''}
function escapeHtml(s){return String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]))}
function money(v){return '$'+Number(v||0).toFixed(2)}
async function login(){
  show(loginMsg,'','');
  const r=await req({action:'login',account_id:loginAccount.value.trim(),pin:loginPin.value.trim()});
  if(!r.success){show(loginMsg,'error',r.error||'Login failed');return}
  loginBox.classList.add('hidden');bankBox.classList.remove('hidden');
  renderAccount(r.account);loadAll();
}
async function logout(){await req({action:'logout'},'GET');location.reload()}
function renderAccount(a){if(!a)return;accountName.textContent=a.owner_name||'Account';accountId.textContent=a.id||'—';cardId.textContent=a.card_id||'—';cardStatus.textContent=a.card_status||a.status||'—';status.textContent=(a.status||a.account_status||'ACTIVE').toUpperCase();balance.textContent=money(a.balance)}
async function loadAll(){
  const b=await req({action:'balance'}); if(b.success){renderAccount(b.data);balanceMsg.textContent='Updated just now.'}else{balanceMsg.textContent=b.error||'Balance unavailable'}
  const t=await req({action:'transactions',limit:50});
  if(!t.success){tx.innerHTML='<div class="error">'+escapeHtml(t.error||'History unavailable')+'</div>';return}
  const list=Array.isArray(t.data)?t.data:[];
  if(!list.length){tx.innerHTML='<div class="muted">No transactions yet.</div>';return}
  tx.innerHTML=list.slice().reverse().map(x=>`<div class="row"><div><strong>${escapeHtml(x.type||'transaction')}</strong><div class="muted small">${escapeHtml(x.description||'')} · ${new Date(Number(x.timestamp||0)).toLocaleString()}</div></div><strong>${Number(x.amount||0)>=0?'+':''}${money(x.amount)}</strong></div>`).join('')
}
async function transfer(){
  show(transferMsg,'','');
  const r=await req({action:'transfer',destination_account_id:destination.value.trim(),amount:Number(amount.value),description:description.value.trim()});
  if(!r.success){show(transferMsg,'error',r.error||'Transfer failed');return}
  show(transferMsg,'success','Transfer completed: '+money(r.data?.amount||0));destination.value='';amount.value='';description.value='';loadAll();
}
async function blockCard(){
  if(!confirm('Block this card?'))return;
  const r=await req({action:'block_card'});
  if(!r.success){alert(r.error||'Unable to block card');return}
  alert('Card blocked.');loadAll();
}
window.addEventListener('load',()=>{if(<?= $loggedIn ? 'true' : 'false' ?>)loadAll()});
</script>
</body>
</html>
