// Run after starting Flutter on port 3000. Requires Playwright and pngjs.
const { chromium } = require('playwright');
const { PNG } = require('pngjs');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

(async () => {
  const out = path.resolve('build/screenshots');
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const errors = [];
  const base = process.env.PREVIEW_URL || 'http://localhost:3001';
  async function screenshot(page, name) {
    const buffer = await page.screenshot({ path: path.join(out, name + '.png') });
    const png = PNG.sync.read(buffer);
    const colors = new Set();
    for (let i = 0; i < png.data.length; i += 400) colors.add(png.data.subarray(i, i + 3).toString('hex'));
    assert(colors.size > 25, name + ' should contain nonblank rendered content');
    console.log(name + ': ' + png.width + 'x' + png.height + ', sampled colors=' + colors.size);
  }
  try {
    for (const [name, width, height] of [['desktop', 1440, 1000], ['tablet', 768, 1024], ['mobile', 390, 844]]) {
      const context = await browser.newContext({ viewport: { width, height } });
      const page = await context.newPage();
      page.on('pageerror', error => errors.push(error.message));
      page.on('console', msg => {
        if (msg.type() === 'error' && /overflow|exception|unable to load asset/i.test(msg.text())) errors.push(msg.text());
      });
      await page.goto(base, { waitUntil: 'networkidle' });
      // Flutter exposes semantic controls after the accessibility placeholder is activated.
      const enable = page.locator('flt-semantics-placeholder');
      await enable.waitFor({ state: 'attached', timeout: 60000 });
      await enable.evaluate(el => el.click());
      await page.getByText('How can we help you?', { exact: true }).waitFor({ timeout: 60000 });
      await page.waitForTimeout(500);
      await screenshot(page, name + '-light');
      await page.getByRole('button', { name: 'Switch to dark mode', exact: true }).click();
      await page.waitForTimeout(400);
      await screenshot(page, name + '-dark');
      await page.getByRole('button', { name: 'Open support chat', exact: true }).click();
      await page.getByText('ReAccess Hub Assistant', { exact: true }).waitFor();
      await page.getByRole('button', { name: 'What is SSPR Enrollment?', exact: true }).last().click();
      await page.waitForTimeout(400);
      await screenshot(page, name + '-chat');
      await page.getByRole('button', { name: 'Close support chat', exact: true }).click();
      await page.reload({ waitUntil: 'networkidle' });
      await page.waitForFunction(() => document.querySelector('flt-semantics-placeholder') || document.querySelector('flt-semantics[role="button"]'), { timeout: 60000 });
      const again = page.locator('flt-semantics-placeholder');
      if (await again.count()) await again.evaluate(el => el.click());
      await page.getByRole('button', { name: 'Open support chat', exact: true }).click();
      await page.waitForTimeout(500);
      await screenshot(page, name + '-restored-chat');
      const restored = await page.evaluate(() => Object.entries(localStorage).filter(([key]) => key.includes('reaccess.chat')).map(([, value]) => JSON.parse(value)));
      assert(restored.length > 0, 'Chat should be persisted in browser storage');
      const stored = typeof restored[0] === 'string' ? JSON.parse(restored[0]) : restored[0];
      assert(stored.messages.some(message => message.text.startsWith('Self-Service Password Reset (SSPR)')), 'FAQ answer should survive reload');
      await page.getByRole('button', { name: 'Close support chat', exact: true }).click();
      if (name === 'desktop') {
        await page.mouse.move(600, 500);
        await page.mouse.wheel(0, 1120);
        await page.waitForTimeout(700);
        await screenshot(page, 'desktop-services-dark');
        await page.mouse.wheel(0, 900);
        await page.waitForTimeout(700);
        await screenshot(page, 'desktop-help-dark');
        await page.getByRole('button', { name: 'Switch to light mode', exact: true }).click();
        await page.waitForTimeout(500);
        await screenshot(page, 'desktop-help-light');
        await page.mouse.move(600, 500);
        await page.mouse.wheel(0, -4000);
        await page.waitForTimeout(700);
      }
      assert.equal(await page.getByText('Admin Access', { exact: true }).count(), 0);
      await page.evaluate(() => { window.location.hash = '/admin/dashboard'; });
      await page.getByText('Authorized school personnel only.', { exact: true }).waitFor();
      assert(page.url().includes('/admin/login'));
      await context.close();
    }
    assert.deepEqual(errors, [], 'Browser rendering errors');
    console.log('Browser smoke checks passed.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
