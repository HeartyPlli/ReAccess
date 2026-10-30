// Screenshot/UI verification with explicit test-only API fixtures.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
(async()=>{
  const browser=await chromium.launch({channel:'msedge',headless:true});
  const out=path.resolve('build/screenshots');
  fs.mkdirSync(out,{recursive:true});
  const errors=[];
  async function fill(page, name, value) {
    const input=page.getByRole('textbox',{name});
    await input.click();
    await page.keyboard.type(value,{delay:15});
  }
  try {
    for(const [name,width,height] of [['desktop',1440,1000],['mobile',390,844]]) {
      const page=await browser.newPage({viewport:{width,height}});
      page.on('pageerror',e=>errors.push(e.message));
      await page.route('**/api/v1/public/requests/verify',route=>route.fulfill({json:{verificationToken:'browser-test-only',previousRequests:2}}));
      await page.route('**/api/v1/public/requests',route=>route.fulfill({json:{reference:'REQ-S-2026-09-0001'}}));
      await page.goto('http://localhost:3001/#/request/student',{waitUntil:'networkidle'});
      const placeholder=page.locator('flt-semantics-placeholder');
      await placeholder.waitFor({state:'attached',timeout:60000});
      await placeholder.evaluate(el=>el.click());
      await page.getByText('Select Request Type',{exact:true}).first().waitFor();
      await page.waitForTimeout(300);
      await page.screenshot({path:path.join(out,name+'-request-selection.png')});
      await page.getByRole('button',{name:/^Account Recovery/}).click();
      await page.getByRole('button',{name:'Next',exact:true}).click();
      await fill(page, /First Name/, 'juan');
      await fill(page, /Last Name/, 'cruz');
      await fill(page, /Student ID/, '123456');
      await page.getByRole('button',{name:/Select institute/}).click();
      await page.getByRole('menuitem',{name:'Institute of Computer Studies',exact:true}).click();
      await fill(page, /School Email/, 'cruzjuan@gadtc.edu.ph');
      await fill(page, /Contact Number/, '09123456789');
      await fill(page, /Gmail Address/, 'juan@gmail.com');
      await page.screenshot({path:path.join(out,name+'-request-personal.png')});
      await page.getByRole('button',{name:'Next',exact:true}).click();
      await page.getByRole('button',{name:'Verify Identity',exact:true}).waitFor();
      await page.screenshot({path:path.join(out,name+'-request-verify.png')});
      await page.getByRole('button',{name:'Verify Identity',exact:true}).click();
      await fill(page, /Reason for Account Recovery/, 'I cannot access my institutional account.');
      await page.screenshot({path:path.join(out,name+'-request-details.png')});
      await page.getByRole('button',{name:'Review',exact:true}).click();
      await page.screenshot({path:path.join(out,name+'-request-review.png')});
      await page.getByRole('button',{name:'Submit Request',exact:true}).click();
      await page.getByText('Request Submitted!',{exact:true}).waitFor();
      await page.screenshot({path:path.join(out,name+'-request-receipt-test-fixture.png')});
      await page.getByRole('button',{name:'Return to Home',exact:true}).click();
      await page.getByText('How can we help you?',{exact:true}).waitFor();
      assert.equal(await page.getByText('Admin Access',{exact:true}).count(),0);
      console.log(name+' request flow passed (test fixture API).');
      await page.close();
    }
    assert.deepEqual(errors,[]);
  } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
