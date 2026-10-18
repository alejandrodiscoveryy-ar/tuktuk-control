import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const source = readFileSync(new URL('../../web/guided_camera.js', import.meta.url), 'utf8');
const marker = '  window.tuktukGuidedCapturePhoto = async function (kind) {';
assert.ok(source.includes(marker));
const sandbox = {window:{}};
vm.runInNewContext(source.replace(marker, '  window.__crop = guideCropRect;\n' + marker), sandbox);
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