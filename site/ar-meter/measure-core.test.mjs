import test from 'node:test';
import assert from 'node:assert/strict';
import {
  floorDistanceMeters, calibrateOneMeter, measuredMeters,
  horizontalSurface, onSameFloor, formatDistanceCm
} from './measure-core.mjs';

const a={x:0,y:0,z:0};
const b={x:0.8,y:0,z:0};
test('reference 100 centimetres corrects an AR-tracked span of 80 centimetres',()=>{
  const correction=calibrateOneMeter(a,b);
  assert.equal(correction,1.25);
  assert.equal(measuredMeters(a,{x:1.6,y:0,z:0},correction),2);
});
test('measurement uses horizontal floor distance only',()=>{
  assert.equal(floorDistanceMeters(a,{x:0.3,y:5,z:0.4}),0.5);
});
test('rejects accidental zero-length or too-short calibration baseline',()=>{
  assert.throws(()=>calibrateOneMeter(a,a),RangeError);
  assert.throws(()=>calibrateOneMeter(a,{x:0.1,y:0,z:0}),RangeError);
});
test('calibration cannot be fabricated or omitted',()=>{
  assert.throws(()=>measuredMeters(a,b,0),RangeError);
  assert.throws(()=>measuredMeters(a,b,Number.NaN),RangeError);
});
test('requires horizontal plane and same floor height',()=>{
  assert.equal(horizontalSurface(0.98),true);
  assert.equal(horizontalSurface(-0.98),true);
  assert.equal(horizontalSurface(0.1),false);
  assert.equal(onSameFloor(a,{x:3,y:0.08,z:1}),true);
  assert.equal(onSameFloor(a,{x:3,y:0.23,z:1}),false);
});
test('result uses centimetres for short spans and metres for long ones',()=>{
  assert.equal(formatDistanceCm(0.55),'55.0 سانتی‌متر');
  assert.equal(formatDistanceCm(1.251),'1.25 متر');
  assert.throws(()=>formatDistanceCm(-1),RangeError);
});
