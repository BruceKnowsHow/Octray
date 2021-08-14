## Octray
![Image](https://cdn.discordapp.com/attachments/254127148913262593/730198439706755153/wide.jpg)

Octray is an experimental raytraced shaderpack for Minecraft/Optifine.

### What is remarkable about Octray?

Octray implements an Octree-like acceleration structure for its raytracing. This allows rays to be cast long distances in sparse environments with significantly fewer intersection-checks.

Octray also contains a few other inventions, such as a pseudo-recursive branching GLSL raytracer, implemented using a ray stack.

### Current Status

Development on this repository has halted for some time now. A rewrite of the shaderpack, [OctrayRewrite](https://www.patreon.com/BruceKnowsHow), is available. Many of the techniques have been built upon and improved in the rewrite (branchless path tracing, sparse chunk voxelization).

## Installation
Octray can be installed the same as any other Minecraft shaderpack. Just download the .zip from GitHub and place it into your shaderpacks folder.

If you have never installed a shaderpack before, there are lots of videos on Youtube to walk you through it. [Here is one](https://www.youtube.com/watch?v=XNLVHl4s8rA).

## Compatibility
As of writing, Octray should be compatible with:
- Nvidia, AMD and Intel hardware
- Every version of Minecraft from 1.8 through 1.16

Always make sure you are using the most recent version of [Optifine](https://optifine.net/downloads).
