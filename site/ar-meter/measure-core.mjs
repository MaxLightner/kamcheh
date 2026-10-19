// Pure geometry for the Kamcheh WebXR ruler. XR coordinates are in metres.
export function floorDistanceMeters(a,b){
  if(!a||!b||![a.x,a.z,b.x,b.z].every(Number.isFinite)) throw new RangeError('Invalid floor positions');
  return Math.hypot(a.x-b.x,a.z-b.z);
}
export function calibrateOneMeter(a,b){
  const raw=floorDistanceMeters(a,b);
  // Require physically marked 100 cm and reject accidental near-identical taps.
  if(raw<0.25||raw>3) throw new RangeError('Reference points must mark a physical 1m span');
  return 1/raw;
}
export function measuredMeters(a,b,correction){
  if(!Number.isFinite(correction)||correction<=0)throw new RangeError('Calibration required');
  return floorDistanceMeters(a,b)*correction;
}
export function horizontalSurface(normalY){
  return Number.isFinite(normalY)&&Math.abs(normalY)>=0.82;
}
export function onSameFloor(a,b,tolerance=.14){
  return !!a&&!!b&&Number.isFinite(a.y)&&Number.isFinite(b.y)&&Math.abs(a.y-b.y)<=tolerance;
}
export function formatDistanceCm(meters){
  if(!Number.isFinite(meters)||meters<0)throw new RangeError('Invalid distance');
  const cm=meters*100;
  return cm<100?cm.toFixed(1)+' سانتی‌متر':meters.toFixed(2)+' متر';
}
