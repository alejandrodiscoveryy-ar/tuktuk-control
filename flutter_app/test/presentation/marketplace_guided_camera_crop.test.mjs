import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const source = readFileSync(new URL('../../web/guided_camera.js', import.meta.url), 'utf8');
const marker = '  window.tuktukGuidedCapturePhoto = async function (kind) {';
assert.ok(source.includes(marker));
const sandbox = {window:{}};
vm.runInNewContext(source.replace(marker, '  window.__crop = guideCropRect; window.__guides = guides; window.__driverCamera = requestDriverCamera;\n' + marker), sandbox);
const rect=(left,top,width,height)=>({left,top,width,height,right:left+width,bottom:top+height});
const crop=(w,h,a,b)=>sandbox.window.__crop({videoWidth:w,videoHeight:h,getBoundingClientRect:()=>a},{getBoundingClientRect:()=>b});
const near=(actual,expected)=>assert.ok(Math.abs(actual-expected)<0.01, `${expected} != ${actual}`);
test('cámara vertical: recorta solo el marco',()=>{
  const p=crop(1080,1920,rect(0,0,360,600),rect(36,145,288,181));
  near(p.x,108); near(p.y,495); near(p.width,864); near(p.height,543);
});
test('sensor horizontal en móvil vertical',()=>{
  const p=crop(1920,1080,rect(0,0,360,600),rect(30,190,300,200));
  near(p.x,690); near(p.y,342); near(p.width,540); near(p.height,360);
});
test('nunca acepta un marco fuera del visor',()=>{
  assert.throws(()=>crop(1080,1920,rect(0,0,360,600),rect(500,700,100,100)));
});
test('each guide uses correct lens and preserves output aspect',()=>{
  const guides=sandbox.window.__guides;
  assert.equal(guides.driver.facing,'user');
  assert.equal(guides.driver.aspect,1);
  for(const [kind,ratio] of [['identity-front',1.59],['identity-back',1.59],['vehicle',4/3]]){
    assert.equal(guides[kind].facing,'environment');
    near(guides[kind].aspect,ratio);
  }
  for(const guide of Object.values(guides)){
    const w=240,h=w/guide.aspect;
    const p=crop(1080,1920,rect(0,0,360,600),rect(60,(600-h)/2,w,h));
    near(p.width/p.height,guide.aspect);
  }
});

function fakeCamera(facing, label = '') {
  const track = { label, stopped: false, getSettings: () => ({ facingMode: facing }),
    stop() { this.stopped = true; } };
  return { track, getTracks: () => [track], getVideoTracks: () => [track] };
}
test('selfie first requests exact front camera', async () => {
  const front = fakeCamera('user');
  const requests = [];
  const media = { getUserMedia: async c => { requests.push(c); return front; } };
  assert.equal(await sandbox.window.__driverCamera(media, () => true), front);
  assert.equal(requests[0].video.facingMode.exact, 'user');
  assert.equal(requests.length, 1);
});
test('selfie rejects rear and selects identified front device', async () => {
  const rear = fakeCamera('environment');
  const front = fakeCamera('user');
  const requests = [];
  const media = {
    getUserMedia: async c => { requests.push(c); return requests.length === 1 ? rear : front; },
    enumerateDevices: async () => [{ kind: 'videoinput', deviceId: 'front1', label: 'Front camera' }]
  };
  assert.equal(await sandbox.window.__driverCamera(media, () => true), front);
  assert.equal(rear.track.stopped, true);
  assert.equal(requests[1].video.deviceId.exact, 'front1');
});
test('selfie does not silently accept rear fallback', async () => {
  const rear = fakeCamera('environment');
  const media = {getUserMedia: async () => rear, enumerateDevices: async () => []};
  await assert.rejects(sandbox.window.__driverCamera(media, () => true));
  assert.equal(rear.track.stopped, true);
});
test('late camera stream is stopped after dialog closes', async () => {
  const front = fakeCamera('user');
  const media = {getUserMedia: async () => front};
  await assert.rejects(sandbox.window.__driverCamera(media, () => false));
  assert.equal(front.track.stopped, true);
});
