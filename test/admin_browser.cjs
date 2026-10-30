// Test-only API fixtures. Production code never uses these responses.
const {chromium}=require('playwright');
const {PNG}=require('pngjs');
const fs=require('node:fs'), path=require('node:path'), assert=require('node:assert/strict');
const id='11111111-1111-4111-8111-111111111111';
const base=process.env.PREVIEW_URL||'http://localhost:3001';
(async()=>{
 const browser=await chromium.launch({channel:'msedge',headless:true});
 const out=path.resolve('build/screenshots');fs.mkdirSync(out,{recursive:true});
 const errors=[];
 try {
  for(const [label,width,height] of [['desktop',1440,1000],['mobile',390,844]]){
   const context=await browser.newContext({viewport:{width,height}});
   const page=await context.newPage();
   page.on('pageerror',e=>errors.push(e.message));
   page.on('console',m=>{if(m.type()==='error'&&/overflow|exception|unable to load asset/i.test(m.text()))errors.push(m.text());});
   let row={id,reference:'REQ-S-2026-09-0001',person_kind:'STUDENT',person_id:'123456',request_type:'SSPR',status:'PENDING',
    created_at:'2026-09-21T08:00:00Z',submitted_at:'2026-09-21',semester_label:'1st Semester 2026-2027',reviewer_notes:'',requires_letter:false,registry_applied:false,
    payload:{personKind:'STUDENT',requestKind:'SSPR',fields:{firstName:'Ana',middleName:'',lastName:'Santos',personId:'123456',
     institute:'Institute of Computer Studies',program:'Bachelor of Science in Computer Science',gmail:'ana@gmail.com',contact:'09171234567',notes:''}},
    requestCount:3,history:[{action:'REQUEST_SUBMITTED',created_at:'2026-09-21',description:'Student submitted an enrollment request.'}],messages:[],delivery:[]};
   let lastFilters;
   await page.route('**/api/v1/**',async route=>{
    const req=route.request(),u=new URL(req.url()),p=u.pathname;
    let data={};
    if(p.endsWith('/auth/login'))data={success:true,accessToken:'test-only',user:{id,username:'admin',email:'office@example.test',firstName:'CISO',lastName:'Administrator',status:'ACTIVE',mustChangePassword:false,roles:['SUPER_ADMIN'],permissions:['manage_requests','manage_registry','manage_support','view_reports','view_audit','manage_settings']}};
    else if(p.endsWith('/settings'))data={periods:[{id,semester:'1st Semester',academic_year:'2026-2027',start_date:'2026-08-01',end_date:'2026-12-31'}],currentPeriod:id};
    else if(p.endsWith('/decision')){const b=req.postDataJSON();row.status=b.action==='approve'?'APPROVED':b.action==='reject'?'REJECTED':'COMPLETED';if(b.action==='register')row.registry_applied=true;data={success:true};}
    else if(p.endsWith('/contacts')){const b=req.postDataJSON();row.work_payload={...row.payload,fields:{...row.payload.fields,gmail:b.gmail,contact:b.contact}};data={success:true};}
    else if(p.endsWith('/priority')){row.priority=req.postDataJSON().priority;data={success:true};}
    else if(p.endsWith('/message')){row.messages.push({body:req.postDataJSON().body,created_at:'2026-09-21'});data={success:true};}
    else if(p.endsWith('/requests/'+id))data=row;
    else if(p.endsWith('/audit'))data={rows:[{created_at:'2026-09-21',username:'admin',actor_role:'SUPER_ADMIN',semester_label:'1st Semester 2026-2027',action:'REQUEST_SUBMITTED',reference:row.reference}]};
    else if(p.endsWith('/support'))data={tickets:[]};
    else if(p.endsWith('/registry'))data={rows:[{person_kind:'STUDENT',person_id:'123456',first_name:'Ana',middle_name:'',last_name:'Santos',institute:'Institute of Computer Studies',program:'Bachelor of Science in Computer Science',position:'',school_email:'santosana@gadtc.edu.ph',contact:'09171234567',gmail:'ana@gmail.com',active:true}]};
    else if(p.endsWith('/requests')||p.endsWith('/reports')){
     lastFilters=u.search;
     const matching=(!u.searchParams.get('type')||u.searchParams.get('type')===row.request_type)&&(!u.searchParams.get('status')||u.searchParams.get('status')===row.status);
     data={rows:matching?[row]:[],summary:{total:matching?1:0,pending:row.status==='PENDING'?1:0,approved:row.status==='APPROVED'?1:0,rejected:0,completed:row.status==='COMPLETED'?1:0,students:1,faculty:0}};
    }
    await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(data)});
   });
   async function shot(name){
    await page.waitForTimeout(450);
    const bytes=await page.screenshot({path:path.join(out,'admin-'+label+'-'+name+'.png')});
    const png=PNG.sync.read(bytes),colors=new Set();
    for(let i=0;i<png.data.length;i+=400)colors.add(png.data.subarray(i,i+3).toString('hex'));
    assert(colors.size>25,'Nonblank '+name);
   }
   async function go(section){await page.evaluate(s=>location.hash='/admin/'+s,section);await page.waitForTimeout(600);}
   await page.goto(base+'/#/admin/login',{waitUntil:'networkidle'});
   const enable=page.locator('flt-semantics-placeholder');await enable.waitFor({state:'attached',timeout:60000});await enable.evaluate(e=>e.click());
   await page.getByRole('textbox',{name:'Username',exact:true}).waitFor({timeout:60000});
   await shot('login-light');
   await page.getByRole('button',{name:'Dark',exact:true}).click();await shot('login-dark');
   await page.getByRole('button',{name:'Light',exact:true}).click();
   await page.reload({waitUntil:'networkidle'});
   const loginSemantics=page.locator('flt-semantics-placeholder');
   await loginSemantics.waitFor({state:'attached'});await loginSemantics.evaluate(e=>e.click());
   await page.getByRole('textbox',{name:'Username',exact:true}).click();
   await page.waitForTimeout(300);await page.keyboard.type('admin',{delay:40});
   await page.getByRole('textbox',{name:'Password',exact:true}).click();
   await page.waitForTimeout(200);await page.keyboard.type('fixture-password',{delay:40});
   await page.getByRole('button',{name:'Sign In',exact:true}).click();
   try { await page.getByText('Dashboard',{exact:true}).waitFor({timeout:15000}); }
   catch(e) { console.error(await page.locator('body').ariaSnapshot()); throw e; }
   await shot('dashboard-light');
   await page.getByRole('button',{name:'Dark',exact:true}).click();await shot('dashboard-dark');
   await page.getByRole('button',{name:'Light',exact:true}).click();
   await go('requests/'+id);await page.getByText('Review Request',{exact:true}).waitFor();await shot('review');
   await page.getByRole('button',{name:'Approve Request',exact:true}).click();
   await page.getByRole('button',{name:'Confirm',exact:true}).click();
   await page.getByRole('button',{name:'Done',exact:true}).waitFor();assert.equal(row.status,'APPROVED');
   await go('users');await page.getByText('Manage Users',{exact:true}).waitFor();await shot('users');
   await go('reports');await page.getByText('Reports',{exact:true}).last().waitFor();await shot('reports');
   await go('audit');await shot('audit');
   await go('settings');await shot('settings');
   await go('messages');await shot('messages');
   assert(lastFilters!==undefined);
   await context.close();
  }
  assert.deepEqual(errors,[]);console.log('Admin desktop/mobile light/dark and approval navigation checks passed (mock API only).');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
