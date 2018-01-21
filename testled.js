#!/usr/bin/env node

var ws281x = require('rpi-ws281x-native');
var NUM_LEDS =  2
var r = 255
var g = 0
var b = 0
pixelData = new Uint32Array(NUM_LEDS);
ws281x.init(NUM_LEDS);

// trap the SIGINT and reset before exit
process.on('SIGINT', function () {
  ws281x.reset();
  process.nextTick(function () { process.exit(0); });
});


//  animation-loop
var offset = 0;

setInterval(function () {
  if (r==255) console.log('Red');
  if (g==255) console.log('Green');
  if (b==255) console.log('Blue');

  for (var i = 0; i < NUM_LEDS; i++) {
    pixelData[i] = rgb2Int(r,g,b);
  }
  ws281x.render(pixelData);

  if (r==255) {
    g=255; r=0;
  } else if (g==255){
    b=255; g=0;
  } else {
    r=255; b=0;
  }
}, 2000 );

function rgb2Int(r, g, b) {
  return ((r & 0xff) << 16) + ((g & 0xff) << 8) + (b & 0xff);
}

console.log('Press <ctrl>+C to exit.');


