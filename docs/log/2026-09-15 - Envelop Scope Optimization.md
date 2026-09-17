> **Historical, noncanonical log (2026-09-15).** This records the project at
> the time and includes superseded presence/platform claims. See
> [`docs/status.md`](../docs/status.md) for current facts.

<p align="center">
  <img src="../../web/assets/gallery/envelop/logs/envelop-runtime-light.svg" width="70%" alt="Current Envelop runtime boundaries from browser through backend and bridge to Tomato">
</p>
<p align="center"><em>The optimized runtime boundary: public browser, backend queue, verified nearby bridge, and Tomato.</em></p>

Whenever I am working on a main proejct, I choose to spend less time turning the other problems into another main proejct. With that, I have observed that the main issue that prompted native apps was permission to access bluetooth.

Without deep thoughts, I drafted to build for all popular tools, but that is essentially inventing the universe just to bake bread! This is why I love coming back to ideas and solving them extensively (In other words, dedicating all 8 cores of my brain to tackle the issue lol)

In the optimization, Evelop stays chat only! And rathyer, a single native macOS for me the server, will control connection to the internet. Without that computer, all is offline.

## Why not use an ESP32 - it has WIFI and BLE
It was tempting, but the inital premise of tomato was about clarity without bluring operation. The issue I have with esp32 and arduino is that a good board of its kind can render a tomato like image, blurring the line as to waht board is doing what?

The adafruit nrf8001 BLE is different as in no universe will it render a video. It is for bidrectional communication, send receive, and that's it.

Also, the premise of the BLE was for my own personal demo, but after such a time diving so deeply into building a computer from scratch, I may have worn out the opportunigy for "first time jumping around excitiment". While I am deeply passionate, it makes sense to keep a balance between demonstrating to muyself and also to every other interested person out there.

I have tested the pipelines and they are working! Tomato sends message as it should, I reveive it and so forth, and it remains that way, if you are online, you are in thec chat, else your record is deleted and so forth!

I am particularoy glad that this subproject took not too long, and will be resolved as the literal seconds run!